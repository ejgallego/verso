/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import ProofWidgets.Component.Panel.Basic
import ProofWidgets.Component.HtmlDisplay
import VersoBlueprint.Data
import VersoBlueprint.Environment

open Lean Elab Command
open ProofWidgets

section BlueprintWidget

structure GraphParams where
  /-- Graph title shown in the panel summary. -/
  title : String
  /-- Informal label requested by the user. -/
  label : String
  /-- Debug rendering of the statement syntax tree. -/
  statementRepr : String
  /-- DOT source to render. -/
  dot : String
  deriving Server.RpcEncodable

@[widget_module]
def blueprintWidget : Component GraphParams where
  javascript := "
    import d3 from 'https://cdn.jsdelivr.net/npm/d3@7.9.0/+esm'
    import { graphviz } from 'https://cdn.jsdelivr.net/npm/d3-graphviz@5.6.0/+esm'
    import * as React from 'react';

    export default function ({ title, label, statementRepr, dot }) {
        const graphRef = React.useRef(null);

        React.useEffect(() => {
           if (graphRef.current && dot) {
             graphviz(graphRef.current)
               .fit(true)
               .renderDot(dot);
           }
        }, [dot]);

        const rootStyle = { display: 'grid', gap: '0.6rem' };
        const legendStyle = {
          display: 'flex',
          flexWrap: 'wrap',
          gap: '0.45rem 0.8rem',
          fontSize: '0.75rem'
        };
        const itemStyle = {
          display: 'inline-flex',
          alignItems: 'center',
          gap: '0.35rem'
        };
        const swatch = color => React.createElement('span', {
          style: {
            width: '0.7rem',
            height: '0.7rem',
            border: '1px solid #6b7280',
            borderRadius: '0.12rem',
            background: color
          }
        });

        return React.createElement('div', { style: rootStyle }, [
          React.createElement('div', {
            key: 'informal',
            style: { border: '1px solid #e2e8f0', borderRadius: '0.35rem', padding: '0.45rem 0.6rem', fontSize: '0.86rem' }
          }, [
            React.createElement('div', { key: 'title', style: { fontWeight: 600, marginBottom: '0.2rem' } },
              'Informal label rendering (placeholder)'),
            React.createElement('div', { key: 'label' }, [
              React.createElement('strong', { key: 'k' }, 'Label: '),
              React.createElement('code', { key: 'v' }, label || '(none)')
            ]),
            React.createElement('div', { key: 'math', style: { marginTop: '0.25rem' } }, [
              React.createElement('strong', { key: 'mk' }, 'Math preview: '),
              React.createElement('span', { key: 'mv' }, 'f(x) = x'),
              React.createElement('sup', { key: 'pow' }, '2'),
              React.createElement('span', { key: 'tail' }, ' + 1')
            ]),
            React.createElement('div', { key: 'todo', style: { marginTop: '0.25rem', color: '#475569' } },
              'Statement syntax debug:'),
            React.createElement('pre', {
              key: 'stx',
              style: {
                marginTop: '0.25rem',
                padding: '0.4rem',
                background: '#f8fafc',
                border: '1px solid #e2e8f0',
                borderRadius: '0.3rem',
                overflowX: 'auto',
                fontSize: '0.75rem',
                lineHeight: 1.3
              }
            }, statementRepr || '(no statement)')
          ]),
          React.createElement('details', { key: 'graphPanel', open: true }, [
            React.createElement('summary', {
              key: 'summary',
              style: { cursor: 'pointer', fontWeight: 600 }
            }, title || 'Blueprint graph'),
            React.createElement('div', { key: 'body', style: { marginTop: '0.35rem', display: 'grid', gap: '0.5rem' } }, [
              React.createElement('div', { key: 'legend', style: legendStyle }, [
                React.createElement('span', { key: 'def', style: itemStyle }, [swatch('#bfdbfe'), 'Definition']),
                React.createElement('span', { key: 'leanOnly', style: itemStyle }, [swatch('#e9d5ff'), 'Lean-only entry (informal missing)']),
                React.createElement('span', { key: 'ok', style: itemStyle }, [swatch('#d4f4dd'), 'Lean + proof']),
                React.createElement('span', { key: 'sorry', style: itemStyle }, [swatch('#fff3bf'), 'Proof pending']),
                React.createElement('span', { key: 'informal', style: itemStyle }, [swatch('#f3f4f6'), 'Informal/text-only']),
                React.createElement('span', { key: 'unresolved', style: itemStyle }, [swatch('#fee2e2'), 'Unresolved dependency']),
                React.createElement('span', { key: 'edges', style: itemStyle }, 'Edges: solid = statement, dashed = proof')
              ]),
              React.createElement('div', {
                key: 'graph',
                ref: graphRef,
                style: {
                  minHeight: '12rem',
                  border: '1px solid #cbd5e1',
                  borderRadius: '0.35rem',
                  padding: '0.25rem',
                  background: '#ffffff'
                }
              })
            ])
          ])
        ]);
    }"

end BlueprintWidget

structure GraphNode where
  label : Name
  deps : List Name
  proofDeps : List Name := []
  fillcolor : String
deriving Inhabited

def Graph := List GraphNode

def definitionNodeColor : String := "#bfdbfe"
def leanOnlyDefNodeColor : String := "#e9d5ff"
def leanOkNodeColor : String := "#d4f4dd"
def sorryNodeColor : String := "#fff3bf"
def informalNodeColor : String := "#f3f4f6"
def unresolvedDepNodeColor : String := "#fee2e2"

def nodeHasSorries (node : Informal.Data.Node) : Bool :=
  match node.code.info with
  | none => false
  | some info => info.definedConsts.any (·.hasSorry) || info.definedProofs.any (·.hasSorry)

def nodeColor (node : Informal.Data.Node) : String :=
  if node.code.code != Syntax.missing && node.statement == Syntax.missing then
    leanOnlyDefNodeColor
  else if node.kind == "Definition" then
    definitionNodeColor
  else if node.code.code != Syntax.missing then
    if nodeHasSorries node then sorryNodeColor
    else if node.proof != Syntax.missing then leanOkNodeColor
    else sorryNodeColor
  else
    informalNodeColor

def Graph.toDot (g : Graph) : String :=
  let known : NameSet := g.foldl (init := {}) fun acc node => acc.insert node.label
  let nodes := g.map fun node =>
    s!"  \"{node.label}\" [label=\"{node.label}\", fillcolor=\"{node.fillcolor}\"];"
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
  String.intercalate "\n" ([header] ++ nodes ++ edges ++ proofEdges ++ ["}"])
where
  header := r##"strict digraph "" {
  rankdir=LR;
  bgcolor="white";
  splines=true;
  nodesep=0.35;
  ranksep=0.45;
  node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=9, margin="0.05,0.03", color="#6b7280", penwidth=1.4];
  edge [color="#6b7280", arrowhead=vee, arrowsize=0.5, penwidth=0.9];
  graph [fontname="Helvetica"];"##

def mkNode (state : Informal.Environment.State) (label : Name) : GraphNode :=
  match state.data.get? label with
  | some node =>
    {
      label
      deps := node.deps.toList
      proofDeps := node.proofDeps.toList
      fillcolor := nodeColor node
    }
  | none =>
    {
      label
      deps := []
      proofDeps := []
      fillcolor := unresolvedDepNodeColor
    }

open Informal Data Environment
structure BuildResult where
  dot : String
  statementRepr : String

def buildFor (label : Name) : CoreM BuildResult := do
  let state := informalExt.getState (← getEnv)
  let some root := state.data.get? label
    | do
      let available :=
        state.data.toArray
          |>.map (·.1.toString)
          |>.take 12
      throwError m!"No Label Found for '{label}'. Known labels (first {available.size}): {String.intercalate ", " available.toList}"
  let stmtDeps : List Name := root.deps.toList.map (fun d => (d : Name))
  let prfDeps : List Name := root.proofDeps.toList.map (fun d => (d : Name))
  let labels : List Name := (label :: stmtDeps ++ prfDeps).eraseDups
  let graph : Graph := labels.map (mkNode state)
  let dot := graph.toDot
  let statementRepr :=
    if root.statement == Syntax.missing then
      "(missing statement)"
    else
      s!"{repr root.statement}"
  pure { dot, statementRepr }

open Server in
def updatePanel (title label statementRepr dot : String) stx :=
  Widget.savePanelWidgetInfo
    (blueprintWidget.javascriptHash)
    (rpcEncode ({ title, label, statementRepr, dot } : GraphParams )) stx

show_panel_widgets [local blueprintWidget]

/-- Graph command -/
syntax (name := showGraph) "#show_graph" str : command

@[command_elab showGraph]
def elabGraph : CommandElab := fun
  | stx@`(#show_graph $label:str) => do
    let target := Name.mkSimple label.getString
    let out <- liftCoreM $ buildFor target
    liftCoreM $ updatePanel s!"BluePrint widget: {target}" label.getString out.statementRepr out.dot stx
  | _ => throwUnsupportedSyntax

-- #show_graph exampleGraph
