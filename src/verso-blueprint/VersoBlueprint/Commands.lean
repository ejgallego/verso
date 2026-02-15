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
  fillcolor : String
  href : Option String := none
deriving FromJson, ToJson, Quote

def Graph := List GraphNode deriving FromJson, ToJson, Quote

def definitionNodeColor : String := "#bfdbfe" -- Definition
def leanOnlyDefNodeColor : String := "#e9d5ff" -- Lean-only definition, informal object missing
def leanOkNodeColor : String := "#d4f4dd" -- Lean + proof available
def sorryNodeColor : String := "#fff3bf" -- Lean only / proof pending
def todoNodeColor : String := "#fde2e2" -- Missing Lean/proof
def informalNodeColor : String := "#f3f4f6" -- Informal/proof-only
def informalDomainName : Name := Name.mkSimple "Informal.Block.informal"

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
  let footer := "}"
  String.intercalate "\n" ([header] ++ nodes ++ edges ++ [footer])
where
  header := r##"strict digraph "" {
    rankdir=LR;
    bgcolor="white";
    splines=true;
    nodesep=0.35;
    ranksep=0.45;
    node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=10, margin="0.08,0.04", color="#6b7280", penwidth=1.8];
    edge [color="#6b7280", arrowhead=vee, arrowsize=0.6, penwidth=1];
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

def d3DotCss := r##"div#graph {
  width: 100%;
  height: 90vh;
  resize: both;
  overflow: hidden; }

.bp_graph_legend {
  margin-top: 0.75rem;
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem 1rem;
  font-size: 0.92rem;
}

.bp_graph_legend_item {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
}

.bp_graph_legend_swatch {
  display: inline-block;
  width: 0.9rem;
  height: 0.9rem;
  border-radius: 0.2rem;
  border: 1px solid #6b7280;
}
"##

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
          <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch" style="background:#fff3bf;"></span>"Lean proof, informal proof pending"</span>
          <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch" style="background:#f3f4f6;"></span>"Informal / text-only"</span>
          <span class="bp_graph_legend_item"><span class="bp_graph_legend_swatch" style="background:#fde2e2;"></span>"Todo"</span>
        </div>
        <div id="graph">
          <script type="text/plain" class="dot-source">
            s!"{data.toDot}"
          </script>
        </div>
      }}
  extraCss := singleton ⟨d3DotCss⟩
  extraJs := singleton ⟨loadD3Dot⟩
--
open Informal Data Environment
def nodeColor (node : Data.Node) : String :=
  if node.code.code != .missing && node.count == 0 then
    leanOnlyDefNodeColor
  else if node.kind == "Definition" then
    definitionNodeColor
  else if node.code.code != .missing then
    if node.proof != .missing then leanOkNodeColor else sorryNodeColor
  else if node.proof != .missing then
    informalNodeColor
  else
    todoNodeColor

def buildAll : CoreM Graph := do
  return (informalExt.getState (← getEnv)).data.foldl (fun label data => {
    label := label
    deps := data.deps.toList
    fillcolor := nodeColor data
  } :: ·) []

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

open Verso Doc Elab Syntax PartElabM in
@[part_command Lean.Doc.Syntax.command]
public meta def depGraph : PartCommand
  | stx@`(block|command{blueprint_graph}) => do
    let endPos := stx.getTailPos?.get!
    -- Dependency graph is (for now) always at header level 1
    closePartsUntil 1 endPos
    addPart (← mkGraphPart stx endPos)
  | _ => (Lean.Elab.throwUnsupportedSyntax : PartElabM Unit)
