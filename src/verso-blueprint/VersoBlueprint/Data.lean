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
deriving Repr, Inhabited, DecidableEq, ToString, ToMessageData, ToJson, FromJson, Quote

@[expose] def LabelMap A := NameMap A

instance [Repr A] : Repr (LabelMap A) := inferInstanceAs <| Repr (NameMap A)

@[expose]
abbrev Parent := Label

inductive NodeKind where
  | definition
  | lemma
  | theorem
  | corollary
deriving Repr, Inhabited, DecidableEq, ToJson, FromJson

instance : ToString NodeKind where
  toString
    | .definition => "Definition"
    | .lemma => "Lemma"
    | .theorem => "Theorem"
    | .corollary => "Corollary"

open Syntax in
instance : Quote NodeKind where
  quote
    | .definition => mkCApp ``NodeKind.definition #[]
    | .lemma => mkCApp ``NodeKind.lemma #[]
    | .theorem => mkCApp ``NodeKind.theorem #[]
    | .corollary => mkCApp ``NodeKind.corollary #[]

/-- Where an incompleteness marker appears in a declaration. -/
inductive SorryWhere where
  | statement
  | proof
deriving Repr, Inhabited, DecidableEq, ToJson, FromJson

open Syntax in
instance : Quote SorryWhere where
  quote
    | .statement => mkCApp ``SorryWhere.statement #[]
    | .proof => mkCApp ``SorryWhere.proof #[]

/--
Structured metadata for one incomplete location in a declaration.
{lit}`refs?` stores the number of references when known.
-/
structure SorryInfo where
  location : SorryWhere
  refs? : Option Nat := none
deriving Repr, Inhabited, DecidableEq, ToJson, FromJson

open Syntax in
instance : Quote SorryInfo where
  quote s := mkCApp ``SorryInfo.mk #[quote s.location, quote s.refs?]

/--
Formalization/proof status for a declaration.
-/
inductive ProvedStatus where
  | proved
  | axiomLike
  | containsSorry (info : Array SorryInfo)
deriving Repr, Inhabited, DecidableEq, ToJson, FromJson

open Syntax in
instance : Quote ProvedStatus where
  quote
    | .proved => mkCApp ``ProvedStatus.proved #[]
    | .axiomLike => mkCApp ``ProvedStatus.axiomLike #[]
    | .containsSorry info => mkCApp ``ProvedStatus.containsSorry #[quote info]

def ProvedStatus.isProved : ProvedStatus → Bool
  | .proved => true
  | _ => false

def ProvedStatus.isAxiomLike : ProvedStatus → Bool
  | .axiomLike => true
  | _ => false

def ProvedStatus.isIncomplete (status : ProvedStatus) : Bool :=
  !status.isProved

def ProvedStatus.hasTypeGap : ProvedStatus → Bool
  | .proved => false
  | .axiomLike => true
  | .containsSorry info => info.any (·.location == .statement)

def ProvedStatus.hasProofGap : ProvedStatus → Bool
  | .proved => false
  | .axiomLike => true
  | .containsSorry info => info.any (·.location == .proof)

def ProvedStatus.ofSorryFlags (hasType hasProof : Bool)
    (typeRefs? : Option Nat := none) (proofRefs? : Option Nat := none) : ProvedStatus :=
  let info : Array SorryInfo :=
    (#[]
      |> fun acc => if hasType then acc.push { location := .statement, refs? := typeRefs? } else acc
      |> fun acc => if hasProof then acc.push { location := .proof, refs? := proofRefs? } else acc)
  if info.isEmpty then .proved else .containsSorry info

def ProvedStatus.ofRefCounts (typeRefs proofRefs : Nat) : ProvedStatus :=
  ProvedStatus.ofSorryFlags
    (typeRefs > 0)
    (proofRefs > 0)
    (if typeRefs > 0 then some typeRefs else none)
    (if proofRefs > 0 then some proofRefs else none)

/-- Information about a code block, including Lean-level analysis -/
structure LiterateDef where
  name : Name
  commandStx : Syntax := .missing
  commandIndex : Nat := 0
  commandLines : Nat := 1
  provedStatus : ProvedStatus := .proved
  typeSorryRefs : Array Syntax := #[]
deriving Repr, Inhabited

structure LiterateThm extends LiterateDef where
  proofSorryRefs : Array Syntax := #[]
deriving Repr, Inhabited

def LiterateDef.hasTypeSorry (d : LiterateDef) : Bool :=
  d.provedStatus.hasTypeGap

def LiterateDef.hasSorry (d : LiterateDef) : Bool :=
  d.provedStatus.isIncomplete

def LiterateThm.hasTypeSorry (d : LiterateThm) : Bool :=
  d.provedStatus.hasTypeGap

def LiterateThm.hasProofSorry (d : LiterateThm) : Bool :=
  d.provedStatus.hasProofGap

def LiterateThm.hasSorry (d : LiterateThm) : Bool :=
  d.provedStatus.isIncomplete

/--
Blueprint incompleteness treats axioms like synthetic sorries because they
lack executable/provable bodies.
-/
def ConstantInfo.blueprintIsAxiomLike (info : ConstantInfo) : Bool :=
  match info with
  | .axiomInfo _ => true
  | _ => false

/--
Combined incompleteness status for blueprint checks.
-/
def ConstantInfo.blueprintProvedStatus (info : ConstantInfo) (allowOpaque : Bool := false) : ProvedStatus :=
  if ConstantInfo.blueprintIsAxiomLike info then
    .axiomLike
  else
    let hasTypeSorry := info.type.hasSorry
    let hasProofSorry := (info.value? (allowOpaque := allowOpaque)).map (·.hasSorry) |>.getD false
    ProvedStatus.ofSorryFlags hasTypeSorry hasProofSorry

/--
Statement-side incompleteness for blueprint status checks.
-/
def ConstantInfo.blueprintHasTypeSorry (info : ConstantInfo) : Bool :=
  (ConstantInfo.blueprintProvedStatus info).hasTypeGap

/--
Proof/body-side incompleteness for blueprint status checks.
-/
def ConstantInfo.blueprintHasProofSorry (info : ConstantInfo) (allowOpaque : Bool := false) : Bool :=
  (ConstantInfo.blueprintProvedStatus info (allowOpaque := allowOpaque)).hasProofGap

structure Code where
  stx : Syntax
  definedDefs : Array LiterateDef := #[]
  definedTheorems : Array LiterateThm := #[]
deriving Repr, Inhabited

inductive ExternalOrigin where
  | directiveLean
  | blueprintAttr
deriving Repr, Inhabited, DecidableEq

/--
Reference to an external declaration mentioned by a blueprint node.
{lit}`written` preserves the user spelling, while {lit}`canonical` is scope-erased for
environment lookup and deduplication.
-/
structure ExternalRef where
  written : Name
  canonical : Name
  origin : ExternalOrigin := .directiveLean
  /--
  Whether this declaration was present in the Lean environment at the time the
  reference was registered from blueprint markup.
  -/
  presentAtRegistration : Bool := true
deriving Repr, Inhabited

def ExternalRef.ofName (name : Name) (origin : ExternalOrigin := .directiveLean) : ExternalRef :=
  { written := name, canonical := name.eraseMacroScopes, origin }

inductive CodeRef where
  /-
  Blueprint code references can currently come from three sources:
  1. An inline Lean block processed by Verso/Lean integration (`.literate`).
  2. A regular Lean declaration tagged with `@[blueprint "..."]` (`.external`, origin `.blueprintAttr`).
  3. A `(lean := "...")` directive reference to Lean code we do not directly control (`.external`, origin `.directiveLean`).

  TODO (external-definitions task): complete and encode the intended behavior from
  the "We'd like to:" portion of the design spec.
  -/
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
  parent : Option Parent := none -- Optional parent group for summaries/graphs
deriving Repr, Inhabited

/-- Map of labels to Node data -/
def Data := LabelMap Node
deriving Repr, Inhabited

/-- We can state a theorem if all its deps are done, and the theorem isn't "not ready" -/
def Data.empty : Data := Std.TreeMap.empty

def Data.parentChildren (data : Data) : LabelMap (Array Label) :=
  data.foldl (init := (Std.TreeMap.empty : LabelMap (Array Label))) fun acc child node =>
    match node.parent with
    | none => acc
    | some parent =>
      let children := acc.getD parent #[]
      acc.insert parent (children.push child)

section

variable [Monad m] [MonadLog m] [AddMessageContext m] [MonadOptions m]

/-- registers an informal definition, will error if already existing -/
private def mergeExternalRef (current incoming : ExternalRef) : ExternalRef :=
  { current with presentAtRegistration := current.presentAtRegistration && incoming.presentAtRegistration }

private def mergeExternalRefs (xs ys : Array ExternalRef) : Array ExternalRef :=
  ys.foldl (init := xs) fun acc y =>
    match acc.findIdx? (fun x => x.canonical == y.canonical) with
    | some idx => acc.set! idx (mergeExternalRef (acc[idx]!) y)
    | none => acc.push y

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

private def mergeParent (label : Label) (current incoming : Option Parent) : m (Option Parent) := do
  match current, incoming with
  | none, none => return none
  | some parent, none => return some parent
  | none, some parent => return some parent
  | some currentParent, some incomingParent =>
    if currentParent = incomingParent then
      logWarning m!"Label {label} repeats '(parent := \"{currentParent}\")'; keeping the same parent"
      return some currentParent
    else
      logError m!"Label {label} declares conflicting parents: existing '{currentParent}', new '{incomingParent}'"
      return some currentParent

def Data.registerCodeRef (data : Data) (label : Label) (codeRef : CodeRef) : m Data := do
  match data.get? label with
  | none =>
    return data.insert label { code := some codeRef }
  | some node =>
    let code ← mergeCodeRef label node.code codeRef
    return data.insert label { node with code }

def Data.register (data : Data) (label : Label) (kind? : Option NodeKind)
    (statement : Option InformalData) (proof : Option InformalData)
    (codeHint : Option CodeRef := none) (parent : Option Parent := none) : m Data := do
  let applyHints (node : Node) : m Node := do
    match codeHint with
    | none =>
      let parent ← mergeParent label node.parent parent
      return { node with parent }
    | some hint =>
      let code ← mergeCodeRef label node.code hint
      let parent ← mergeParent label node.parent parent
      return { node with code, parent }
  let nextCount := data.size + 1
  match data.get? label, statement, proof with
  -- First statement for a fresh label.
  | none, some statement, none =>
    let count := nextCount
    let node ← applyHints {
      statement := some statement
      count
      kind := kind?.getD .lemma
    }
    return data.insert label node
  -- Proof without a corresponding statement is weird, ignore?
  | none, none, some _ =>
    logError m!"No statement for proof with label {label}"
    return data
  -- Late statement fill for an existing placeholder node.
  | some node, some statement, none =>
    if node.statement.isNone then
      let count := if node.count == 0 then nextCount else node.count
      let node ← applyHints {
        node with
          kind := kind?.getD node.kind
          count
          statement := some statement
      }
      return data.insert label node
    else
      -- logError m!"Duplicated entry for {label}"
      return data
  -- Register proof for an existing statement.
  | some node, none, some proof =>
    if node.proof.isSome then
      -- logError m!"{label} already has a proof"
      return data
    else if node.statement.isNone then
      logError m!"Cannot register proof for {label}: statement dependencies are missing"
      return data
    else
      let node ← applyHints {
        node with
          proof := some proof
      }
      return data.insert label node
  | none, none, none =>
    logError m!"Invalid registration state for {label}: missing both statement and proof for a new label"
    return data
  | none, some _, some _ =>
    logError m!"Invalid registration state for {label}: cannot register statement and proof simultaneously for a new label"
    return data
  | some _, none, none =>
    logError m!"Invalid registration state for {label}: update must provide either statement or proof"
    return data
  | some _, some _, some _ =>
    logError m!"Invalid registration state for {label}: cannot register statement and proof simultaneously"
    return data

/-- Register Lean code and code metadata for an informal object label. -/
def Data.registerCode (data : Data) (label : Label) (code : Syntax)
    (definedDefs : Array LiterateDef := #[]) (definedTheorems : Array LiterateThm := #[]) : m Data := do
  let literate : CodeRef := .literate { stx := code, definedDefs, definedTheorems }
  match data.get? label with
  | none =>
    return data.insert label { code := some literate }
  | some node =>
    let code ← mergeCodeRef label node.code literate
    return data.insert label { node with code }

end
