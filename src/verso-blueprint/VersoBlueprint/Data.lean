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
  commandLines : Nat := 1
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

inductive ExternalOrigin where
  | directiveLean
  | blueprintAttr
deriving Repr, Inhabited, DecidableEq

structure ExternalRef where
  written : Name
  canonical : Name
  origin : ExternalOrigin := .directiveLean
deriving Repr, Inhabited

def ExternalRef.ofName (name : Name) (origin : ExternalOrigin := .directiveLean) : ExternalRef :=
  { written := name, canonical := name.eraseMacroScopes, origin }

inductive CodeRef where
  | userOk
  | external (decls : Array ExternalRef)
  | literate (code : Code)
deriving Repr, Inhabited

structure InformalData where
  stx : Syntax
  deps : Array Label := #[]
  elabStx : Array Syntax := #[] -- Syntax is going to have type Verso.Block ...
deriving Repr, Inhabited

structure Node where
  kind : NodeKind := .lemma
  count : Nat := 0
  statement : Option InformalData := none -- Informal Object statement
  proof : Option InformalData := none -- Informal Object proof
  code : Option CodeRef := none -- Informal Object associated code status
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
private def mergeExternalRefs (xs ys : Array ExternalRef) : Array ExternalRef :=
  ys.foldl (init := xs) fun acc y =>
    if acc.any (fun x => x.canonical == y.canonical) then
      acc
    else
      acc.push y

private def mergeCodeRef (label : Label) (current : Option CodeRef) (incoming : CodeRef) : m (Option CodeRef) := do
  match current, incoming with
  | none, incoming => return some incoming
  | some .userOk, .userOk => return current
  | some (.external xs), .external ys => return some (.external (mergeExternalRefs xs ys))
  | some .userOk, .external ys => return some (.external ys)
  | some (.external xs), .userOk => return some (.external xs)
  | some (.literate _), .literate _ =>
    logError m!"Label {label} already has code"
    return current
  | some .userOk, .literate _ =>
    logError m!"Label {label} uses '(leanok := true)' and cannot have an associated Lean code block"
    return current
  | some (.external _), .literate _ =>
    logError m!"Label {label} uses '(lean := ...)' and cannot have an associated Lean code block"
    return current
  | some (.literate _), .userOk =>
    logError m!"Label {label} cannot use '(leanok := true)' because it already has an associated Lean code block"
    return current
  | some (.literate _), .external _ =>
    logError m!"Label {label} cannot use '(lean := ...)' because it already has an associated Lean code block"
    return current

def Data.registerCodeRef (data : Data) (label : Label) (codeRef : CodeRef) : m Data := do
  match data.get? label with
  | none =>
    return data.insert label { code := some codeRef }
  | some node =>
    let code ← mergeCodeRef label node.code codeRef
    return data.insert label { node with code }

def Data.register (data : Data) (label : Label) (kind? : Option NodeKind)
    (statement : Option InformalData) (proof : Option InformalData)
    (codeHint : Option CodeRef := none) : m Data := do
  let applyCodeHint (node : Node) : m Node := do
    match codeHint with
    | none => return node
    | some hint =>
      let code ← mergeCodeRef label node.code hint
      return { node with code }
  let nextCount := data.size + 1
  match data.get? label, statement, proof with
  | none, some statement, none =>
    let count := nextCount
    let node ← applyCodeHint {
      statement := some statement
      count
      kind := kind?.getD .lemma
    }
    return data.insert label node
  | none, none, some _ =>
    -- logError m!"No statement for proof with label {label}"
    return data
  | some node, some statement, none =>
    if node.statement.isNone then
      let count := if node.count == 0 then nextCount else node.count
      let node ← applyCodeHint {
        node with
          kind := kind?.getD node.kind
          count
          statement := some statement
      }
      return data.insert label node
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
      let node ← applyCodeHint {
        node with
          proof := some proof
      }
      return data.insert label node
  | _, _, _ => return data

/-- Register Lean code and code metadata for an informal object label. -/
def Data.registerCode (data : Data) (label : Label) (code : Syntax)
    (definedDefs : Array DefinedDecl := #[]) (definedTheorems : Array DefinedDecl := #[]) : m Data := do
  let literate : CodeRef := .literate { stx := code, definedDefs, definedTheorems }
  match data.get? label with
  | none =>
    return data.insert label { code := some literate }
  | some node =>
    let code ← mergeCodeRef label node.code literate
    return data.insert label { node with code }

end
