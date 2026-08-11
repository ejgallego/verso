/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module

public import Lean.Data.Json.FromToJson
public import Lean.Data.Json.Parser

public section

namespace Verso.Search.ExperimentalVIR

open Lean

/--
The browser-facing representation of an item that participates in semantic search.

The `ref` field deliberately remains JSON: domain renderers may attach arbitrary data to it, and
the experimental VIR boundary must preserve that data without imposing a new extension API.
-/
public structure Searchable where
  searchKey : String
  address : String
  domainId : String
  ref : Json
  priority : Option Int := none
deriving BEq, ToJson, FromJson

private structure XRefTarget where
  address : String
  id : String
  data : Json

private def XRefTarget.fromJson (json : Json) : Except String XRefTarget := do
  return {
    address := ← json.getObjValAs? String "address"
    id := ← json.getObjValAs? String "id"
    data := ← json.getObjVal? "data"
  }

private def XRefTarget.destination (target : XRefTarget) : String :=
  s!"{target.address}#{target.id}"

private def contents
    (domainData : Json) (reverseForVIR : Bool := false) :
    Except String (Array (String × Json)) := do
  let contents ← domainData.getObjVal? "contents" >>= Json.getObj?
  return if reverseForVIR then contents.toArray.reverse else contents.toArray

private def targets (value : Json) : Except String (Array Json) :=
  value.getArr?

private def firstTarget (key : String) (value : Json) : Except String XRefTarget := do
  let values ← targets value
  let some first := values[0]?
    | throw s!"Search domain entry {key.quote} has no targets"
  XRefTarget.fromJson first

private def dataString (field : String) (target : XRefTarget) : Except String String :=
  target.data.getObjValAs? String field

private def mapByKey
    (domainId : String) (domainData : Json) (reverseForVIR : Bool) :
    Except String (Array Searchable) := do
  let mut out := #[]
  for (key, value) in ← contents domainData reverseForVIR do
    let target ← firstTarget key value
    out := out.push {
      searchKey := key
      address := target.destination
      domainId
      ref := value
    }
  return out

private def mapByDataString
    (domainId field : String) (domainData : Json) (reverseForVIR : Bool) :
    Except String (Array Searchable) := do
  let mut out := #[]
  for (key, value) in ← contents domainData reverseForVIR do
    let target ← firstTarget key value
    out := out.push {
      searchKey := ← dataString field target
      address := target.destination
      domainId
      ref := value
    }
  return out

private def mapSuggestion
    (domainId : String) (domainData : Json) (reverseForVIR : Bool) :
    Except String (Array Searchable) := do
  let mut out := #[]
  for (key, value) in ← contents domainData reverseForVIR do
    let target ← firstTarget key value
    out := out.push {
      searchKey := ← dataString "searchTerm" target
      address := target.destination
      domainId
      ref := ← target.data.getObjVal? "suggestedRedirect"
    }
  return out

private def mapSection
    (domainId : String) (domainData : Json) (reverseForVIR : Bool) :
    Except String (Array Searchable) := do
  let mut out := #[]
  for (key, value) in ← contents domainData reverseForVIR do
    let target ← firstTarget key value
    let sectionNumber ← target.data.getObjValAs? (Option String) "sectionNum"
    let title ← dataString "title" target
    let priority ← target.data.getObjValAs? (Option Int) "searchPriority"
    out := out.push {
      searchKey := s!"{sectionNumber.getD ""} {title}"
      address := target.destination
      domainId
      ref := value
      priority
    }
  return out

private structure ExampleItem where
  context : Array String
  name : String
  address : String
deriving ToJson

private def exampleItem (targetJson : Json) : Except String ExampleItem := do
  let target ← XRefTarget.fromJson targetJson
  let data ← target.data.getObjVal? target.destination
  return {
    context := ← data.getObjValAs? (Array String) "context"
    name := ← data.getObjValAs? String "display"
    address := target.destination
  }

private def addExample
    (groups : Array (String × Array ExampleItem)) (item : ExampleItem) :
    Array (String × Array ExampleItem) := Id.run do
  let mut groups := groups
  for i in [:groups.size] do
    if groups[i]!.1 == item.name then
      groups := groups.set! i (item.name, groups[i]!.2.push item)
      return groups
  return groups.push (item.name, #[item])

private def commonContextPrefix (items : Array ExampleItem) : Nat := Id.run do
  let some first := items[0]? | return 0
  let mut prefixLen := 0
  for i in [:first.context.size] do
    let part := first.context[i]!
    if items.all fun item => item.context[i]? == some part then
      prefixLen := prefixLen + 1
    else
      break
  return prefixLen

private def mapExamples
    (domainId : String) (domainData : Json) (reverseForVIR : Bool) :
    Except String (Array Searchable) := do
  let mut groups : Array (String × Array ExampleItem) := #[]
  for (_, value) in ← contents domainData reverseForVIR do
    for target in ← targets value do
      groups := addExample groups (← exampleItem target)

  let mut out := #[]
  for (_, items) in groups do
    if items.isEmpty then continue
    let prefixLen := commonContextPrefix items
    let ref := ToJson.toJson items
    for item in items do
      let parts := (item.context.extract prefixLen).push item.name
      out := out.push {
        searchKey := String.intercalate " › " parts.toList
        address := item.address
        domainId
        ref
      }
  return out

/--
Maps one built-in Verso cross-reference domain to semantic-search items.

Unknown domains return an error so the browser adapter can retain the existing JavaScript mapper as
an extension-compatible fallback.
-/
private def mapDomainWith
    (reverseForVIR : Bool) (domainId : String) (domainData : Json) :
    Except String (Array Searchable) :=
  match domainId with
  | "VersoHtml.module" => mapByKey domainId domainData reverseForVIR
  | "Verso.Genre.Manual.doc" => mapByKey domainId domainData reverseForVIR
  | "Verso.Genre.Manual.doc.option" => mapByKey domainId domainData reverseForVIR
  | "VersoHtml.constant" => mapByDataString domainId "userName" domainData reverseForVIR
  | "Verso.Genre.Manual.doc.tech" => mapByDataString domainId "term" domainData reverseForVIR
  | "Verso.Genre.Manual.doc.tactic" => mapByDataString domainId "userName" domainData reverseForVIR
  | "Verso.Genre.Manual.doc.tactic.conv" =>
      mapByDataString domainId "userName" domainData reverseForVIR
  | "Verso.Genre.Manual.doc.suggestion" => mapSuggestion domainId domainData reverseForVIR
  | "Verso.Genre.Manual.section" => mapSection domainId domainData reverseForVIR
  | "Verso.Genre.Manual.example" => mapExamples domainId domainData reverseForVIR
  | _ => throw s!"No experimental VIR mapper is registered for domain {domainId.quote}"

/-- Native typed mapper for one built-in Verso cross-reference domain. -/
public def mapDomain (domainId : String) (domainData : Json) : Except String (Array Searchable) :=
  mapDomainWith false domainId domainData

private def mapDomainJsonWith
    (reverseForVIR : Bool) (domainId domainData : String) : Except String String := do
  let json ← Json.parse domainData
  return (ToJson.toJson (← mapDomainWith reverseForVIR domainId json)).compress

/-- String-only wrapper suitable for testing the stable JavaScript boundary natively. -/
public def mapDomainJson (domainId domainData : String) : Except String String :=
  mapDomainJsonWith false domainId domainData

/--
VIR adapter that restores object-member iteration order in the current interpreter. Native Lean's
JSON traversal already agrees with JavaScript source order; this reversal is deliberately confined
to the experimental runtime export and can be removed when the VIR iteration discrepancy is fixed.
-/
public def mapDomainJsonVIR (domainId domainData : String) : Except String String :=
  mapDomainJsonWith true domainId domainData

/-- One raw semantic-search hit after JavaScript has expanded it to a specific searchable item. -/
public structure SemanticHit where
  sourceIndex : UInt32
  rawScore : Float
  semanticPriority : Option Int := none
  domainPriority : Option Int := none
  itemPriority : Option Int := none
deriving Repr

/-- One raw full-text hit returned by the current JavaScript elasticlunr engine. -/
public structure FullTextHit where
  sourceIndex : UInt32
  rawScore : Float
  fullTextPriority : Option Int := none
  documentPriority : Option Int := none
deriving Repr

/-- Identifies the JavaScript result stream to use when rehydrating a ranked candidate. -/
public inductive CandidateKind where
  | semantic
  | fullText
deriving Repr, BEq

/-- A score and source-array reference returned to the JavaScript rendering layer. -/
public structure RankedCandidate where
  kind : CandidateKind
  sourceIndex : UInt32
  score : Float
deriving Repr

private def priorityDeviation (priority : Option Int) : Int :=
  priority.map (· - 50) |>.getD 0

private def floatOne : Float := Float.ofBits 0x3ff0000000000000
private def bestPossibleTextScore : Float := Float.ofBits 0x3fe999999999999a

private def powNat (base : Float) (exponent : Nat) : Float := Id.run do
  let mut result := floatOne
  let mut factor := base
  let mut exponent := exponent
  while exponent > 0 do
    if exponent % 2 == 1 then
      result := result * factor
    factor := factor * factor
    exponent := exponent / 2
  return result

-- 2^(1/50). Priorities are integer-valued throughout Verso, so multiplying their centered
-- deviations and raising this value to the resulting integer implements 2^sum where
-- `sum = Σ ((priority - 50) / 50)` without requiring the unsupported `Float.exp2` native extern.
private def priorityStep : Float := Float.ofBits 0x3ff0392d9352ad75

private def localPriorityFactor (deviation : Int) : Float :=
  if deviation < 0 then
    floatOne / powNat priorityStep deviation.natAbs
  else
    powNat priorityStep deviation.natAbs

private def combineScoreWith [Monad m]
    (factor : Int → m Float) (rawScore : Float) (priorities : Array (Option Int)) : m Float := do
  let deviation := priorities.foldl (init := 0) fun total priority =>
    total + priorityDeviation priority
  return rawScore * (← factor deviation)

private def insertRankedWith [Monad m]
    (greater : Float → Float → m Bool) (candidate : RankedCandidate) :
    List RankedCandidate → m (List RankedCandidate)
  | [] => pure [candidate]
  | next :: rest => do
      if ← greater candidate.score next.score then
        return candidate :: next :: rest
      else
        return next :: (← insertRankedWith greater candidate rest)

private def stableSortWith [Monad m]
    (greater : Float → Float → m Bool) (candidates : Array RankedCandidate) :
    m (Array RankedCandidate) := do
  let mut sorted := []
  for candidate in candidates do
    sorted ← insertRankedWith greater candidate sorted
  return sorted.toArray

private def normalizedTextFactorWith [Monad m]
    (greater : Float → Float → m Bool) : Option Float → m Float
  | none => pure floatOne
  | some score => do
      if ← greater score bestPossibleTextScore then
        pure (bestPossibleTextScore / score)
      else
        pure floatOne

/--
Effect-polymorphic ranking implementation. The native and current VIR entry points use the local
factor calculation and Float comparison, while alternate runtimes can supply other primitives.

It normalizes, prioritizes, merges, and stably sorts raw semantic and full-text candidates. The
browser retains the original fuzzysort/elasticlunr objects and uses `sourceIndex` to rehydrate the
ordered candidates, so no DOM or third-party JavaScript object crosses the VIR boundary.
-/
public def rankCandidatesWith [Monad m]
    (factor : Int → m Float) (greater : Float → Float → m Bool)
    (semanticHits : Array SemanticHit) (fullTextHits : Array FullTextHit) :
    m (Array RankedCandidate) := do
  let mut maxTextScore : Option Float := none
  for hit in fullTextHits do
    maxTextScore ← match maxTextScore with
      | none => pure (some hit.rawScore)
      | some current => pure (some (if ← greater hit.rawScore current then hit.rawScore else current))
  let textFactor ← normalizedTextFactorWith greater maxTextScore

  let mut candidates := #[]
  for hit in semanticHits do
    let score ← combineScoreWith factor hit.rawScore #[
      hit.semanticPriority,
      hit.domainPriority,
      hit.itemPriority
    ]
    candidates := candidates.push {
      kind := .semantic
      sourceIndex := hit.sourceIndex
      score
    }
  for hit in fullTextHits do
    let score ← combineScoreWith factor (hit.rawScore * textFactor) #[
      hit.fullTextPriority,
      hit.documentPriority
    ]
    candidates := candidates.push {
      kind := .fullText
      sourceIndex := hit.sourceIndex
      score
    }
  stableSortWith greater candidates

/-- Native reference implementation of {name}`rankCandidatesWith`. -/
public def rankCandidates
    (semanticHits : Array SemanticHit) (fullTextHits : Array FullTextHit) :
    Array RankedCandidate :=
  rankCandidatesWith (m := Id) localPriorityFactor (fun lhs rhs => decide (lhs > rhs))
    semanticHits fullTextHits

end Verso.Search.ExperimentalVIR
