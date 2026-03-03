/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Lean.Data.Json
import VersoBlueprint.DocGenNameRender

namespace Informal.Data

open Lean

deriving instance Lean.ToJson for Lean.DeclarationRange
deriving instance Lean.FromJson for Lean.DeclarationRange

open Syntax in
instance : Lean.Quote Lean.Position where
  quote p := mkCApp ``Lean.Position.mk #[quote p.line, quote p.column]

open Syntax in
instance : Lean.Quote Lean.DeclarationRange where
  quote r := mkCApp ``Lean.DeclarationRange.mk
    #[quote r.pos, quote r.charUtf16, quote r.endPos, quote r.endCharUtf16]

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

def NodeKind.isTheoremLike : NodeKind → Bool
  | .lemma | .theorem | .corollary => true
  | .definition => false

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

/--
Conservative merge for duplicated status snapshots:
- `axiomLike` dominates,
- otherwise keep any observed statement/proof incompleteness.
-/
def ProvedStatus.mergeConservative (a b : ProvedStatus) : ProvedStatus :=
  if a.isAxiomLike || b.isAxiomLike then
    .axiomLike
  else
    ProvedStatus.ofSorryFlags
      (a.hasTypeGap || b.hasTypeGap)
      (a.hasProofGap || b.hasProofGap)

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

def ConstantInfo.blueprintKindText : ConstantInfo → String
  | .defnInfo _ => "definition"
  | .thmInfo _ => "theorem"
  | .axiomInfo _ => "axiom"
  | .opaqueInfo _ => "opaque"
  | .quotInfo _ => "quotient"
  | .inductInfo _ => "inductive"
  | .ctorInfo _ => "constructor"
  | .recInfo _ => "recursor"

structure Code where
  stx : Syntax
  definedDefs : Array LiterateDef := #[]
  definedTheorems : Array LiterateThm := #[]
deriving Repr, Inhabited

inductive ExternalOrigin where
  | directiveLean
  | blueprintAttr
deriving Repr, Inhabited, DecidableEq, ToJson, FromJson

open Syntax in
instance : Quote ExternalOrigin where
  quote
    | .directiveLean => mkCApp ``ExternalOrigin.directiveLean #[]
    | .blueprintAttr => mkCApp ``ExternalOrigin.blueprintAttr #[]

inductive ExternalDeclProvenance where
  | inWorkspace (moduleName : Name) (sourcePath : String)
  | outWorkspace (moduleName : Name) (sourcePath? : Option String := none)
  | unknown
deriving Repr, Inhabited, DecidableEq, ToJson, FromJson

open Syntax in
instance : Quote ExternalDeclProvenance where
  quote
    | .inWorkspace moduleName sourcePath =>
      mkCApp ``ExternalDeclProvenance.inWorkspace #[quote moduleName, quote sourcePath]
    | .outWorkspace moduleName sourcePath? =>
      mkCApp ``ExternalDeclProvenance.outWorkspace #[quote moduleName, quote sourcePath?]
    | .unknown =>
      mkCApp ``ExternalDeclProvenance.unknown #[]

def ExternalDeclProvenance.moduleName? : ExternalDeclProvenance → Option Name
  | .inWorkspace moduleName _ => some moduleName
  | .outWorkspace moduleName _ => some moduleName
  | .unknown => none

def ExternalDeclProvenance.sourcePath? : ExternalDeclProvenance → Option String
  | .inWorkspace _ sourcePath => some sourcePath
  | .outWorkspace _ sourcePath? => sourcePath?
  | .unknown => none

def ExternalDeclProvenance.label : ExternalDeclProvenance → String
  | .inWorkspace _ _ => "in workspace"
  | .outWorkspace _ _ => "out workspace"
  | .unknown => "unknown provenance"

inductive ExternalDeclLookupError where
  | notPresentAtRegistration
  | notFoundInEnvironment
deriving Repr, Inhabited, DecidableEq, ToJson, FromJson

open Syntax in
instance : Quote ExternalDeclLookupError where
  quote
    | .notPresentAtRegistration =>
      mkCApp ``ExternalDeclLookupError.notPresentAtRegistration #[]
    | .notFoundInEnvironment =>
      mkCApp ``ExternalDeclLookupError.notFoundInEnvironment #[]

def ExternalDeclLookupError.message : ExternalDeclLookupError → String
  | .notPresentAtRegistration => "name was not present during directive/code-block registration"
  | .notFoundInEnvironment => "name is not present in current environment"

abbrev ExternalDeclRender := _root_.Informal.DocGenRender

instance : ToJson ExternalDeclRender where
  toJson
    | .ok html => Json.mkObj [("ok", toJson html)]
    | .error error => Json.mkObj [("error", toJson error)]

instance : FromJson ExternalDeclRender where
  fromJson?
    | .obj obj =>
      match obj.get? "ok", obj.get? "error" with
      | some ok, none => return .ok (← fromJson? ok)
      | none, some err => return .error (← fromJson? err)
      | _, _ => throw "expected object with exactly one of fields 'ok' or 'error'"
    | _ => throw "expected object"

instance : Lean.Quote ExternalDeclRender where
  quote
    | .ok html => Syntax.mkApp (mkCIdent ``Except.ok) #[(Lean.quote html)]
    | .error error => Syntax.mkApp (mkCIdent ``Except.error) #[(Lean.quote error)]

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
  present : Bool := true
  /--
  Snapshot of proof/completeness status at registration time.
  -/
  provedStatus : ProvedStatus := .proved
  /--
  Snapshot of theorem-likeness at registration time.
  -/
  isTheoremLike : Bool := false
  /--
  Snapshot of declaration provenance metadata.
  -/
  provenance : ExternalDeclProvenance := .unknown
  /--
  Snapshot of declaration source ranges (if known at registration time).
  -/
  range? : Option Lean.DeclarationRange := none
  selectionRange? : Option Lean.DeclarationRange := none
  /--
  Snapshot of declaration kind and optional source link.
  -/
  kind? : Option String := none
  sourceHref? : Option String := none
  /--
  Snapshot of direct DocGen rendering outcome.
  -/
  render : ExternalDeclRender := .error (.moduleUnavailable canonical)
deriving Repr, Inhabited, ToJson, FromJson

open Syntax in
instance : Quote ExternalRef where
  quote ref := mkCApp ``ExternalRef.mk
    #[ quote ref.written
     , quote ref.canonical
     , quote ref.origin
     , quote ref.present
     , quote ref.provedStatus
     , quote ref.isTheoremLike
     , quote ref.provenance
     , quote ref.range?
     , quote ref.selectionRange?
     , quote ref.kind?
     , quote ref.sourceHref?
     , quote ref.render
     ]

def ExternalRef.ofName (name : Name) (origin : ExternalOrigin := .directiveLean) : ExternalRef :=
  { written := name, canonical := name.eraseMacroScopes, origin }

def ExternalRef.withSnapshot (ref : ExternalRef) (info? : Option ConstantInfo) : ExternalRef :=
  let canonical := ref.canonical.eraseMacroScopes
  match info? with
  | none =>
    {
      ref with
      canonical
      present := false
      provedStatus := .proved
      isTheoremLike := false
      kind? := none
      render := .error (.moduleUnavailable canonical)
    }
  | some info =>
    {
      ref with
      canonical
      present := true
      provedStatus := ConstantInfo.blueprintProvedStatus info (allowOpaque := true)
      isTheoremLike := match info with | .thmInfo _ => true | _ => false
      kind? := some (ConstantInfo.blueprintKindText info)
    }

private def chooseProvenance (current incoming : ExternalDeclProvenance) : ExternalDeclProvenance :=
  match current, incoming with
  | .unknown, p => p
  | p, .unknown => p
  | p, _ => p

private def chooseRender (current incoming : ExternalDeclRender) : ExternalDeclRender :=
  match current, incoming with
  | .ok _, _ => current
  | .error _, .ok _ => incoming
  | .error _, .error _ => current

def ExternalRef.merge (current incoming : ExternalRef) : ExternalRef :=
  let present := current.present && incoming.present
  let provedStatus :=
    if present then
      ProvedStatus.mergeConservative
        current.provedStatus
        incoming.provedStatus
    else
      .proved
  let provenance :=
    if present then chooseProvenance current.provenance incoming.provenance else .unknown
  let range? := if present then current.range? <|> incoming.range? else none
  let selectionRange? := if present then current.selectionRange? <|> incoming.selectionRange? else none
  let kind? := if present then current.kind? <|> incoming.kind? else none
  let sourceHref? := if present then current.sourceHref? <|> incoming.sourceHref? else none
  let render :=
    if present then
      chooseRender current.render incoming.render
    else
      .error (.moduleUnavailable current.canonical)
  {
    current with
    present
    provedStatus
    isTheoremLike := current.isTheoremLike || incoming.isTheoremLike
    provenance
    range?
    selectionRange?
    kind?
    sourceHref?
    render
  }

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
  ExternalRef.merge current incoming

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
