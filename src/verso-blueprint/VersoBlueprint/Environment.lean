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
  kind : Data.InProgressKind := .proof
  codeHint : Option CodeRef := none
  parent : Option Parent := none
  priority : Option String := none
  deps : Array Label := #[]
  elabStx : Array Syntax := #[]
deriving Inhabited, Repr

structure State where
  data : Data := Data.empty
  localData : NameMap Node := {}
  groups : NameMap String := {}
  localGroups : NameMap String := {}
  stack : List InProgress := []
deriving Inhabited, Repr

inductive Entry where
  | node (label : Name) (node : Node)
  | group (label : Name) (header : String)
deriving Inhabited, Repr

initialize informalExt : PersistentEnvExtension Entry Entry State ←
  registerPersistentEnvExtension {
    mkInitial := pure {}
    addEntryFn state := fun
      | .node label node =>
        { state with
          data := state.data.insert label node
          localData := state.localData.insert label node
        }
      | .group label header =>
        { state with
          groups := state.groups.insert label header
          localGroups := state.localGroups.insert label header
        }
    addImportedFn entries := do
      let (data, groups) := entries.foldl (init := (({} : NameMap Node), ({} : NameMap String))) fun acc entry =>
        entry.foldl (init := acc) fun (dataAcc, groupAcc) item =>
          match item with
          | .node label node => (dataAcc.insert label node, groupAcc)
          | .group label header => (dataAcc, groupAcc.insert label header)
      pure { data, groups }
    -- Strip transient elaboration cache before exporting nodes to the environment.
    exportEntriesFnEx env := fun state _level =>
      let nodeEntries := state.localData.toArray.map fun (name, node) =>
        let statement := node.statement.map fun s => { s with elabStx := #[] }
        let proof := node.proof.map fun p => { p with elabStx := #[] }
        Entry.node name { node with statement, proof }
      let groupEntries := state.localGroups.toArray.map fun (label, header) =>
        Entry.group label header
      nodeEntries ++ groupEntries
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
def checkLabelAndNesting (label : Label) (kind : Data.InProgressKind) : m Unit := do
  let { data, stack, .. } := informalExt.getState (← getEnv)
  match (kind, data.get? label, stack.isEmpty) with
  | (.statement _, none, true) => return ()
  | (.statement _, some node, true) =>
    if node.statement.isNone then
      return ()
    else
      logError m!"Label {label} already defined"
  | (.proof, some node, true) =>
    if node.proof.isSome then
      logError m!"Label {label} already has a proof"
    else if node.statement.isNone then
      logError m!"Cannot add proof for {label}: statement/dependencies are missing"
    else return ()
  | (.proof, none, true) => logError m!"Cannot find proof for label {label}"
  | (_, _, false) => logError m!"Cannot declare nested definitions"

-- stack operators, to associate {uses} role to the currently opened label
def push (label : Label) (kind : Data.InProgressKind)
    (codeHint : Option CodeRef := none) (parent : Option Parent := none) (priority : Option String := none) : m Unit := do
  checkLabelAndNesting label kind
  modify fun data =>
    let pdata := { label, kind, codeHint, parent, priority }
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
        let data ← state.data.register cur.label cur.kind payload cur.codeHint cur.parent cur.priority
        let localData :=
          match data.get? cur.label with
          | some node => state.localData.insert cur.label node
          | none => state.localData
        return { state with data, localData, stack }
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
    match cur.kind with
    | .proof => pure ()
    | .statement _ =>
      let cur := { cur with elabStx := stxs }
      modify fun state => { state with stack := cur :: rest }

def registerCode (label : Label) (code : Syntax)
    (definedDefs : Array LiterateDef := #[]) (definedTheorems : Array LiterateThm := #[]) : m Unit := do
  modifyM fun state => do
    let data ← state.data.registerCode label code definedDefs definedTheorems
    let localData :=
      match data.get? label with
      | some node => state.localData.insert label node
      | none => state.localData
    return { state with data, localData }

def getNode? (label : Label) : m (Option Node) := do
  return (informalExt.getState (← getEnv)).data.get? label

def registerGroup (label : Label) (header : String) : m Unit := do
  let header := header.trimAscii.toString
  modifyM fun state => do
    match state.groups.get? label with
    | none =>
      return {
        state with
        groups := state.groups.insert label header
        localGroups := state.localGroups.insert label header
      }
    | some currentHeader =>
      if currentHeader = header then
        logWarning m!"Group {label} is declared multiple times with the same header; keeping '{currentHeader}'"
      else
        logError m!"Group {label} has conflicting headers: existing '{currentHeader}', new '{header}'"
      return state

end EnvOps
