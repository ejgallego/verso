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

--
def Graph := List (Name × List Name) deriving ToJson, Quote

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
      return {{ <div id="graph"> s!"{data}" </div> }}
  extraJs := singleton ⟨r##"console.log("hi")"##⟩

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

--
open Informal Data Environment
def buildAll : CoreM Graph := do
  return (informalExt.getState (← getEnv)).data.foldl (fun label data => (label, data.deps.toList) :: ·) []

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

