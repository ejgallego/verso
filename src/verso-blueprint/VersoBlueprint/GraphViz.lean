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
open System (FilePath)
open ProofWidgets

section GraphWidget

structure GraphParams where
  /-- Name of a constant to get the type of. -/
  dot : String
  deriving Server.RpcEncodable

@[widget_module]
def graphWidget : Component GraphParams where
  javascript := "
    import d3 from 'https://cdn.jsdelivr.net/npm/d3@7.9.0/+esm'
    import { graphviz } from 'https://cdn.jsdelivr.net/npm/d3-graphviz@5.6.0/+esm'
    import * as React from 'react';

    function loadStyle(url) {
      // Create the link element
      const link = document.createElement('link');

      link.rel = 'stylesheet';
      link.type = 'text/css';
      link.href = url;

      // Optional: Log when it's finished loading
      link.onload = () => console.log(`CSS loaded: ${url}`);
      link.onerror = () => console.error(`Error loading CSS: ${url}`);

      // Add it to the head
      document.head.appendChild(link);
    }

    // loadStyle('https://cdn.jsdelivr.net/npm/katex@0.16.28/dist/katex.min.css');

    export default function ({ dot }) {
        const containerRef = React.useRef(null);

        React.useEffect(() => {
           if (containerRef.current && dot) {
             graphviz(containerRef.current).renderDot(dot);
           }
        }, [dot]);

        return React.createElement('div', { ref: containerRef });
    }"

end GraphWidget

/-- Convert a graph to DOT format -/
def Graph := List (Name × List Name)

def header := r##"digraph Blueprint {
  rankdir=LR;
  bgcolor="white";
  splines=true;
  nodesep=0.35;
  ranksep=0.45;

  node [
    shape=box,
    style="rounded,filled",
    fontname="Helvetica",
    fontsize=10,
    margin="0.08,0.04",
    color="#6b7280"
  ];

  edge [
    color="#6b7280",
    arrowsize=0.6,
    penwidth=1
  ];"##

def graphToDot (g : Graph) : String :=
  let edges := g.flatMap fun (src, dests) =>
    dests.map fun dest => s!"  \"{src}\" -> \"{dest}\";"
  let footer := "}"
  String.intercalate "\n" ([header] ++ edges ++ [footer])

/-- Execute Graphviz to convert DOT to SVG -/
def generateSVG (dot : String) : IO String := do
  let (iFile, oFile) := ("__input.dot", "__output.svg")
  IO.FS.writeFile iFile dot
  let output ← IO.Process.output {
    cmd := "dot"
    args := #["-Tsvg", iFile, "-o", oFile]
  }
  if output.exitCode != 0 then
    throw (IO.userError s!"Graphviz failed: {output.stderr}")
  IO.FS.readFile oFile

def exampleGraph : String := r##"digraph Blueprint {
  rankdir=LR;
  bgcolor="white";
  splines=true;
  nodesep=0.35;
  ranksep=0.45;

  node [
    shape=box,
    style="rounded,filled",
    fontname="Helvetica",
    fontsize=10,
    margin="0.08,0.04",
    color="#6b7280"
  ];

  edge [
    color="#6b7280",
    arrowsize=0.6,
    penwidth=1
  ];

  // --- Nodes ---

  // mathlib
  mathlib_group [
    label="Group",
    fillcolor="#dbeafe"
  ];

  // leanok
  def_monoid [
    label="def_monoid",
    fillcolor="#d4f4dd"
  ];

  lemma_assoc [
    label="lemma_assoc",
    fillcolor="#d4f4dd"
  ];

  // sorry
  lemma_id [
    label="lemma_id",
    fillcolor="#fff3bf"
  ];

  // todo
  thm_main [
    label="main_theorem",
    fillcolor="#fde2e2"
  ];

  // informal / text
  informal_overview [
    label="Overview",
    fillcolor="#f3f4f6"
  ];

  // --- Dependencies ---

  mathlib_group -> def_monoid;
  def_monoid -> lemma_assoc;
  def_monoid -> lemma_id;
  lemma_assoc -> thm_main;
  lemma_id -> thm_main;
  informal_overview -> thm_main;
}"##

open Informal Data Environment
def buildFor (label : Name) : CoreM String := do
  let some root := (informalExt.getState (← getEnv)).data.get? label
    | throwError "No Label Found"
  -- let g := root.deps.map fun d => (d, [])
  pure $ graphToDot [(label, root.deps.toList)]

open Server in
def updatePanel (dot : String) stx :=
  Widget.savePanelWidgetInfo
    (graphWidget.javascriptHash)
    (rpcEncode ({ dot } : GraphParams )) stx


#widget graphWidget with ( { dot := exampleGraph } : GraphParams)

/-- Graph command -/
syntax (name := showGraph) "#show_graph" ident : command

@[command_elab showGraph]
def elabGraph : CommandElab := fun
  | stx@`(#show_graph $name:ident) => do
    let graph <- liftCoreM $ buildFor name.getId
    liftCoreM $ updatePanel graph stx
  | _ => throwUnsupportedSyntax

-- #show_graph elabGraph
