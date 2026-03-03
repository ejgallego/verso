/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Commands
import VersoBlueprint.Commands.RenderGraph

namespace Informal.Commands

open Lean Elab Command
open Informal Data Environment

def buildAll : CoreM (Graph × Array (Name × String)) := do
  let env ← getEnv
  let state := informalExt.getState env
  let roots : Array Name := state.data.toArray.map (·.1)
  let externalAdapter := Informal.NodeFacts.ExternalDeclAdapter.ofEnv env
  let external : Informal.Graph.ExternalCodeStatus := externalAdapter.graphStatus
  let graph := Informal.Graph.buildWithExternal state roots external (resolveRef? := some)
  return (graph, state.groups.toArray)

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
  | none =>
    let configured :=
      (← getOptions).get
        verso.blueprint.graph.defaultDirection.name
        verso.blueprint.graph.defaultDirection.defValue
    match GraphDirection.parse? configured with
    | some direction => pure direction
    | none =>
      logWarning m!"Invalid value '{configured}' for option 'verso.blueprint.graph.defaultDirection'; expected LR, RL, TB, or BT. Falling back to TB."
      pure .TB
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
  let block ← ``(Verso.Doc.Block.other (Informal.Commands.Block.graph $(quote graphData)) #[])
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

end Informal.Commands
