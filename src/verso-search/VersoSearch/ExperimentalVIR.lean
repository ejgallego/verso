/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module

public import Lean.Data.Json.FromToJson
public import Lean.Data.Json.Parser
public import VersoSearch.ExperimentalRanking

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

end Verso.Search.ExperimentalVIR
