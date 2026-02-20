/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean.CoreM
import Lean.EnvExtension
import VersoBlueprint.Data

namespace Informal.Environment

open Lean
open Informal.Data

structure InProgress where
  label : Label
  kind? : Option NodeKind := none
  isProof : Bool := false
  codeHint : Option CodeRef := none
  deps : Array Label := #[]
  elabStx : Array Syntax := #[]
deriving Inhabited, Repr

structure State where
  data : Data := Data.empty
  stack : List InProgress := []
deriving Inhabited, Repr

initialize informalExt : PersistentEnvExtension (Name × Node) (Name × Node) State ←
  registerPersistentEnvExtension {
    mkInitial := pure {}
    -- we should merge
    addEntryFn state := fun (label, node) => { state with data := state.data.insert label node }
    addImportedFn entries := do
      let data := entries.foldl (init := Std.TreeMap.empty) fun acc entry =>
        entry.foldl (init := acc) fun acc (name, node) =>
           acc.insert name node
      pure $ { data }
    -- Strip transient elaboration cache before exporting nodes to the environment.
    exportEntriesFnEx env := fun state _level =>
      state.data.toArray.map fun (name, node) =>
        let statement := node.statement.map fun s => { s with elabStx := #[] }
        let proof := node.proof.map fun p => { p with elabStx := #[] }
        (name, { node with statement, proof })
  }

private structure TexPreludeState where
  prelude : Array String := #[]
  localPrelude : Array String := #[]
deriving Inhabited

private def pushUnique (chunks : Array String) (chunk : String) : Array String :=
  if chunks.contains chunk then chunks else chunks.push chunk

initialize texPreludeExt : PersistentEnvExtension String String TexPreludeState ←
  registerPersistentEnvExtension {
    mkInitial := pure {}
    addImportedFn entries := do
      let prelude :=
        entries.foldl (init := #[]) fun acc entry =>
          entry.foldl (init := acc) pushUnique
      pure { prelude }
    addEntryFn := fun state chunk =>
      if state.prelude.contains chunk then
        state
      else
        { prelude := state.prelude.push chunk, localPrelude := state.localPrelude.push chunk }
    exportEntriesFn state := state.localPrelude
  }

private def joinChunks (chunks : Array String) : String :=
  chunks.foldl (init := "") fun acc chunk =>
    if acc.isEmpty then
      chunk
    else
      acc ++ "\n" ++ chunk

section EnvOps

variable [Monad m] [MonadEnv m] [MonadLog m] [AddMessageContext m] [MonadOptions m]

def modify (f : State -> State) : m Unit :=
  modifyEnv (informalExt.modifyState · f)

def modifyM (f : State -> m State) : m Unit := do
  let st := informalExt.getState (← getEnv)
  let st ← f st
  modifyEnv (informalExt.setState · st)

-- XXX: needs: test
def checkLabelAndNesting (label : Label) (isProof : Bool) : m Unit := do
  let { data, stack, .. } := informalExt.getState (← getEnv)
  match (isProof, data.get? label, stack.isEmpty) with
  | (false, none, true) => return ()
  | (false, some node, true) =>
    if node.statement.isNone then
      return ()
    else
      logError m!"Label {label} already defined"
  | (true, some node, true) =>
    if node.proof.isSome then
      logError m!"Label {label} already has a proof"
    else if node.statement.isNone then
      logError m!"Cannot add proof for {label}: statement/dependencies are missing"
    else return ()
  | (true, none, true) => logError m!"Cannot find proof for label {label}"
  | (_, _, false) => logError m!"Cannot declare nested definitions"

-- stack operators, to associate {uses} role to the currently opened label
def push (label : Label) (kind? : Option NodeKind) (isProof : Bool)
    (codeHint : Option CodeRef := none) : m Unit := do
  -- logInfo m!"push for {label} {isProof}"
  checkLabelAndNesting label isProof
  modify fun data =>
    let pdata := { label, kind?, isProof, codeHint }
    { data with stack := pdata :: data.stack }

def getCount : m Nat := do
  return (informalExt.getState (← getEnv)).data.size

/-- When unwinding a nested declaration, discard only the nested frame and keep `data` unchanged. -/
def State.popNested? (state : State) : Option State :=
  match state.stack with
  | _ :: stack =>
    if stack.isEmpty then
      none
    else
      some { state with stack }
  | [] => none

def pop (ref : Syntax) : m Nat := do
  modifyM fun state => do
    if let some state := state.popNested? then
      return state
    else
      match state.stack with
      | [] =>
        logError m!"Internal Error: closing non-opened directive"
        return state
      | cur :: stack =>
        let payload : InformalData := {
          stx := ref
          deps := cur.deps
          elabStx := cur.elabStx
        }
        let statement := if cur.isProof then none else some payload
        let proof := if cur.isProof then some payload else none
        let data ← state.data.register cur.label cur.kind? statement proof cur.codeHint
        return { state with data, stack }
  getCount

def peek : m (Option InProgress) := do
  return (informalExt.getState (← getEnv)).stack.head?

def stack : m (List InProgress) := do
  return (informalExt.getState (← getEnv)).stack

def addDep (stx : Syntax) (dep : Name) : m Unit := do
  match (informalExt.getState (← getEnv)).stack with
  | [] =>
    logErrorAt stx m!"uses declaration outside an informal enviroment"
    pure ()
  | cur :: rest =>
    let cur := { cur with deps := cur.deps.push dep }
    let stack := cur :: rest
    modify fun state => { state with stack }

def setStatementElab (stxs : Array Syntax) : m Unit := do
  match (informalExt.getState (← getEnv)).stack with
  | [] => pure ()
  | cur :: rest =>
    if cur.isProof then
      pure ()
    else
      let cur := { cur with elabStx := stxs }
      modify fun state => { state with stack := cur :: rest }

def registerCode (label : Label) (code : Syntax)
    (definedDefs : Array DefinedDecl := #[]) (definedTheorems : Array DefinedDecl := #[]) : m Unit := do
  modifyM fun state => do
    let data ← state.data.registerCode label code definedDefs definedTheorems
    return { state with data }

def getNode? (label : Label) : m (Option Node) := do
  return (informalExt.getState (← getEnv)).data.get? label

def addTexPrelude (texPrelude : String) : m Unit := do
  let texPrelude := texPrelude.trimAscii.toString
  if texPrelude.isEmpty then
    pure ()
  else
    modifyEnv (texPreludeExt.addEntry · texPrelude)

def getTexPrelude : m String := do
  return joinChunks (texPreludeExt.getState (← getEnv)).prelude

end EnvOps
