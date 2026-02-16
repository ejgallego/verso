/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
-- import Architect.Basic
import Verso
import VersoManual
import VersoBlueprint.Environment

open Lean Elab Command

set_option doc.verso true

namespace Informal.Commands

/-- Blueprint summary commands, interactive -/
syntax (name := bpSummary) "#bp_summary" : command

@[command_elab bpSummary]
def elabSummary : CommandElab := fun _stx => do
  logInfo m!"Generating BP summary"

-- Blueprint summary commands
syntax (name := bpGraph) "#bp_graph" : command

-- Architect integration is for the PNT blueprint
open Informal.Environment in
@[command_elab bpGraph]
def elabGraph : CommandElab := fun _stx => do
  -- let map := Architect.blueprintExt
  logInfo m!"Generating BP graph"
  let state := informalExt.getState (← getEnv)
  logInfo m!"{repr state}"
  dbg_trace s!"{repr state}"

/- Blueprint summary commands, Verso -/

structure GraphNode where
  label : Name
  deps : List Name
  proofDeps : List Name := []
  fillcolor : String
  href : Option String := none
deriving FromJson, ToJson, Quote

def Graph := List GraphNode deriving FromJson, ToJson, Quote

structure PendingProofItem where
  label : Name
  kind : String
  leanObjects : List Name := []
deriving Inhabited, FromJson, ToJson, Quote

structure SorryItem where
  label : Name
  kind : String
  decl : Name
  isTheorem : Bool := false
  sorryRefs : Nat := 0
  typeSorryRefs : Nat := 0
  proofSorryRefs : Nat := 0
deriving Inhabited, FromJson, ToJson, Quote

structure IndexItem where
  label : Name
  kind : String
  leanObjects : List Name := []
deriving Inhabited, FromJson, ToJson, Quote

structure Summary where
  totalEntries : Nat := 0
  definitions : Nat := 0
  lemmas : Nat := 0
  theorems : Nat := 0
  corollaries : Nat := 0
  leanOnlyEntries : Nat := 0
  informalOnlyEntries : Nat := 0
  pendingInformalProofEntries : List PendingProofItem := []
  leanDecls : Nat := 0
  sorries : Nat := 0
  sorryDetails : List SorryItem := []
  definitionIndex : List IndexItem := []
  theoremLikeIndex : List IndexItem := []
deriving Inhabited, FromJson, ToJson, Quote

def definitionNodeColor : String := "#bfdbfe" -- Definition
def leanOnlyDefNodeColor : String := "#e9d5ff" -- Lean-only definition, informal object missing
def leanOkNodeColor : String := "#d4f4dd" -- Lean + proof available
def sorryNodeColor : String := "#fff3bf" -- Lean code present / informal proof pending
def informalNodeColor : String := "#f3f4f6" -- Informal/proof-only
def informalDomainName : Name := Name.mkSimple "Informal.Block.informal"
def informalCodeDomainName : Name := Name.mkSimple "Informal.Block.informalCode"
def exampleDomainName : Name := ``Verso.Genre.Manual.example

def Graph.toDot (g : Graph) : String :=
  let known : NameSet := g.foldl (init := {}) fun acc node => acc.insert node.label
  let nodes := g.map fun node =>
    let attrs :=
      if let some href := node.href then
        s!"label=\"{node.label}\", fillcolor=\"{node.fillcolor}\", URL=\"{href}\", target=\"_self\", tooltip=\"{node.label}\""
      else
        s!"label=\"{node.label}\", fillcolor=\"{node.fillcolor}\""
    s!"  \"{node.label}\" [{attrs}];"
  let edges := g.flatMap fun node =>
    node.deps.filterMap fun dep =>
      if known.contains dep then
        some s!"  \"{node.label}\" -> \"{dep}\";"
      else
        none
  let proofEdges := g.flatMap fun node =>
    node.proofDeps.filterMap fun dep =>
      if known.contains dep then
        some s!"  \"{node.label}\" -> \"{dep}\" [style=dashed, penwidth=1.2];"
      else
        none
  let footer := "}"
  String.intercalate "\n" ([header] ++ nodes ++ edges ++ proofEdges ++ [footer])
where
  header := r##"strict digraph "" {
    rankdir=LR;
    bgcolor="white";
    splines=true;
    nodesep=0.35;
    ranksep=0.45;
    node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=10, margin="0.08,0.04", color="#6b7280", penwidth=1.8];
    edge [color="#6b7280", arrowhead=vee, arrowsize=0.6, penwidth=1];
    graph [fontname="Helvetica"];
  "##

def loadD3Dot :=
  r##"(function () {
    function load(src) {
      return new Promise(function (resolve, reject) {
        const s = document.createElement("script");
        s.src = src;
        s.onload = resolve;
        s.onerror = reject;
        document.head.appendChild(s);
      });
    }

    Promise.resolve()
      .then(() => load("https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js"))
      .then(() => load("https://cdn.jsdelivr.net/npm/d3-graphviz@5.6.0/build/d3-graphviz.min.js"))
      .then(() => {

  const graphContainer = d3.select("#graph");

  const dotTxt = graphContainer
    .select("script.dot-source")
    .text()
    .trim();

  const width = graphContainer.node().clientWidth;
  const height = graphContainer.node().clientHeight;

  // graphContainer.graphviz({useWorker: true})
  graphContainer.graphviz()
      .width(width)
      .height(height)
      .fit(true)
      .renderDot(dotTxt)
      // .on("end", interactive);
  });
  })();
  "##

def d3DotCss := include_str "graph.css"

def joinNames (xs : List Name) : String :=
  if xs.isEmpty then "none" else String.intercalate ", " (xs.map toString)

def openTargetDetailsJs : String := r##"(function () {
  function openFromHash() {
    if (!window.location.hash) return;
    const id = decodeURIComponent(window.location.hash.slice(1));
    if (!id) return;
    const target = document.getElementById(id);
    if (!target) return;
    const details = target.matches("details") ? target : target.closest("details");
    if (details) details.open = true;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", openFromHash);
  } else {
    openFromHash();
  }
  window.addEventListener("hashchange", openFromHash);
})();"##

def blueprintStyleSwitcherCss : String := r##"
#bp-style-switcher {
  position: fixed;
  right: 1rem;
  bottom: 1rem;
  z-index: 1000;
  background: #ffffff;
  border: 1px solid #cbd5e1;
  border-radius: 0.45rem;
  box-shadow: 0 4px 14px rgba(15, 23, 42, 0.1);
  padding: 0.4rem 0.55rem;
  font-size: 0.82rem;
}

#bp-style-switcher label {
  margin-right: 0.35rem;
  font-weight: 600;
}

#bp-style-switcher select {
  border: 1px solid #cbd5e1;
  border-radius: 0.3rem;
  background: #ffffff;
  font-size: 0.82rem;
  padding: 0.1rem 0.25rem;
}
  "##

def blueprintStyleSwitcherJs : String := r##"(function () {
  const storageKey = "verso-blueprint-style";
  const switcherId = "bp-style-switcher";
  const root = document.documentElement;

  function normalize(style) {
    if (style === "blueprint" || style === "modern" || style === "bold") return style;
    return "blueprint";
  }

  function applyStyle(style) {
    root.setAttribute("data-bp-style", normalize(style));
  }

  function getSavedStyle() {
    try {
      return normalize(localStorage.getItem(storageKey));
    } catch (_err) {
      return "blueprint";
    }
  }

  function saveStyle(style) {
    try {
      localStorage.setItem(storageKey, normalize(style));
    } catch (_err) {}
  }

  function installSwitcher() {
    if (document.getElementById(switcherId)) return;
    if (!document.body) return;

    const host = document.createElement("div");
    host.id = switcherId;

    const label = document.createElement("label");
    label.setAttribute("for", "bp-style-select");
    label.textContent = "Style";

    const select = document.createElement("select");
    select.id = "bp-style-select";
    select.innerHTML = [
      '<option value="blueprint">blueprint</option>',
      '<option value="modern">modern</option>',
      '<option value="bold">bold</option>'
    ].join("");

    const current = getSavedStyle();
    select.value = current;
    applyStyle(current);

    select.addEventListener("change", function () {
      const value = normalize(select.value);
      applyStyle(value);
      saveStyle(value);
    });

    host.appendChild(label);
    host.appendChild(select);
    document.body.appendChild(host);
  }

  applyStyle(getSavedStyle());

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", installSwitcher);
  } else {
    installSwitcher();
  }
})();"##

-- block_extension Block.dependency_graph (label : String) where
open Verso Doc Elab Genre Manual in
block_extension Block.graph (graph : Graph) where
  -- for TOC
  -- localContentItem _ _ _ := none
  data := graph.toJson
  traverse _id _data _contents := do
      return none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI _goB _id data _blocks => do
      let .ok data := fromJson? (α := Graph) data
        | HtmlT.logError "Malformed data in Block.graph.toHtml"
          pure .empty
      let s ← HtmlT.state
      let data : Graph := data.map fun node =>
        let href :=
          match s.resolveDomainObject informalDomainName node.label.toString with
          | .ok dest => some dest.relativeLink
          | .error _ => none
        ({ node with href } : GraphNode)
      return {{
        <div class="bp_graph_legend">
          <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch" style="background:#bfdbfe;"></span>"Definition"</span>
          <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch" style="background:#e9d5ff;"></span>"Lean-only def (informal missing)"</span>
          <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch" style="background:#d4f4dd;"></span>"Lean + proof"</span>
          <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch" style="background:#fff3bf;"></span>"Lean code, informal proof pending"</span>
          <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch" style="background:#f3f4f6;"></span>"Informal / text-only"</span>
          <span class="bp_graph_legend_item">"Edge styles: solid = statement deps, dashed = proof deps"</span>
        </div>
        <div id="graph">
          <script type="text/plain" class="dot-source">
            s!"{data.toDot}"
          </script>
        </div>
      }}
  extraCss := ([d3DotCss, blueprintStyleSwitcherCss] : List String)
  extraJs := ([loadD3Dot, blueprintStyleSwitcherJs] : List String)

open Verso Doc Elab Genre Manual in
block_extension Block.summary (summary : Summary) where
  data := toJson summary
  traverse _id _data _contents := do
    return none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI _goB _id data _blocks => do
      let .ok data := fromJson? (α := Summary) data
        | HtmlT.logError "Malformed data in Block.summary.toHtml"
          pure .empty
      let s ← HtmlT.state
      let getEntryHref (label : Name) : Option String :=
        match s.resolveDomainObject informalDomainName label.toString with
        | .ok dest => Option.some dest.relativeLink
        | .error _ => Option.none
      let getCodeHref (label : Name) : Option String :=
        match s.resolveDomainObject informalCodeDomainName label.toString with
        | .ok dest => Option.some dest.relativeLink
        | .error _ => Option.none
      let getDeclHref (decl : Name) : Option String :=
        match s.resolveDomainObject exampleDomainName decl.toString with
        | .ok dest => Option.some dest.relativeLink
        | .error _ =>
          match s.domains.get? exampleDomainName with
          | Option.none => Option.none
          | Option.some dom =>
            let pref := decl.toString ++ " (in "
            let cands := dom.objects.foldl (init := #[]) fun acc key _obj =>
              if key == decl.toString || key.startsWith pref then
                acc.push key
              else
                acc
            if cands.size = 1 then
              match s.resolveDomainObject exampleDomainName cands[0]! with
              | .ok dest => Option.some dest.relativeLink
              | .error _ => Option.none
            else
              Option.none
      let mkEntryRef (label : Name) :=
        match getEntryHref label with
        | Option.some href => {{ <a href={{href}}> <code>s!"{label}"</code> </a> }}
        | Option.none => {{ <code>s!"{label}"</code> }}
      let mkDeclItems (decls : List Name) :=
        decls.toArray.map fun decl =>
          match getDeclHref decl with
          | Option.some href => {{ <li><a href={{href}}> <code>s!"{decl}"</code> </a></li> }}
          | Option.none => {{ <li><code>s!"{decl}"</code></li> }}
      let pendingProofRows :=
        data.pendingInformalProofEntries.toArray.map fun item =>
          let codeHref := getCodeHref item.label
          let associatedDecls := !item.leanObjects.isEmpty
          {{ <li>
               <span class="bp_summary_item_head">{{mkEntryRef item.label}}</span>
               <span class="bp_summary_item_meta">s!"({item.kind})"</span>
               {{if associatedDecls then
                  {{<details class="bp_summary_decls"><summary>s!"Associated lean decls ({item.leanObjects.length})"</summary><ul class="bp_summary_decl_list">{{mkDeclItems item.leanObjects}}</ul></details>}}
                 else
                  {{<span></span>}}}}
               {{if let some href := codeHref then
                  {{<div class="bp_summary_item_body">"Lean code: " <a class="bp_code_link" href={{href}}>"code"</a></div>}}
                 else
                  {{<span></span>}}}}
             </li> }}
      let sorryRows :=
        data.sorryDetails.toArray.map fun item =>
          let codeHref := getCodeHref item.label
          let declLink :=
            match getDeclHref item.decl with
            | Option.some href => {{ <a href={{href}}> <code>s!"{item.decl}"</code> </a> }}
            | Option.none => {{ <code>s!"{item.decl}"</code> }}
          let whereTxt :=
            if item.typeSorryRefs > 0 && item.proofSorryRefs > 0 then
              "in statement and proof"
            else if item.typeSorryRefs > 0 then
              "in statement"
            else if item.proofSorryRefs > 0 then
              "in proof"
            else
              "location unknown"
          let sorryLinks : Array Output.Html :=
            match codeHref with
            | Option.none => #[]
            | some href =>
              let stmtLinks :=
                if item.typeSorryRefs > 0 then
                  #[{{ <a class="bp_code_link" href={{href}} title="Go to Lean code with statement sorry">s!"in statement ({item.typeSorryRefs})"</a> }}]
                else
                  #[]
              let proofLinks :=
                if item.proofSorryRefs > 0 then
                  #[{{ <a class="bp_code_link" href={{href}} title="Go to Lean code with proof sorry">s!"in proof ({item.proofSorryRefs})"</a> }}]
                else
                  #[]
              let links := stmtLinks ++ proofLinks
              if links.isEmpty then
                #[{{ <a class="bp_code_link" href={{href}}>s!"in code ({item.sorryRefs})"</a> }}]
              else
                links
          {{ <li>
               <span class="bp_summary_item_head">{{mkEntryRef item.label}}</span>
               <span class="bp_summary_item_meta">s!"({item.kind})"</span>
               <div class="bp_summary_item_body">
                 "Declaration with sorry: " {{declLink}} " "
                 <span class="bp_summary_badge">
                   s!"[{if item.isTheorem then "theorem/lemma" else "definition"}; {whereTxt}; refs: {item.sorryRefs}]"
                 </span>
               </div>
               {{if Array.isEmpty sorryLinks then
                  {{<span></span>}}
                 else
                  {{<div class="bp_summary_item_body">"Jump: " {{(sorryLinks.toList.intersperse {{<span>" | "</span>}}).toArray}}</div>}}}}
             </li> }}
      let definitionRows :=
        data.definitionIndex.toArray.map fun item =>
          let codeHref := getCodeHref item.label
          let associatedDecls := !item.leanObjects.isEmpty
          {{ <li>
               <span class="bp_summary_item_head">{{mkEntryRef item.label}}</span>
               <span class="bp_summary_item_meta">s!"({item.kind})"</span>
               {{if associatedDecls then
                  {{<details class="bp_summary_decls"><summary>s!"Associated lean decls ({item.leanObjects.length})"</summary><ul class="bp_summary_decl_list">{{mkDeclItems item.leanObjects}}</ul></details>}}
                 else
                  {{<span></span>}}}}
               {{if let some href := codeHref then
                  {{<div class="bp_summary_item_body">"Lean code: " <a class="bp_code_link" href={{href}}>"code"</a></div>}}
                 else
                  {{<span></span>}}}}
             </li> }}
      let theoremLikeRows :=
        data.theoremLikeIndex.toArray.map fun item =>
          let codeHref := getCodeHref item.label
          let associatedDecls := !item.leanObjects.isEmpty
          {{ <li>
               <span class="bp_summary_item_head">{{mkEntryRef item.label}}</span>
               <span class="bp_summary_item_meta">s!"({item.kind})"</span>
               {{if associatedDecls then
                  {{<details class="bp_summary_decls"><summary>s!"Associated lean decls ({item.leanObjects.length})"</summary><ul class="bp_summary_decl_list">{{mkDeclItems item.leanObjects}}</ul></details>}}
                 else
                  {{<span></span>}}}}
               {{if let some href := codeHref then
                  {{<div class="bp_summary_item_body">"Lean code: " <a class="bp_code_link" href={{href}}>"code"</a></div>}}
                 else
                  {{<span></span>}}}}
             </li> }}
      return {{
        <div class="bp_summary">
          <details class="bp_summary_section" open>
            <summary>s!"Blueprint DB entries ({data.totalEntries})"</summary>
            <div class="bp_summary_grid">
              <div class="bp_summary_card"><span class="bp_summary_label">"Total entries"</span><span class="bp_summary_value">s!"{data.totalEntries}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Definitions"</span><span class="bp_summary_value">s!"{data.definitions}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Lemmas"</span><span class="bp_summary_value">s!"{data.lemmas}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Theorems"</span><span class="bp_summary_value">s!"{data.theorems}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Corollaries"</span><span class="bp_summary_value">s!"{data.corollaries}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Lean-only entries"</span><span class="bp_summary_value">s!"{data.leanOnlyEntries}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Informal-only entries"</span><span class="bp_summary_value">s!"{data.informalOnlyEntries}"</span></div>
            </div>
            <details class="bp_summary_subsection">
              <summary>s!"Definition Index ({data.definitionIndex.length})"</summary>
              <ul class="bp_summary_list">
                {{if definitionRows.isEmpty then {{<li class="bp_summary_empty">"No definitions registered."</li>}} else definitionRows}}
              </ul>
            </details>
            <details class="bp_summary_subsection">
              <summary>s!"Theorem / Lemma / Corollary Index ({data.theoremLikeIndex.length})"</summary>
              <ul class="bp_summary_list">
                {{if theoremLikeRows.isEmpty then {{<li class="bp_summary_empty">"No theorem/lemma/corollary entries registered."</li>}} else theoremLikeRows}}
              </ul>
            </details>
          </details>
          <details class="bp_summary_section" open>
            <summary>"Lean progress"</summary>
            <div class="bp_summary_grid">
              <div class="bp_summary_card"><span class="bp_summary_label">"Lean definitions/theorems"</span><span class="bp_summary_value">s!"{data.leanDecls}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Entries with informal proof pending"</span><span class="bp_summary_value">s!"{data.pendingInformalProofEntries.length}"</span></div>
              <div class="bp_summary_card bp_summary_placeholder"><span class="bp_summary_label">"Sorries"</span><span class="bp_summary_value">s!"{data.sorries}"</span></div>
            </div>
            <details class="bp_summary_subsection">
              <summary>s!"Lean code with informal proof pending ({data.pendingInformalProofEntries.length})"</summary>
              <ul class="bp_summary_list">
                {{if pendingProofRows.isEmpty then {{<li class="bp_summary_empty">"No pending informal proofs."</li>}} else pendingProofRows}}
              </ul>
            </details>
            <details class="bp_summary_subsection bp_summary_placeholder">
              <summary>s!"Sorries details ({data.sorryDetails.length})"</summary>
              <ul class="bp_summary_list">
                {{if sorryRows.isEmpty then {{<li class="bp_summary_empty">"No sorries detected."</li>}} else sorryRows}}
              </ul>
            </details>
          </details>
        </div>
      }}
  extraCss := singleton ⟨d3DotCss⟩
  extraJs := singleton ⟨openTargetDetailsJs⟩
--
open Informal Data Environment
def nodeHasSorries (node : Data.Node) : Bool :=
  match node.code.info with
  | none => false
  | some info =>
    info.definedDefs.any (·.hasSorry) || info.definedTheorems.any (·.hasSorry)

def nodeColor (node : Data.Node) : String :=
  if node.code.code != .missing && node.statement == .missing then
    leanOnlyDefNodeColor
  else if node.kind == "Definition" then
    definitionNodeColor
  else if node.code.code != .missing then
    if nodeHasSorries node then sorryNodeColor
    else if node.proof != .missing then leanOkNodeColor
    else sorryNodeColor
  else
    informalNodeColor

def buildAll : CoreM Graph := do
  return (informalExt.getState (← getEnv)).data.foldl (fun label data => {
    label := label
    deps := data.deps.toList
    proofDeps := data.proofDeps.toList
    fillcolor := nodeColor data
  } :: ·) []

def countSorries (decls : Array Data.DefinedDecl) : Nat :=
  decls.foldl (init := 0) fun acc decl => acc + (if decl.hasSorry then 1 else 0)

def collectSorries (label : Name) (kind : String) (decls : Array Data.DefinedDecl) (theoremNames : NameSet) :
    List SorryItem :=
  decls.foldl (init := []) fun acc decl =>
    if decl.hasSorry then
      {
        label
        kind
        decl := decl.name
        isTheorem := theoremNames.contains decl.name
        sorryRefs := decl.sorryRefs.size
        typeSorryRefs := decl.typeSorryRefs.size
        proofSorryRefs := decl.proofSorryRefs.size
      } :: acc
    else
      acc

def kindNeedsInformalProof (kind : String) : Bool :=
  kind == "Lemma" || kind == "Theorem" || kind == "Corollary"

def buildSummary : CoreM Summary := do
  let entries := (informalExt.getState (← getEnv)).data.toArray
  return entries.foldl (init := ({} : Summary)) fun acc (label, node) =>
    let hasStatement := node.statement != .missing
    let hasProof := node.proof != .missing
    let hasCode := node.code.code != .missing
    let (leanDecls, sorries, leanObjects, sorryDetails) :=
      match node.code.info with
      | none => (0, 0, ([] : List Name), ([] : List SorryItem))
      | some info =>
        let theoremNames : NameSet := info.definedTheorems.foldl (init := {}) fun acc d => acc.insert d.name
        let leanObjects := (info.definedDefs ++ info.definedTheorems).map (fun d : Data.DefinedDecl => d.name) |>.toList
        let leanDecls := info.definedDefs.size + info.definedTheorems.size
        let allDecls := info.definedDefs ++ info.definedTheorems
        let sorries := countSorries allDecls
        let sorryDetails := collectSorries label node.kind allDecls theoremNames
        (leanDecls, sorries, leanObjects, sorryDetails)
    let pendingInformalProofEntries : List PendingProofItem :=
      if hasCode && ((kindNeedsInformalProof node.kind && !hasProof) || !hasStatement) then
        { label, kind := node.kind, leanObjects } :: acc.pendingInformalProofEntries
      else
        acc.pendingInformalProofEntries
    let definitionIndex : List IndexItem :=
      if node.kind == "Definition" then
        { label, kind := node.kind, leanObjects } :: acc.definitionIndex
      else
        acc.definitionIndex
    let theoremLikeIndex : List IndexItem :=
      if kindNeedsInformalProof node.kind then
        { label, kind := node.kind, leanObjects } :: acc.theoremLikeIndex
      else
        acc.theoremLikeIndex
    let acc := { acc with
      totalEntries := acc.totalEntries + 1
      leanOnlyEntries := acc.leanOnlyEntries + (if hasCode && !hasStatement then 1 else 0)
      informalOnlyEntries := acc.informalOnlyEntries + (if hasStatement && !hasCode then 1 else 0)
      pendingInformalProofEntries
      leanDecls := acc.leanDecls + leanDecls
      sorries := acc.sorries + sorries
      sorryDetails := sorryDetails ++ acc.sorryDetails
      definitionIndex
      theoremLikeIndex
    }
    match node.kind with
    | "Definition" => { acc with definitions := acc.definitions + 1 }
    | "Lemma" => { acc with lemmas := acc.lemmas + 1 }
    | "Theorem" => { acc with theorems := acc.theorems + 1 }
    | "Corollary" => { acc with corollaries := acc.corollaries + 1 }
    | _ => acc

-- this runs in corem as it only needs the env
open Verso Doc Elab Syntax in
def mkGraphPart (stx : Syntax) (endPos : String.Pos.Raw) : PartElabM FinishedPart := do
  let titlePreview := "Dependency Graph"
  -- XXX: Better way to do this?
  -- let titleInlines ← `(inline | $(quote titlePreview))
  let titleInlines ← `(inline | "Dependency Graph")
  let expandedTitle ← #[titleInlines].mapM (elabInline ·)
  let metadata := none
  let graph ← buildAll
  logInfo m!"Adding {graph.length} nodes"
  let block ← ``(Verso.Doc.Block.other (Block.graph $(quote graph)) #[])
  let subParts := #[]
  pure $ FinishedPart.mk stx expandedTitle titlePreview metadata #[block] subParts endPos

open Verso Doc Elab Syntax in
def mkSummaryPart (stx : Syntax) (endPos : String.Pos.Raw) : PartElabM FinishedPart := do
  let titlePreview := "Blueprint Summary"
  let titleInlines ← `(inline | "Blueprint Summary")
  let expandedTitle ← #[titleInlines].mapM (elabInline ·)
  let metadata := none
  let summary ← buildSummary
  logInfo m!"Blueprint summary for {summary.totalEntries} entries"
  let block ← ``(Verso.Doc.Block.other (Block.summary $(quote summary)) #[])
  let subParts := #[]
  pure $ FinishedPart.mk stx expandedTitle titlePreview metadata #[block] subParts endPos

open Verso Doc Elab Syntax PartElabM in
@[part_command Lean.Doc.Syntax.command]
public meta def depGraph : PartCommand
  | stx@`(block|command{blueprint_graph}) => do
    let endPos := stx.getTailPos?.get!
    -- Dependency graph is (for now) always at header level 1
    closePartsUntil 1 endPos
    addPart (← mkGraphPart stx endPos)
  | _ => (Lean.Elab.throwUnsupportedSyntax : PartElabM Unit)

open Verso Doc Elab Syntax PartElabM in
@[part_command Lean.Doc.Syntax.command]
public meta def bpSummaryCmd : PartCommand
  | stx@`(block|command{bp_summary}) => do
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkSummaryPart stx endPos)
  | stx@`(block|command{blueprint_summary}) => do
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkSummaryPart stx endPos)
  | _ => (Lean.Elab.throwUnsupportedSyntax : PartElabM Unit)
