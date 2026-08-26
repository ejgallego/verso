/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/
module
public import VersoSearch
public import VersoSearch.DomainSearch
public import VersoSearch.ExperimentalVIR

/-!
Tests for the JavaScript wire format produced by `Verso.Search.DomainMapper.toJs` and
`Verso.Search.DomainMappers.toJs`. These are structural checks against the emitted JS source: they
assert that priority fields and global priority exports appear with the configured values, so the
browser-side combining code in `search-box.js` has the data it expects.
-/

namespace Verso.Tests.SearchJs

open Std
open Verso.Search

namespace ExperimentalVIRTests

open Verso.Search.ExperimentalVIR

private def testSectionMapper : IO Unit := do
  let input :=
    r#"{"contents":{"intro":[{"address":"/guide/","id":"intro","data":{
      "sectionNum":"1.","title":"Introduction","searchPriority":75}}],
      "next":[{"address":"/guide/","id":"next","data":{
      "sectionNum":"2.","title":"Next","searchPriority":50}}]}}"#
  -- Exercise the string boundary used by VIR; `Json.parse` and `json%` construct object maps in
  -- opposite traversal orders, and this boundary must agree with JavaScript source order.
  let output ← IO.ofExcept <| mapDomainJson "Verso.Genre.Manual.section" input
  let outputJson ← IO.ofExcept <| Lean.Json.parse output
  let mapped : Array Searchable ← IO.ofExcept <| Lean.fromJson? outputJson
  let some item := mapped[0]? | throw <| IO.userError "section mapper returned no result"
  unless mapped.size == 2 do throw <| IO.userError s!"section mapper returned {mapped.size} results"
  unless item.searchKey == "1. Introduction" do
    throw <| IO.userError s!"unexpected section search key: {item.searchKey.quote}"
  unless item.address == "/guide/#intro" do
    throw <| IO.userError s!"unexpected section address: {item.address.quote}"
  unless item.priority == some 75 do
    throw <| IO.userError s!"unexpected section priority: {item.priority}"
  unless mapped.map (·.searchKey) == #["1. Introduction", "2. Next"] do
    throw <| IO.userError s!"section mapper did not preserve source order: {mapped.map (·.searchKey)}"

private def testExampleMapper : IO Unit := do
  let input := json%{
    "contents": {
      "foo": [
        {
          "address": "/a/",
          "id": "foo-a",
          "data": {
            "/a/#foo-a": {"context": ["Manual", "Part A"], "display": "foo"}
          }
        },
        {
          "address": "/b/",
          "id": "foo-b",
          "data": {
            "/b/#foo-b": {"context": ["Manual", "Part B"], "display": "foo"}
          }
        }
      ]
    }
  }
  let mapped ← IO.ofExcept <| mapDomain "Verso.Genre.Manual.example" input
  unless mapped.map (·.searchKey) == #["Part A › foo", "Part B › foo"] do
    throw <| IO.userError s!"unexpected example search keys: {mapped.map (·.searchKey)}"
  unless mapped.map (·.address) == #["/a/#foo-a", "/b/#foo-b"] do
    throw <| IO.userError s!"unexpected example addresses: {mapped.map (·.address)}"
  let some first := mapped[0]? | throw <| IO.userError "example mapper returned no first result"
  let some second := mapped[1]? | throw <| IO.userError "example mapper returned no second result"
  unless first.ref == second.ref do
    throw <| IO.userError "duplicate example names should share their comparison ref"

private def close (actual expected : Float) : Bool :=
  (actual - expected).abs < 0.000000000001

private def testRanking : IO Unit := do
  let semantic : Array SemanticHit := #[
    { sourceIndex := 0, rawScore := 0.5, semanticPriority := some 75,
      domainPriority := some 75 },
    { sourceIndex := 1, rawScore := 0.9 }
  ]
  let fullText : Array FullTextHit := #[
    { sourceIndex := 0, rawScore := 2.0 }
  ]
  let ranked := rankCandidates semantic fullText
  unless ranked.map (·.kind) == #[.semantic, .semantic, .fullText] do
    throw <| IO.userError s!"unexpected ranked streams: {repr (ranked.map (·.kind))}"
  unless ranked.map (·.sourceIndex) == #[0, 1, 0] do
    throw <| IO.userError s!"unexpected ranked source indices: {ranked.map (·.sourceIndex)}"
  let some first := ranked[0]? | throw <| IO.userError "ranking returned no first result"
  let some second := ranked[1]? | throw <| IO.userError "ranking returned no second result"
  let some third := ranked[2]? | throw <| IO.userError "ranking returned no third result"
  unless close first.score 1.0 && close second.score 0.9 && close third.score 0.8 do
    throw <| IO.userError s!"unexpected ranked scores: {ranked.map (·.score)}"

private def testStableRanking : IO Unit := do
  let ranked := rankCandidates
    #[{ sourceIndex := 10, rawScore := 0.5 }, { sourceIndex := 11, rawScore := 0.5 }]
    #[{ sourceIndex := 20, rawScore := 0.5 }]
  unless ranked.map (·.sourceIndex) == #[10, 11, 20] do
    throw <| IO.userError s!"equal scores were not stable: {ranked.map (·.sourceIndex)}"

def tests : List (Lean.Name × IO Unit) := [
  (`testSectionMapper, testSectionMapper),
  (`testExampleMapper, testExampleMapper),
  (`testRanking, testRanking),
  (`testStableRanking, testStableRanking)
]

end ExperimentalVIRTests

private def hasSub (haystack : String) (needle : String) : Bool :=
  haystack.find? needle |>.isSome

private def assertContains (label : String) (haystack : String) (needle : String) : IO Unit := do
  unless hasSub haystack needle do
    throw <| IO.userError s!"expected {label} output to contain {repr needle}, got:\n{haystack}"

/-- Verifies that `DomainMapper.toJs` emits the display/class/data fields without a priority. -/
def testMapperToJs : IO Unit := do
  let mapper : DomainMapper :=
    { displayName := "Term"
      className := "term"
      dataToSearchables := "x => []" }
  let rendered := (DomainMapper.toJs mapper).pretty (width := 70)
  assertContains "DomainMapper" rendered "displayName:"
  assertContains "DomainMapper" rendered "\"Term\""
  assertContains "DomainMapper" rendered "className:"
  assertContains "DomainMapper" rendered "\"term\""
  assertContains "DomainMapper" rendered "dataToSearchables:"
  if hasSub rendered "searchPriority" then
    throw <| IO.userError
      s!"DomainMapper output should not contain `searchPriority` (it lives in SearchPriorities now):\n{rendered}"

/--
Verifies that `DomainMappers.toJs` emits both the `domainMappers` constant and the
`searchPriorities` constant with the correct semantic / fullText values plus the per-domain
priorities map.
-/
def testMappersToJs : IO Unit := do
  let mapper : DomainMapper :=
    { displayName := "Term"
      className := "term"
      dataToSearchables := "x => []" }
  let mappers : DomainMappers := HashMap.ofList [("Verso.Test", mapper)]
  let priorities : SearchPriorities :=
    { semantic := 60, fullText := 40, domains := ({} : Verso.NameMap _).insert `Verso.Test 73 }
  let rendered := (mappers.toJs priorities).pretty (width := 70)
  assertContains "DomainMappers" rendered "export const domainMappers"
  assertContains "DomainMappers" rendered "export const searchPriorities"
  assertContains "DomainMappers" rendered "semantic:"
  assertContains "DomainMappers" rendered "60"
  assertContains "DomainMappers" rendered "fullText:"
  assertContains "DomainMappers" rendered "40"
  assertContains "DomainMappers" rendered "domains:"
  assertContains "DomainMappers" rendered "\"Verso.Test\""
  assertContains "DomainMappers" rendered "73"

/--
Verifies that `Verso.Search.priorityMapJson` produces a keyed map of only the documents whose priority
differs from neutral, using the same centered-at-50 integer convention as `Searchable.priority`.
-/
def testPriorityMap : IO Unit := do
  let docs : Array IndexDoc := #[
    { id := "boosted", header := "", context := #[], content := "", priority := some 80 },
    { id := "no-priority", header := "", context := #[], content := "", priority := none },
    -- A `some 50` is semantically equivalent to `none` and must not bloat the emitted map:
    { id := "explicit-neutral", header := "", context := #[], content := "", priority := some 50 },
    { id := "suppressed", header := "", context := #[], content := "", priority := some 10 },
    -- Ancestor-summed priorities can fall outside [0, 99]:
    { id := "deep-subsection", header := "", context := #[], content := "", priority := some (-20) }
  ]
  let rendered := (priorityMapJson docs).compress
  assertContains "priorityMapJson" rendered "\"boosted\":80"
  assertContains "priorityMapJson" rendered "\"suppressed\":10"
  assertContains "priorityMapJson" rendered "\"deep-subsection\":-20"
  -- Neutral docs (none or some 50) must be omitted entirely, not serialized as null or 50.
  for omitted in ["no-priority", "explicit-neutral"] do
    if hasSub rendered omitted then
      throw <| IO.userError
        s!"priorityMapJson should omit neutral docs ({omitted}), but emitted:\n{rendered}"

/-- Defaults for `SearchPriorities` are `semantic := 50` and `fullText := 50`. -/
def testMappersToJsDefaults : IO Unit := do
  let mappers : DomainMappers := {}
  let rendered := (mappers.toJs).pretty (width := 70)
  assertContains "DomainMappers defaults" rendered "export const searchPriorities"
  assertContains "DomainMappers defaults" rendered "semantic:"
  assertContains "DomainMappers defaults" rendered "fullText:"
  assertContains "DomainMappers defaults" rendered "50"

/-- The opt-in VIR configuration is emitted alongside the existing search-page path. -/
def testSearchConfigJs : IO Unit := do
  let config : VirSearchConfig := {
    runtimeModule := "-verso-search/vir/js/vir-runtime.js"
    wasmUrl := "-verso-search/vir/wasm/vir-upstream.wasm"
    packageSetUrl := "-verso-search/vir/VersoSearchVir/Runtime.irpkg-set.json"
  }
  let rendered := searchConfigJs (some "search/") (some config)
  assertContains "searchConfigJs" rendered "window.searchPagePath = \"search/\";"
  assertContains "searchConfigJs" rendered "window.versoSearchVir ="
  assertContains "searchConfigJs" rendered "VersoSearchVir.Runtime.mapDomainJson"
  assertContains "searchConfigJs" rendered "VersoSearchVir.Runtime.rankCandidates"

public def runSearchJsTests : IO Nat := do
  let tests : List (Lean.Name × IO Unit) :=
    [ (`testMapperToJs, testMapperToJs)
    , (`testMappersToJs, testMappersToJs)
    , (`testMappersToJsDefaults, testMappersToJsDefaults)
    , (`testPriorityMap, testPriorityMap)
    , (`testSearchConfigJs, testSearchConfigJs)
    ] ++ ExperimentalVIRTests.tests
  let mut failures := 0
  for (name, test) in tests do
    try
      test
      IO.println s!"{name}: passed"
    catch e =>
      IO.println s!"{name}: FAILED - {e}"
      failures := failures + 1
  return failures
