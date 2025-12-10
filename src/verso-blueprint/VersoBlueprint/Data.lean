/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean.Data.Json

namespace Informal.Data

open Lean

set_option doc.verso true
-- set_option pp.rawOnError true

-- informal object labels are names for now, but that could change
def Label := Name
deriving Repr, Inhabited

def LabelMap A := NameMap A
deriving Inhabited

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

-- labels operations
def Data.pushDep (data : Data) (label : Label) (dep : Label) : Data :=
  data.alter label fun data =>
    let data := data.getD default
    some { data with deps := data.deps.push dep }

