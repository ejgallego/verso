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

inductive NodeKind where
  | definition
  | lemma
  | theorem
  | corollary
  | proof
deriving Repr, Inhabited, DecidableEq, ToJson, FromJson

instance : ToString NodeKind where
  toString
    | .definition => "Definition"
    | .lemma => "Lemma"
    | .theorem => "Theorem"
    | .proof => "Proof"
    | .corollary => "Corollary"

open Syntax in
instance : Quote NodeKind where
  quote
    | .definition => mkCApp ``NodeKind.definition #[]
    | .lemma => mkCApp ``NodeKind.lemma #[]
    | .theorem => mkCApp ``NodeKind.theorem #[]
    | .proof => mkCApp ``NodeKind.proof #[]
    | .corollary => mkCApp ``NodeKind.corollary #[]

/-- Information about a code block, including Lean-level analysis -/
structure DefinedDecl where
  name : Name
  commandStx : Syntax := .missing
  commandIndex : Nat := 0
  hasSorry : Bool := false
  hasTypeSorry : Bool := false
  hasProofSorry : Bool := false
  typeSorryRefs : Array Syntax := #[]
  proofSorryRefs : Array Syntax := #[]
deriving Repr, Inhabited

structure Code where
  stx : Syntax
  definedDefs : Array DefinedDecl := #[]
  definedTheorems : Array DefinedDecl := #[]
deriving Repr, Inhabited

structure InformalData where
  stx : Syntax
  deps : Array Label := #[]
  elabStx : Array Syntax := #[]
deriving Repr, Inhabited

structure Node where
  kind : NodeKind := .lemma
  count : Nat := 0
  statement : Option InformalData := none -- Informal Object statement
  proof : Option InformalData := none -- Informal Object proof
  code : Option Code := none -- Informal Object associated code
deriving Repr, Inhabited

/-- Map of labels to Node data -/
def Data := LabelMap Node
deriving Repr, Inhabited

/-- We can state a theorem if all its deps are done, and the theorem isn't "not ready" -/
def Data.empty : Data := Std.TreeMap.empty

section

variable [Monad m] [MonadLog m] [AddMessageContext m] [MonadOptions m]

-- XXX: needs: test
/-- registers an informal definition, will error if already existing -/
def Data.register (data : Data) (label : Label) (kind? : Option NodeKind)
    (statement : Option InformalData) (proof : Option InformalData) : m Data := do
  let nextCount := data.size + 1
  match data.get? label, statement, proof with
  | none, some statement, none =>
    let count := nextCount
    return data.insert label {
      statement := some statement
      count
      kind := kind?.getD .lemma
    }
  | none, none, some _ =>
    -- logError m!"No statement for proof with label {label}"
    return data
  | some node, some statement, none =>
    if node.statement.isNone then
      let count := if node.count == 0 then nextCount else node.count
      return data.modify label fun node => {
        node with
          kind := kind?.getD node.kind
          count
          statement := some statement
      }
    else
      -- logError m!"Duplicated entry for {label}"
      return data
  | some node, none, some proof =>
    if node.proof.isSome then
      -- logError m!"{label} already has a proof"
      return data
    else if node.statement.isNone then
      logError m!"Cannot register proof for {label}: statement dependencies are missing"
      return data
    else
      return data.modify label fun node => { node with proof := some proof }
  | _, _, _ => return data

/-- Register Lean code and code metadata for an informal object label. -/
def Data.registerCode (data : Data) (label : Label) (code : Syntax)
    (definedDefs : Array DefinedDecl := #[]) (definedTheorems : Array DefinedDecl := #[]) : m Data := do
  match data.get? label with
  | none =>
    return data.insert label { code := some { stx := code, definedDefs, definedTheorems } }
  | some node =>
    if node.code.isNone then
      return data.modify label fun node => { node with code := some { stx := code, definedDefs, definedTheorems } }
    else
      -- Could also append multiple code blocks here instead of erroring.
      logError m!"Label {label} already has code"
      return data

end
