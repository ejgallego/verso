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
import VersoBlueprint.Cite
import VersoBlueprint.Graph
import VersoBlueprint.PreviewCache
import VersoBlueprint.Resolve
import VersoBlueprint.StyleSwitcher

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

/- Blueprint summary commands, Verso -/

abbrev GraphNode := Informal.Graph.GraphNode Name
abbrev Graph := Informal.Graph.Graph Name

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
  typeSorryRefs : Nat := 0
  proofSorryRefs : Nat := 0
deriving Inhabited, FromJson, ToJson, Quote

structure IndexItem where
  label : Name
  kind : String
  leanObjects : List Name := []
deriving Inhabited, FromJson, ToJson, Quote

structure ParentTheoremGroup where
  parent : Name
  header : String := ""
  entries : List IndexItem := []
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
  theoremLikeByParent : List ParentTheoremGroup := []
deriving Inhabited, FromJson, ToJson, Quote

open Verso.Genre.Manual.Bibliography

structure BibliographyEntry where
  label : String
  citation : Citable
deriving FromJson, ToJson

structure BibliographyData where
  entries : List BibliographyEntry := []
deriving FromJson, ToJson

inductive GraphDirection where
  | LR
  | RL
  | TB
  | BT
deriving Inhabited, Repr, BEq, FromJson, ToJson, Quote

def GraphDirection.rankdir : GraphDirection → String
  | .LR => "LR"
  | .RL => "RL"
  | .TB => "TB"
  | .BT => "BT"

def GraphDirection.parse? (s : String) : Option GraphDirection :=
  match s.toLower with
  | "lr" | "left-right" | "horizontal" => some .LR
  | "rl" | "right-left" => some .RL
  | "tb" | "top-bottom" | "vertical" => some .TB
  | "bt" | "bottom-top" => some .BT
  | _ => none

structure GraphBlockData where
  graph : Graph
  direction : GraphDirection := .TB
  groupTitles : Array (Name × String) := #[]
deriving Inhabited, FromJson, ToJson, Quote

def graphDotHeader (rankdir : String) : String :=
  "strict digraph \"\" {\n" ++
  s!"    rankdir={rankdir};\n" ++
  "    bgcolor=\"white\";\n" ++
  "    splines=true;\n" ++
  "    nodesep=0.35;\n" ++
  "    ranksep=0.45;\n" ++
  "    node [shape=box, style=\"rounded,filled\", fontname=\"Helvetica\", fontsize=10, margin=\"0.08,0.04\", color=\"#6b7280\", penwidth=1.8];\n" ++
  "    edge [color=\"#6b7280\", arrowhead=vee, arrowsize=0.6, penwidth=1];\n" ++
  "    graph [fontname=\"Helvetica\"];\n" ++
  "  "

def graphToDot (g : Graph) (direction : GraphDirection := .TB)
    (resolveHref : Name → Option String := fun _ => none)
    (resolveGroupTitle : Name → Option String := fun _ => none) : String :=
  Informal.Graph.Graph.toDot g (graphDotHeader direction.rankdir)
    (groupLabel? := some resolveGroupTitle)
    (refAttrs? := some fun ref =>
    (resolveHref ref).map (fun href => s!"URL=\"{href}\", target=\"_self\""))

def loadD3Dot :=
  r##"(function () {
    function debounce(fn, waitMs) {
      let timeout = null;
      return function () {
        const args = arguments;
        clearTimeout(timeout);
        timeout = setTimeout(function () {
          fn.apply(null, args);
        }, waitMs);
      };
    }

    function layoutGraphBlock(graphBlock) {
      if (!graphBlock) return;

      graphBlock.style.left = "0px";
      graphBlock.style.width = "auto";
      graphBlock.style.maxWidth = "none";

      const main = document.querySelector(".with-toc > main");
      const blockRect = graphBlock.getBoundingClientRect();
      let left = 0;
      let right = window.innerWidth;

      if (main) {
        const mainRect = main.getBoundingClientRect();
        const mainStyle = window.getComputedStyle(main);
        const padLeft = parseFloat(mainStyle.paddingLeft) || 0;
        const padRight = parseFloat(mainStyle.paddingRight) || 0;
        left = mainRect.left + padLeft;
        right = mainRect.right - padRight;
      }

      const width = Math.max(320, right - left);
      const shift = left - blockRect.left;

      graphBlock.style.left = shift + "px";
      graphBlock.style.width = width + "px";
      graphBlock.style.maxWidth = width + "px";
    }

    function load(src) {
      return new Promise(function (resolve, reject) {
        const s = document.createElement("script");
        s.src = src;
        s.onload = resolve;
        s.onerror = reject;
        document.head.appendChild(s);
      });
    }

    function collectPreviewTemplates() {
      const map = new Map();
      const templates = document.querySelectorAll("template.bp_graph_preview_tpl[data-bp-preview-label]");
      templates.forEach(function (tpl) {
        const label = tpl.getAttribute("data-bp-preview-label") || "";
        const html = (tpl.innerHTML || "").trim();
        if (label && html) {
          map.set(label, html);
        }
      });
      return map;
    }

    function renderMath(root) {
      if (!root) return;
      if (typeof katex !== "object" || typeof katex.render !== "function") return;
      const renderAll = function (selector, displayMode) {
        root.querySelectorAll(selector).forEach(function (m) {
          if (!(m instanceof Element)) return;
          if (m.getAttribute("data-bp-math-rendered") === "1") return;
          try {
            katex.render(m.textContent || "", m, { throwOnError: false, displayMode: displayMode });
            m.setAttribute("data-bp-math-rendered", "1");
          } catch (_err) {}
        });
      };
      renderAll(".math.inline", false);
      renderAll(".math.display", true);
    }

    function attachPreviewHandlers(graphContainer, previewMap) {
      const panel = document.getElementById("bp-graph-preview");
      if (!panel) return;
      const title = panel.querySelector(".bp_graph_preview_title");
      const body = panel.querySelector(".bp_graph_preview_body");
      const hide = function () {
        panel.hidden = true;
        if (title) title.textContent = "";
        if (body) body.innerHTML = "";
      };
      if (!title || !body || previewMap.size === 0) {
        hide();
        return;
      }
      const svg = graphContainer.select("svg").node();
      if (!svg) {
        hide();
        return;
      }
      const labelFromNode = function (node) {
        if (!node) return "";
        const titleNode = node.querySelector("title");
        const titleTxt =
          titleNode && typeof titleNode.textContent === "string" ? titleNode.textContent.trim() : "";
        if (titleTxt && previewMap.has(titleTxt)) return titleTxt;
        const textNode = node.querySelector("text");
        const textTxt =
          textNode && typeof textNode.textContent === "string" ? textNode.textContent.trim() : "";
        if (textTxt && previewMap.has(textTxt)) return textTxt;
        return "";
      };
      const show = function (label) {
        const html = previewMap.get(label);
        if (!html) return;
        title.textContent = label;
        body.innerHTML = html;
        renderMath(body);
        panel.hidden = false;
      };
      const nodes = svg.querySelectorAll("g.node");
      nodes.forEach(function (node) {
        const label = labelFromNode(node);
        if (!label) return;
        node.style.cursor = "pointer";
        node.setAttribute("tabindex", "0");
        const titleNode = node.querySelector("title");
        if (titleNode) titleNode.remove();
        const all = [node].concat(Array.from(node.querySelectorAll("*")));
        all.forEach(function (el) {
          if (el.hasAttribute && el.hasAttribute("title")) {
            el.removeAttribute("title");
          }
          if (el.hasAttribute && el.hasAttribute("xlink:title")) {
            el.removeAttribute("xlink:title");
          }
          if (el.removeAttributeNS) {
            el.removeAttributeNS("http://www.w3.org/1999/xlink", "title");
          }
        });
      });
      const showFromTarget = function (target) {
        if (!(target instanceof Element)) return;
        const node = target.closest("g.node");
        if (!node) return;
        const label = labelFromNode(node);
        if (label) show(label);
      };
      svg.addEventListener("mouseover", function (ev) {
        showFromTarget(ev.target);
      });
      svg.addEventListener("focusin", function (ev) {
        showFromTarget(ev.target);
      });
      svg.addEventListener("mouseleave", hide);
    }

    Promise.resolve()
      .then(() => load("https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js"))
      .then(() => load("https://cdn.jsdelivr.net/npm/d3-graphviz@5.6.0/build/d3-graphviz.min.js"))
      .then(() => {
  const graphBlock = document.querySelector(".bp_graph_fullwidth");
  layoutGraphBlock(graphBlock);

  const graphContainer = d3.select("#graph");
  if (graphContainer.empty()) return;
  const previewMap = collectPreviewTemplates();

  const dotTxt = graphContainer
    .select("script.dot-source")
    .text()
    .trim();

  function renderGraph() {
    layoutGraphBlock(graphBlock);
    const width = graphContainer.node().clientWidth;
    const height = graphContainer.node().clientHeight;

    // graphContainer.graphviz({useWorker: true})
    const gv = graphContainer.graphviz()
      .width(width)
      .height(height)
      .fit(true)
      .on("end", function () {
        attachPreviewHandlers(graphContainer, previewMap);
      });
    gv.renderDot(dotTxt);
    // TODO: remove fallback once graphviz `end` is confirmed stable on our
    // supported browser/runtime matrix.
    // Fallback for runtimes where the graphviz `end` event is unreliable.
    setTimeout(function () {
      attachPreviewHandlers(graphContainer, previewMap);
    }, 120);
  }

  renderGraph();
  window.addEventListener("resize", debounce(renderGraph, 180));
  });
  })();
  "##

def graphTocToggleJs : String := r##"(function () {
  const className = "bp-graph-toc-hidden";
  const storageKey = "verso-blueprint-graph-toc-visible";
  if (!document.querySelector(".bp_graph_fullwidth")) return;
  if (!document.getElementById("toc")) return;

  function readVisible() {
    try {
      const saved = localStorage.getItem(storageKey);
      if (saved === "1") return true;
      if (saved === "0") return false;
    } catch (_err) {}
    return false; // default: hidden
  }

  let visible = readVisible();
  const root = document.documentElement;
  const button = document.createElement("button");
  button.id = "bp-toc-toggle";
  button.type = "button";

  function apply() {
    if (visible) root.classList.remove(className);
    else root.classList.add(className);
    button.textContent = visible ? "Hide ToC" : "Show ToC";
    window.dispatchEvent(new Event("resize"));
  }

  function persist() {
    try {
      localStorage.setItem(storageKey, visible ? "1" : "0");
    } catch (_err) {}
  }

  button.addEventListener("click", function () {
    visible = !visible;
    persist();
    apply();
  });

  if (document.body) document.body.appendChild(button);
  else document.addEventListener("DOMContentLoaded", function () {
    if (document.body) document.body.appendChild(button);
  }, { once: true });

  apply();
})();"##

def d3DotCss := include_str "graph.css"

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

def blueprintStyleSwitcherCss : String := Informal.StyleSwitcher.css

def blueprintStyleSwitcherJs : String := Informal.StyleSwitcher.jsBasic

-- block_extension Block.dependency_graph (label : String) where
open Verso Doc Elab Genre Manual in
block_extension Block.graph (graphData : GraphBlockData) where
  -- for TOC
  -- localContentItem _ _ _ := none
  data := toJson graphData
  traverse _id _data _contents := do
      return none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB _id data _blocks => do
      let graphData : GraphBlockData ←
        match fromJson? (α := GraphBlockData) data with
        | .ok gd => pure gd
        | .error _ =>
          match fromJson? (α := Graph) data with
          | .ok graph => pure { graph, direction := .TB }
          | .error _ =>
            HtmlT.logError "Malformed data in Block.graph.toHtml"
            pure { graph := #[], direction := .TB }
      let s ← HtmlT.state
      let resolveHref : Name → Option String := fun ref =>
        Resolve.resolveDomainHref? s Resolve.informalDomainName ref.toString
      let groupTitles : Lean.NameMap String :=
        graphData.groupTitles.foldl (init := ({} : Lean.NameMap String)) fun acc (group, title) =>
          acc.insert group title
      let resolveGroupTitle : Name → Option String := fun group =>
        groupTitles.get? group
      -- TODO: factor preview-domain decoding into a shared helper used by both
      -- graph and summary rendering paths.
      let previewBlocks? (label : Name) : Option (Array (Verso.Doc.Block Verso.Genre.Manual)) :=
        let decode (facet : PreviewCache.Facet) : Option (Array (Verso.Doc.Block Verso.Genre.Manual)) := do
          let key := PreviewCache.key label facet
          let obj ← s.getDomainObject? Resolve.informalPreviewDomainName key
          let entry ← (fromJson? (α := PreviewCache.Entry) obj.data).toOption
          return entry.blocks
        match decode .statement with
        | some blocks => some blocks
        | Option.none => decode .proof
      let previewTemplates ← graphData.graph.foldlM (init := (#[] : Array Output.Html)) fun acc node => do
        let some blocks := previewBlocks? node.label
          | pure acc
        let renderedBlocks ← blocks.mapM goB
        let tpl : Output.Html := {{
          <template class="bp_graph_preview_tpl" "data-bp-preview-label"={{s!"{node.label}"}}>
            {{renderedBlocks}}
          </template>
        }}
        pure <| acc.push tpl
      let previewStore : Output.Html :=
        if previewTemplates.isEmpty then
          .empty
        else
          {{
            <div class="bp_graph_preview_store" hidden>
              {{previewTemplates}}
            </div>
          }}
      let previewPanel : Output.Html :=
        if previewTemplates.isEmpty then
          .empty
        else
          {{
            <aside id="bp-graph-preview" class="bp_graph_preview" hidden>
              <div class="bp_graph_preview_title"></div>
              <div class="bp_graph_preview_body"></div>
            </aside>
          }}
      return {{
        <div class="bp_graph_fullwidth">
          <div class="bp_graph_legend">
            <div class="bp_graph_legend_group">
              <span class="bp_graph_legend_group_title">"Shapes"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_shape_box"></span>"Definition"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_shape_ellipse"></span>"Theorem / lemma / corollary"</span>
            </div>
            <div class="bp_graph_legend_group">
              <span class="bp_graph_legend_group_title">"Statement Border"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_stmt_blocked"></span>"Blocked"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_stmt_ready"></span>"Ready to formalize"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_stmt_formalized"></span>"Formalized"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_stmt_mathlib"></span>"In Mathlib"</span>
            </div>
            <div class="bp_graph_legend_group">
              <span class="bp_graph_legend_group_title">"Background Status"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_proof_none"></span>"Not ready"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_proof_ready"></span>"Ready to formalize"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_proof_formalized"></span>"Formalized"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_proof_anc"></span>"Formalized + ancestors"</span>
            </div>
            <div class="bp_graph_legend_group">
              <span class="bp_graph_legend_group_title">"Warning Overlays"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_warn_unknown"></span>"Unknown reference"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_warn_lean_only"></span>"Lean code, informal statement missing"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_warn_missing_external"></span>"External Lean declaration missing"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_warn_local_sorries"></span>"Local sorries"</span>
              <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch bp_graph_legend_warn_deps"></span>"Formalized node with incomplete ancestors"</span>
            </div>
            <div class="bp_graph_legend_group">
              <span class="bp_graph_legend_group_title">"Edges"</span>
              <span class="bp_graph_legend_item">"Solid: theorem/lemma deps"</span>
              <span class="bp_graph_legend_item">"Dashed: definition-source deps"</span>
              <span class="bp_graph_legend_item">"Dotted: proof-only deps"</span>
            </div>
          </div>
          <div id="graph">
            <script type="text/plain" class="dot-source">
              s!"{graphToDot graphData.graph graphData.direction resolveHref resolveGroupTitle}"
            </script>
          </div>
          {{previewStore}}
          {{previewPanel}}
        </div>
      }}
  extraCss := ([d3DotCss, blueprintStyleSwitcherCss] : List String)
  extraJs := ([loadD3Dot, graphTocToggleJs, blueprintStyleSwitcherJs] : List String)

open Verso Doc Elab Genre Manual in
block_extension Block.summary (summary : Summary) where
  data := toJson summary
  traverse _id _data _contents := do
    return none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB _id data _blocks => do
      let .ok data := fromJson? (α := Summary) data
        | HtmlT.logError "Malformed data in Block.summary.toHtml"
          pure .empty
      let s ← HtmlT.state
      -- TODO: factor preview-domain decoding into a shared helper used by both
      -- graph and summary rendering paths.
      let previewBlocks? (label : Name) : Option (Array (Verso.Doc.Block Verso.Genre.Manual)) :=
        let decode (facet : PreviewCache.Facet) : Option (Array (Verso.Doc.Block Verso.Genre.Manual)) := do
          let key := PreviewCache.key label facet
          let obj ← s.getDomainObject? Resolve.informalPreviewDomainName key
          let entry ← (fromJson? (α := PreviewCache.Entry) obj.data).toOption
          return entry.blocks
        match decode .statement with
        | some blocks => some blocks
        | Option.none => decode .proof
      let getEntryHref (label : Name) : Option String :=
        Resolve.resolveDomainHref? s Resolve.informalDomainName label.toString
      let getCodeHref (label : Name) : Option String :=
        Resolve.resolveDomainHref? s Resolve.informalCodeDomainName label.toString
      let getDeclHref (decl : Name) : Option String :=
        Resolve.resolveExampleDeclHref? s decl
      let mkEntryRef (label : Name) := do
        -- TODO: unify preview UI behavior between graph and summary pages.
        let preview? : Option Output.Html ←
          match previewBlocks? label with
          | Option.none => pure none
          | some blocks =>
            let rendered ← blocks.mapM goB
            pure <| some {{
              <div class="bp_summary_preview" role="tooltip">
                <div class="bp_summary_preview_title"><code>s!"{label}"</code></div>
                <div class="bp_summary_preview_body">{{rendered}}</div>
              </div>
            }}
        let labelNode : Output.Html :=
          match getEntryHref label with
          | Option.some href => {{ <a href={{href}}> <code>s!"{label}"</code> </a> }}
          | Option.none => {{ <code>s!"{label}"</code> }}
        pure {{
          <span class="bp_summary_preview_wrap">
            {{labelNode}}
            {{if let some preview := preview? then preview else .empty}}
          </span>
        }}
      let mkDeclItems (decls : List Name) :=
        decls.toArray.map fun decl =>
          match getDeclHref decl with
          | Option.some href => {{ <li><a href={{href}}> <code>s!"{decl}"</code> </a></li> }}
          | Option.none => {{ <li><code>s!"{decl}"</code></li> }}
      let mkLeanRow (label : Name) (kind : String) (leanObjects : List Name) := do
        let entryRef ← mkEntryRef label
        let codeHref := getCodeHref label
        let associatedDecls := !leanObjects.isEmpty
        pure {{ <li>
                  <span class="bp_summary_item_head">{{entryRef}}</span>
                  <span class="bp_summary_item_meta">s!"({kind})"</span>
                  {{if associatedDecls then
                     {{<details class="bp_summary_decls"><summary>s!"Associated lean decls ({leanObjects.length})"</summary><ul class="bp_summary_decl_list">{{mkDeclItems leanObjects}}</ul></details>}}
                    else
                     {{<span></span>}}}}
                  {{if let some href := codeHref then
                     {{<div class="bp_summary_item_body">"Lean code: " <a class="bp_code_link" href={{href}}>"code"</a></div>}}
                    else
                     {{<span></span>}}}}
                </li> }}
      let pendingProofRows ←
        data.pendingInformalProofEntries.toArray.mapM fun item =>
          mkLeanRow item.label item.kind item.leanObjects
      let sorryRows ←
        data.sorryDetails.toArray.mapM fun item => do
          let entryRef ← mkEntryRef item.label
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
          let sorryRefs := item.typeSorryRefs + item.proofSorryRefs
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
                #[{{ <a class="bp_code_link" href={{href}}>s!"in code ({sorryRefs})"</a> }}]
              else
                links
          pure {{ <li>
                    <span class="bp_summary_item_head">{{entryRef}}</span>
                    <span class="bp_summary_item_meta">s!"({item.kind})"</span>
                    <div class="bp_summary_item_body">
                      "Declaration with sorry: " {{declLink}} " "
                      <span class="bp_summary_badge">
                        s!"[{if item.isTheorem then "theorem/lemma" else "definition"}; {whereTxt}; refs: {sorryRefs}]"
                      </span>
                    </div>
                    {{if Array.isEmpty sorryLinks then
                       {{<span></span>}}
                      else
                       {{<div class="bp_summary_item_body">"Jump: " {{(sorryLinks.toList.intersperse {{<span>" | "</span>}}).toArray}}</div>}}}}
                  </li> }}
      let definitionRows ←
        data.definitionIndex.toArray.mapM fun item =>
          mkLeanRow item.label item.kind item.leanObjects
      let theoremLikeRows ←
        data.theoremLikeIndex.toArray.mapM fun item =>
          mkLeanRow item.label item.kind item.leanObjects
      let theoremLikeByParentRows ←
        data.theoremLikeByParent.toArray.mapM fun group => do
          let rows ← group.entries.toArray.mapM fun item =>
            mkLeanRow item.label item.kind item.leanObjects
          pure {{
            <details class="bp_summary_subsection">
              <summary>s!"{group.header} ({group.entries.length})"</summary>
              <ul class="bp_summary_list">
                {{if rows.isEmpty then {{<li class="bp_summary_empty">"No theorem/lemma/corollary entries in this parent group."</li>}} else rows}}
              </ul>
            </details>
          }}
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
            <details class="bp_summary_subsection">
              <summary>s!"Theorem / Lemma / Corollary by Parent ({data.theoremLikeByParent.length})"</summary>
              {{if theoremLikeByParentRows.isEmpty then
                 {{<div class="bp_summary_empty">"No parent groups declared for theorem-like entries."</div>}}
                else
                 theoremLikeByParentRows}}
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

open Verso Doc Elab Genre Manual in
block_extension Block.bibliography (biblio : BibliographyData) where
  data := toJson biblio
  traverse id data _contents := do
    let .ok biblio := fromJson? (α := BibliographyData) data
      | logError "Malformed data in Block.bibliography.traverse"
        return none
    let path ← (·.path) <$> read
    let _ ← Verso.Genre.Manual.externalTag id path s!"--bp-bibliography"
    for entry in biblio.entries do
      modify fun st =>
        st.saveDomainObject Resolve.bibliographyDomainName entry.label id
    return none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun goI _goB _id data _blocks => do
      let .ok data := fromJson? (α := BibliographyData) data
        | HtmlT.logError "Malformed data in Block.bibliography.toHtml"
          pure .empty
      let st ← HtmlT.state
      let entries := data.entries.toArray.qsort (fun a b => a.citation.sortKey < b.citation.sortKey)
      let rows ← entries.mapM fun entry => do
        let rendered ← entry.citation.bibHtml goI
        let itemId := s!"bp-bib-{Informal.Cite.citationAnchorId entry.label}"
        let usageHrefs := Resolve.resolveDomainHrefs st Resolve.citationUsageDomainName entry.label
        let usageData : Informal.Cite.CitationUsageData :=
          match st.getDomainObject? Resolve.citationUsageDomainName entry.label with
          | some obj =>
            match fromJson? (α := Informal.Cite.CitationUsageData) obj.data with
            | .ok data => data
            | .error _ => {}
          | Option.none => {}
        let usageDetails := usageData.uses.toArray.qsort (fun a b => a.href < b.href)
        let usageRows : Array Output.Html :=
          if usageDetails.isEmpty then
            usageHrefs.foldl (init := #[]) fun out href =>
              out.push {{<li><a href={{href}}>s!"Citation use {out.size + 1}"</a></li>}}
          else
            usageDetails.map fun use =>
              {{<li><a href={{use.href}}>{{.text true use.summary}}</a></li>}}
        let usageCount := if usageDetails.isEmpty then usageHrefs.size else usageDetails.size
        pure {{
          <li id={{itemId}}>
            {{rendered}}
            <details class="bp_summary_decls">
              <summary>s!"Cited from ({usageCount})"</summary>
              <ul class="bp_summary_decl_list">
                {{if usageRows.isEmpty then {{<li class="bp_summary_empty">"No citation uses recorded."</li>}} else usageRows}}
              </ul>
            </details>
          </li>
        }}
      pure {{
        <div class="bp_summary">
          <details class="bp_summary_section" open>
            <summary>s!"Bibliography ({entries.size})"</summary>
            <ul class="bp_summary_list">
              {{if rows.isEmpty then {{<li class="bp_summary_empty">"No bibliography entries registered."</li>}} else rows}}
            </ul>
          </details>
        </div>
      }}
  extraCss := singleton ⟨d3DotCss⟩
  extraJs := singleton ⟨openTargetDetailsJs⟩
--
open Informal Data Environment
def externalDeclMissing (env : Lean.Environment) (decl : Name) : Bool :=
  let decl := decl.eraseMacroScopes
  (env.find? decl).isNone

def externalDeclHasTypeSorry (env : Lean.Environment) (decl : Name) : Bool :=
  let decl := decl.eraseMacroScopes
  match env.find? decl with
  | none => false
  | some info => info.type.hasSorry

def externalDeclHasProofSorry (env : Lean.Environment) (decl : Name) : Bool :=
  let decl := decl.eraseMacroScopes
  match env.find? decl with
  | none => false
  | some info => info.value?.map (·.hasSorry) |>.getD false

def buildAll : CoreM (Graph × Array (Name × String)) := do
  let env ← getEnv
  let state := informalExt.getState env
  let roots : Array Name := state.data.toArray.map (·.1)
  let external : Informal.Graph.ExternalCodeStatus := {
    isMissing := externalDeclMissing env
    hasTypeSorry := externalDeclHasTypeSorry env
    hasProofSorry := externalDeclHasProofSorry env
  }
  let graph := Informal.Graph.buildWithExternal state roots external (resolveRef? := some)
  return (graph, state.groups.toArray)

def countDefSorries (decls : Array Data.LiterateDef) : Nat :=
  decls.foldl (init := 0) fun acc decl => acc + (if decl.hasSorry then 1 else 0)

def countThmSorries (decls : Array Data.LiterateThm) : Nat :=
  decls.foldl (init := 0) fun acc decl => acc + (if decl.hasSorry then 1 else 0)

def collectDefSorries (label : Name) (kind : String) (decls : Array Data.LiterateDef) (theoremNames : NameSet) :
    List SorryItem :=
  decls.foldl (init := []) fun acc decl =>
    if decl.hasSorry then
      {
        label
        kind
        decl := decl.name
        isTheorem := theoremNames.contains decl.name
        typeSorryRefs := decl.typeSorryRefs.size
        proofSorryRefs := 0
      } :: acc
    else
      acc

def collectThmSorries (label : Name) (kind : String) (decls : Array Data.LiterateThm) (theoremNames : NameSet) :
    List SorryItem :=
  decls.foldl (init := []) fun acc decl =>
    if decl.hasSorry then
      {
        label
        kind
        decl := decl.name
        isTheorem := theoremNames.contains decl.name
        typeSorryRefs := decl.typeSorryRefs.size
        proofSorryRefs := decl.proofSorryRefs.size
      } :: acc
    else
      acc

def kindNeedsInformalProof (kind : Data.NodeKind) : Bool :=
  kind == Data.NodeKind.lemma || kind == Data.NodeKind.theorem || kind == Data.NodeKind.corollary

def addParentTheoremLikeItem (groups : NameMap (List IndexItem)) (parent : Name) (item : IndexItem) :
    NameMap (List IndexItem) :=
  groups.insert parent (item :: groups.getD parent [])

def buildSummary : CoreM Summary := do
  let state := informalExt.getState (← getEnv)
  let entries := state.data.toArray
  let parentChildren := state.data.parentChildren
  let groupHeaders := state.groups
  let summary := entries.foldl (init := ({} : Summary)) fun acc (label, node) =>
      let hasStatement := node.statement.isSome
      let hasProof := node.proof.isSome
      let hasCode := node.code.isSome
      let (leanDecls, sorries, leanObjects, sorryDetails) :=
        match node.code with
        | none => (0, 0, ([] : List Name), ([] : List SorryItem))
        | some .userOk =>
          (0, 0, ([] : List Name), ([] : List SorryItem))
        | some (.external decls) =>
          (decls.size, 0, (decls.map (·.canonical)).toList, ([] : List SorryItem))
        | some (.literate code) =>
          let theoremNames : NameSet := code.definedTheorems.foldl (init := {}) fun acc (d : Data.LiterateThm) => acc.insert d.name
          let leanObjects := (code.definedDefs.map (·.name) ++ code.definedTheorems.map (·.name)).toList
          let leanDecls := code.definedDefs.size + code.definedTheorems.size
          let sorries := countDefSorries code.definedDefs + countThmSorries code.definedTheorems
          let sorryDetails :=
            collectDefSorries label (toString node.kind) code.definedDefs theoremNames ++
            collectThmSorries label (toString node.kind) code.definedTheorems theoremNames
          (leanDecls, sorries, leanObjects, sorryDetails)
      let pendingInformalProofEntries : List PendingProofItem :=
        if hasCode && ((kindNeedsInformalProof node.kind && !hasProof) || !hasStatement) then
          { label, kind := toString node.kind, leanObjects } :: acc.pendingInformalProofEntries
        else
          acc.pendingInformalProofEntries
      let definitionIndex : List IndexItem :=
        if node.kind == Data.NodeKind.definition then
          { label, kind := toString node.kind, leanObjects } :: acc.definitionIndex
        else
          acc.definitionIndex
      let theoremLikeIndex : List IndexItem :=
        if kindNeedsInformalProof node.kind then
          { label, kind := toString node.kind, leanObjects } :: acc.theoremLikeIndex
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
      | Data.NodeKind.definition => { acc with definitions := acc.definitions + 1 }
      | Data.NodeKind.lemma => { acc with lemmas := acc.lemmas + 1 }
      | Data.NodeKind.theorem => { acc with theorems := acc.theorems + 1 }
      | Data.NodeKind.corollary => { acc with corollaries := acc.corollaries + 1 }
  let theoremLikeByParent : List ParentTheoremGroup :=
    let grouped := entries.foldl (init := ({} : NameMap (List IndexItem))) fun acc (label, node) =>
      if kindNeedsInformalProof node.kind then
        let leanObjects : List Name :=
          match node.code with
          | some (.external decls) => (decls.map (·.canonical)).toList
          | some (.literate code) =>
            (code.definedDefs.map (·.name) ++ code.definedTheorems.map (·.name)).toList
          | _ => []
        match node.parent with
        | some parent =>
          let item : IndexItem := { label, kind := toString node.kind, leanObjects }
          addParentTheoremLikeItem acc parent item
        | none => acc
      else
        acc
    grouped.toArray.toList.foldr (init := []) fun (parent, items) acc =>
      if (parentChildren.getD parent #[]).size <= 1 then
        acc
      else
        let header := groupHeaders.getD parent parent.toString
        { parent, header, entries := items.reverse } :: acc
  return { summary with theoremLikeByParent }

open Verso.ArgParse

instance : FromArgVal GraphDirection Verso.Doc.Elab.PartElabM where
  fromArgVal := {
    description := doc!"graph direction (`LR`, `RL`, `TB`, or `BT`)"
    signature := CanMatch.Ident ∪ CanMatch.String
    get := fun
      | .name id =>
        match GraphDirection.parse? id.getId.toString with
        | some d => pure d
        | none => throwErrorAt id "Expected one of `LR`, `RL`, `TB`, `BT`"
      | .str s =>
        match GraphDirection.parse? s.getString with
        | some d => pure d
        | none => throwErrorAt s "Expected one of \"lr\", \"rl\", \"tb\", \"bt\""
      | other =>
        throwError "Expected a direction identifier or string, got {toMessageData other}"
  }

structure BlueprintGraphConfig where
  direction : Option GraphDirection := none

instance : FromArgs BlueprintGraphConfig Verso.Doc.Elab.PartElabM where
  fromArgs := BlueprintGraphConfig.mk <$> .named' `direction true

def parseGraphDirection (cfg : BlueprintGraphConfig) : Verso.Doc.Elab.PartElabM GraphDirection := do
  match cfg.direction with
  | none => pure .TB
  | some direction => pure direction

-- this runs in corem as it only needs the env
open Verso Doc Elab Syntax in
def mkGraphPart (stx : Syntax) (endPos : String.Pos.Raw) (direction : GraphDirection := .TB) : PartElabM FinishedPart := do
  let titlePreview := "Dependency Graph"
  -- XXX: Better way to do this?
  -- let titleInlines ← `(inline | $(quote titlePreview))
  let titleInlines ← `(inline | "Dependency Graph")
  let expandedTitle ← #[titleInlines].mapM (elabInline ·)
  let metadata := none
  let (graph, groupTitles) ← buildAll
  logInfo m!"Adding {graph.size} nodes"
  let graphData : GraphBlockData := { graph, direction, groupTitles }
  let block ← ``(Verso.Doc.Block.other (Block.graph $(quote graphData)) #[])
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

open Verso Doc Elab Syntax in
def mkBibliographyPart (stx : Syntax) (endPos : String.Pos.Raw) : PartElabM FinishedPart := do
  let titlePreview := "Blueprint Bibliography"
  let titleInlines ← `(inline | "Blueprint Bibliography")
  let expandedTitle ← #[titleInlines].mapM (elabInline ·)
  let metadata := none
  let entries := Informal.Cite.allBibEntries (← getEnv)
  logInfo m!"Blueprint bibliography for {entries.length} entries"
  let refs : Array (TSyntax `term) ← entries.toArray.mapM fun (label, decl) =>
    `(BibliographyEntry.mk $(quote label) $(mkIdent decl))
  let block ← ``(Verso.Doc.Block.other
    (Block.bibliography (BibliographyData.mk (entries := ([$refs,*] : List BibliographyEntry)))) #[])
  let subParts := #[]
  pure $ FinishedPart.mk stx expandedTitle titlePreview metadata #[block] subParts endPos

open Verso Doc Elab Syntax PartElabM in
@[part_command Lean.Doc.Syntax.command]
public meta def depGraph : PartCommand
  | stx@`(block|command{blueprint_graph $args*}) => do
    let cfg ← Verso.ArgParse.parseThe BlueprintGraphConfig (← parseArgs args)
    let direction ← parseGraphDirection cfg
    let endPos := stx.getTailPos?.get!
    -- Dependency graph is (for now) always at header level 1
    closePartsUntil 1 endPos
    addPart (← mkGraphPart stx endPos direction)
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

open Verso Doc Elab Syntax PartElabM in
@[part_command Lean.Doc.Syntax.command]
public meta def bpBibliographyCmd : PartCommand
  | stx@`(block|command{bp_bibliography}) => do
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkBibliographyPart stx endPos)
  | stx@`(block|command{blueprint_bibliography}) => do
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkBibliographyPart stx endPos)
  | _ => (Lean.Elab.throwUnsupportedSyntax : PartElabM Unit)
