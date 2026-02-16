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
  kind? : Option String := none
  isProof : Bool := false
  deps : Array Label
  proofDeps : Array Label := #[]
  statementElab : Array Syntax := #[]
deriving Inhabited, Repr

structure State where
  data : Data := Data.empty
  stack : List InProgress := []
  texPrelude : String := ""
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
      state.data.toArray.map fun (name, node) => (name, { node with statementElab := #[] })
  }

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
  | (false, some _, true) => logError m!"Label {label} already defined"
  | (true, some node, true) =>
    if node.proof != .missing then
      logError m!"Label {label} already has a proof"
    else return ()
  | (true, none, true) => logError m!"Cannot find proof for label {label}"
  | (_, _, false) => logError m!"Cannot declare nested definitions"

-- stack operators, to associate {uses} role to the currently opened label
def push (label : Label) (kind? : Option String) (isProof : Bool) : m Unit := do
  -- logInfo m!"push for {label} {isProof}"
  checkLabelAndNesting label isProof
  modify fun data =>
    let pdata := { label, kind?, isProof, deps := #[] }
    { data with stack := pdata :: data.stack }

def getCount : m Nat := do
  return (informalExt.getState (← getEnv)).data.size

def pop (ref : Syntax) : m Nat := do
  modifyM fun state => do match state.stack with
  | [] =>
    logError m!"Internal Error: closing non-opened directive"
    return state
  | cur :: stack =>
    let statement := if cur.isProof then none else some ref
    let proof := if cur.isProof then some ref else none
    let statementElab := if cur.isProof then #[] else cur.statementElab
    let data ← state.data.register cur.label cur.kind? cur.deps cur.proofDeps statement proof statementElab
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
    let cur :=
      if cur.isProof then
        { cur with proofDeps := cur.proofDeps.push dep }
      else
        { cur with deps := cur.deps.push dep }
    let stack := cur :: rest
    modify fun state => { state with stack }

def setStatementElab (stxs : Array Syntax) : m Unit := do
  match (informalExt.getState (← getEnv)).stack with
  | [] => pure ()
  | cur :: rest =>
    if cur.isProof then
      pure ()
    else
      let cur := { cur with statementElab := stxs }
      modify fun state => { state with stack := cur :: rest }

def registerCode (label : Label) (code : Syntax) (info : Option CodeInfo := none) : m Unit := do
  modifyM fun state => do
    let data ← state.data.registerCode label code info
    return { state with data }

def getNode? (label : Label) : m (Option Node) := do
  return (informalExt.getState (← getEnv)).data.get? label

def addTexPrelude (texPrelude : String) : m Unit := do
  let texPrelude := texPrelude.trimAscii.toString
  if texPrelude.isEmpty then
    pure ()
  else
    modify fun state =>
      let texPrelude :=
        if state.texPrelude.isEmpty then
          texPrelude
        else
          state.texPrelude ++ "\n" ++ texPrelude
      { state with texPrelude }

def getTexPrelude : m String := do
  return (informalExt.getState (← getEnv)).texPrelude

end EnvOps
