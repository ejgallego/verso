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
  deps : Array Label
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
    exportEntriesFnEx env := fun state _level => state.data.toArray
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
  let { data, stack } := informalExt.getState (← getEnv)
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
    let pdata := { label, kind?, deps := #[] }
    { data with stack := pdata :: data.stack }

def getCount : m Nat := do
  return (informalExt.getState (← getEnv)).data.size

def pop (isProof : Option Syntax) : m Nat := do
  modifyM fun state => do match state.stack with
  | [] =>
    logError m!"Internal Error: closing non-opened directive"
    return state
  | cur :: stack =>
    let data ← state.data.register cur.label cur.kind? cur.deps isProof
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

def registerCode (label : Label) (code : Syntax) (info : Option CodeInfo := none) : m Unit := do
  modifyM fun state => do
    let data ← state.data.registerCode label code info
    return { state with data }

def getNode? (label : Label) : m (Option Node) := do
  return (informalExt.getState (← getEnv)).data.get? label

end EnvOps
