/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Lean.Data.Json

namespace Informal.Data

open Lean

set_option doc.verso true
-- set_option pp.rawOnError true

-- informal object labels are names for now, but that could change
@[expose]
def Label := Name
deriving Repr, Inhabited, ToString, ToMessageData, ToJson, FromJson, Quote

@[expose] def LabelMap A := NameMap A

instance [Repr A] : Repr (LabelMap A) := inferInstanceAs <| Repr (NameMap A)

/-- Information about a code block, including Lean-level analysis -/
structure CodeInfo where
  proved : Bool := false
  deps : Array Label := #[]
deriving Repr, Inhabited

-- def CodeInfo.get (name : Name) : CodeInfo := by sorry

structure Code where
  code : Syntax := .missing
  info : Option CodeInfo
deriving Repr, Inhabited

structure Node where
  kind : String := "Lemma"
  statement : Syntax := .missing -- Informal Object statement
  proof : Syntax := .missing -- Informal Object proof
  code : Syntax := .missing -- Informal Object associated code
  deps : Array Label := #[] -- Informal Object deps
deriving Repr, Inhabited

/-- Map of labels to Node data -/
def Data := LabelMap Node
deriving Repr, Inhabited

/-- We can state a theorem if all its deps are done, and the theorem isn't "not ready" -/
def Data.empty : Data := Std.TreeMap.empty

/-- We can state a theorem if all its deps are done, and the theorem isn't "not ready" -/
def Data.can_state : Bool := false

/-- all of the deps are OK, including the proof -/
def Data.can_prove : Bool := false

/-- the lean definition is Ok -/
def Data.proved : Bool := false

/--  -/
def Data.fully_proved : Bool := false

section

variable [Monad m] [MonadLog m] [AddMessageContext m] [MonadOptions m]

-- XXX: needs: test
/-- registers an informal definition, will error if already existing -/
def Data.register (data : Data) (label : Label) (deps : Array Label) (isProof : Option Syntax) : m Data := do
  match data.get? label, isProof with
  | none, none =>
    return data.insert label { deps }
  | none, some _ =>
    -- logError m!"No statement for proof with label {label}"
    return data
  | some _node, none =>
    -- logError m!"Duplicated entry for {label}"
    return data
  | some node, some proof =>
    if node.proof == .missing then
      return data.modify label fun node => { node with proof }
    else
      -- logError m!"{label} already has a proof"
      return data

end
