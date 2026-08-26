/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Vir
import VersoSearch.ExperimentalVIR

namespace VersoSearchVir.FullLean

open Lean.Vir
open Lean.Vir.Browser
open Verso.Search.ExperimentalVIR

private structure FuzzyMatch where
  score : Float
  indexes : Array Nat

private structure Candidate where
  item : Searchable
  score : Float
  indexes : Array Nat
  sourceIndex : Nat

private structure RenderedSearch where
  html : String
  status : String
  count : Nat

private structure CachedSearch where
  query : String
  rendered : RenderedSearch

private structure PreparedTarget where
  item : Searchable
  chars : Array Char
  starts : Array Nat
  nextStarts : Array Nat
  mask : UInt32

private structure PreparedQuery where
  whole : Array Char
  words : Array (Array Char)
  mask : UInt32

private def isAsciiUpper (c : Char) : Bool :=
  'A' ≤ c && c ≤ 'Z'

private def isAsciiLower (c : Char) : Bool :=
  'a' ≤ c && c ≤ 'z'

private def isAsciiDigit (c : Char) : Bool :=
  '0' ≤ c && c ≤ '9'

private def isAsciiAlphaNum (c : Char) : Bool :=
  isAsciiUpper c || isAsciiLower c || isAsciiDigit c

private def charsMask (chars : Array Char) : UInt32 := Id.run do
  let mut mask := 0
  for c in chars do
    if c.isWhitespace then continue
    let code := c.toNat
    let bit :=
      if 'a'.toNat ≤ code && code ≤ 'z'.toNat then code - 'a'.toNat
      else if '0'.toNat ≤ code && code ≤ '9'.toNat then 26
      else if code ≤ 127 then 30
      else 31
    mask := mask ||| ((1 : UInt32) <<< UInt32.ofNat bit)
  return mask

private def wordStarts (target : Array Char) : Array Nat := Id.run do
  let mut starts := #[]
  let mut previousUpper := false
  let mut previousAlphaNum := false
  for i in [:target.size] do
    let c := target[i]!
    let upper := isAsciiUpper c
    let alphaNum := isAsciiAlphaNum c
    if (upper && !previousUpper) || !previousAlphaNum || !alphaNum then
      starts := starts.push i
    previousUpper := upper
    previousAlphaNum := alphaNum
  return starts

private def nextWordStarts (target : Array Char) (starts : Array Nat) : Array Nat := Id.run do
  let mut result := Array.replicate target.size target.size
  let mut startIndex := 0
  let mut nextStart := starts[0]?.getD target.size
  for i in [:target.size] do
    if i < nextStart then
      result := result.set! i nextStart
    else
      startIndex := startIndex + 1
      nextStart := starts[startIndex]?.getD target.size
      result := result.set! i nextStart
  return result

private def findContiguousFrom
    (query target : Array Char) (start : Nat) : Option Nat := Id.run do
  if query.isEmpty || target.size < query.size then return none
  for i in [start:target.size - query.size + 1] do
    let mut isMatch := true
    for j in [:query.size] do
      if query[j]! != target[i + j]! then
        isMatch := false
        break
    if isMatch then return some i
  return none

private def greedyIndexes (query target : Array Char) : Option (Array Nat) := Id.run do
  if query.isEmpty then return none
  let mut indexes := #[]
  let mut queryIndex := 0
  for targetIndex in [:target.size] do
    if query[queryIndex]! == target[targetIndex]! then
      indexes := indexes.push targetIndex
      queryIndex := queryIndex + 1
      if queryIndex == query.size then return some indexes
  return none

private def strictWordIndexes
    (query target : Array Char) (nextStarts greedy : Array Nat) : Option (Array Nat) := Id.run do
  let mut indexes := #[]
  let mut queryIndex := 0
  let mut backtracks := 0
  let mut targetIndex := if greedy[0]! == 0 then 0 else nextStarts[greedy[0]! - 1]!
  while targetIndex < target.size || 0 < queryIndex do
    if target.size ≤ targetIndex then
      if queryIndex == 0 then break
      backtracks := backtracks + 1
      if 200 < backtracks then break
      queryIndex := queryIndex - 1
      let some previous := indexes.back? | break
      indexes := indexes.pop
      targetIndex := nextStarts[previous]!
    else if query[queryIndex]! == target[targetIndex]! then
      indexes := indexes.push targetIndex
      queryIndex := queryIndex + 1
      if queryIndex == query.size then return some indexes
      targetIndex := targetIndex + 1
    else
      targetIndex := nextStarts[targetIndex]!
  return none

private def rawScore
    (querySize targetSize : Nat) (indexes : Array Nat)
    (strict contiguous wordContiguous : Bool) (wordStartCount : Nat) : Float := Id.run do
  let mut gapPenalty := 0
  let mut gapCount := 0
  for i in [1:indexes.size] do
    if indexes[i]! != indexes[i - 1]! + 1 then
      gapPenalty := gapPenalty + indexes[i]!
      gapCount := gapCount + 1
  let first := indexes[0]!
  let last := indexes[indexes.size - 1]!
  let spread := last - first - (querySize - 1)
  let mut score := -Float.ofNat gapPenalty
  score := score - Float.ofNat ((12 + spread) * gapCount)
  if first != 0 then
    let firstFloat := Float.ofNat first
    score := score - firstFloat * firstFloat * 0.2
  if strict then
    if 24 < wordStartCount then
      score := score * Float.ofNat (10 * (wordStartCount - 24))
  else
    score := score * 1000.0
  let lengthPenalty := Float.ofNat (targetSize - querySize) / 2.0
  score := score - lengthPenalty
  if contiguous then score := score / (1.0 + Float.ofNat (querySize * querySize))
  if wordContiguous then score := score / (1.0 + Float.ofNat (querySize * querySize))
  return score - lengthPenalty

private def singleWord (queryChars : Array Char) (target : PreparedTarget) : Option FuzzyMatch := Id.run do
  let some greedy := greedyIndexes queryChars target.chars | return none
  let strict? := strictWordIndexes queryChars target.chars target.nextStarts greedy
  let strict := strict?.isSome
  let indexes := strict?.getD greedy
  let contiguousStart := findContiguousFrom queryChars target.chars greedy[0]!
  let contiguous := contiguousStart.isSome
  let wordContiguous := match contiguousStart with
    | none => false
    | some start => target.starts.contains start
  let raw := rawScore queryChars.size target.chars.size indexes strict contiguous wordContiguous target.starts.size
  return some { score := raw, indexes }

private def words (query : String) : Array String := Id.run do
  let mut result := #[]
  for wordSlice in query.split Char.isWhitespace do
    let word := wordSlice.toString
    if !word.isEmpty && !result.contains word then result := result.push word
  return result

private def prepareQuery (query : String) : PreparedQuery :=
  let lower := query.toLower
  {
    whole := lower.toList.toArray
    words := (words lower).map fun word => word.toList.toArray
    mask := charsMask lower.toList.toArray
  }

private def prepareTarget (item : Searchable) : PreparedTarget :=
  let original := item.searchKey.toList.toArray
  let starts := wordStarts original
  let chars := item.searchKey.toLower.toList.toArray
  { item, chars, starts, nextStarts := nextWordStarts chars starts, mask := charsMask chars }

private def prepareTargets (items : Array Searchable) : Array PreparedTarget :=
  items.map prepareTarget

private def mergeIndexes (left right : Array Nat) : Array Nat := Id.run do
  let mut result := left
  for index in right do
    if !result.contains index then result := result.push index
  return result.qsort (· < ·)

private def fuzzyMatch (query : PreparedQuery) (target : PreparedTarget) : Option FuzzyMatch := Id.run do
  if query.words.isEmpty then return none
  if query.words.size == 1 then return singleWord query.words[0]! target
  let mut score := 0.0
  let mut indexes := #[]
  let mut previousStart := 0
  for word in query.words do
    let some matched := singleWord word target | return none
    score := score + matched.score / Float.ofNat query.words.size
    let currentStart := matched.indexes[0]!
    if currentStart < previousStart then
      score := score - 2.0 * Float.ofNat (previousStart - currentStart)
    previousStart := currentStart
    indexes := mergeIndexes indexes matched.indexes
  match singleWord query.whole target with
  | some whole => if score < whole.score then return whole
  | none => pure ()
  return some { score, indexes }

private def comesBefore (left right : Candidate) : Bool :=
  left.score > right.score ||
    (left.score == right.score && left.sourceIndex < right.sourceIndex)

private def insertTop (limit : Nat) (candidate : Candidate) (top : Array Candidate) : Array Candidate := Id.run do
  let mut result := #[]
  let mut inserted := false
  for current in top do
    if !inserted && comesBefore candidate current then
      result := result.push candidate
      inserted := true
    if result.size < limit then result := result.push current
  if !inserted && result.size < limit then result := result.push candidate
  return result

private def search (queryText : String) (items : Array PreparedTarget) (limit : Nat := 30) : Array Candidate := Id.run do
  -- `fuzzysort` converts its public threshold back into this raw-score lane before matching.
  -- Staying raw preserves ordering and avoids a per-result `Float.pow` that the pinned VIR runtime
  -- does not yet provide.
  let thresholdRaw := -204096.52904642705
  let query := prepareQuery queryText
  let mut top := #[]
  for sourceIndex in [:items.size] do
    let some item := items[sourceIndex]? | continue
    if query.mask &&& item.mask != query.mask then continue
    if let some matched := fuzzyMatch query item then
      if matched.score ≥ thresholdRaw then
        top := insertTop limit {
          item := item.item
          score := matched.score
          indexes := matched.indexes
          sourceIndex
        } top
  return top

private def domainName (domainId : String) : String :=
  match domainId with
  | "VersoHtml.module" => "Module"
  | "VersoHtml.constant" => "Declaration"
  | "Verso.Genre.Manual.section" => "Section"
  | "Verso.Genre.Manual.doc" => "Documentation"
  | "Verso.Genre.Manual.doc.option" => "Option"
  | "Verso.Genre.Manual.doc.tech" => "Terminology"
  | "Verso.Genre.Manual.doc.tactic" => "Tactic"
  | "Verso.Genre.Manual.doc.tactic.conv" => "Conv tactic"
  | "Verso.Genre.Manual.doc.suggestion" => "Suggestion"
  | "Verso.Genre.Manual.example" => "Example"
  | _ => domainId

private def setTextContentString (element : Js Element) (text : String) : DomM Unit := do
  let jsText ← JsValue.ofString text
  Element.setTextContent element (← Js.Nullable.ofJs jsText)

private def escapeHtmlText (text : String) : String := Id.run do
  let mut escaped := ""
  for c in text.toList do
    match c with
    | '&' => escaped := escaped ++ "&amp;"
    | '<' => escaped := escaped ++ "&lt;"
    | '>' => escaped := escaped ++ "&gt;"
    | _ => escaped := escaped.push c
  return escaped

private def escapeHtmlAttribute (text : String) : String := Id.run do
  let mut escaped := ""
  for c in text.toList do
    match c with
    | '&' => escaped := escaped ++ "&amp;"
    | '<' => escaped := escaped ++ "&lt;"
    | '>' => escaped := escaped ++ "&gt;"
    | '"' => escaped := escaped ++ "&quot;"
    | '\'' => escaped := escaped ++ "&#39;"
    | _ => escaped := escaped.push c
  return escaped

private example : escapeHtmlText "<&>" = "&lt;&amp;&gt;" := by decide

private example :
    escapeHtmlAttribute "\"'<&>" = "&quot;&#39;&lt;&amp;&gt;" := by decide

private def highlightedHtml (text : String) (indexes : Array Nat) : String := Id.run do
  let chars := text.toList.toArray
  if chars.isEmpty then return ""
  let mut highlighted := indexes.contains 0
  let mut run := ""
  let mut html := ""
  for i in [:chars.size] do
    let nextHighlighted := indexes.contains i
    if nextHighlighted != highlighted then
      let tag := if highlighted then "em" else "span"
      html := html ++ s!"<{tag}>{escapeHtmlText run}</{tag}>"
      run := ""
      highlighted := nextHighlighted
    run := run.push chars[i]!
  let tag := if highlighted then "em" else "span"
  return html ++ s!"<{tag}>{escapeHtmlText run}</{tag}>"

private def renderCandidateHtml (candidate : Candidate) : String :=
  let address := escapeHtmlAttribute candidate.item.address
  let searchKey := escapeHtmlAttribute candidate.item.searchKey
  let label := highlightedHtml candidate.item.searchKey candidate.indexes
  let domain := escapeHtmlText (domainName candidate.item.domainId)
  s!"<li class=\"search-result\" role=\"option\">" ++
    s!"<a class=\"search-result-link\" href=\"{address}\" data-search-key=\"{searchKey}\">" ++
    s!"<p>{label}</p><p class=\"domain\">{domain}</p></a></li>"

private def renderCandidatesHtml (candidates : Array Candidate) : String := Id.run do
  let mut html := ""
  for candidate in candidates do
    html := html ++ renderCandidateHtml candidate
  return html

private def makeRendering (items : Array PreparedTarget) (query : String) : RenderedSearch :=
  if query.isEmpty || query.all Char.isWhitespace then
    { html := "", status := s!"Ready: {items.size} quick-jump entries", count := 0 }
  else
    let candidates := search query items
    let count := candidates.size
    {
      html := renderCandidatesHtml candidates
      status := s!"{count} result{if count == 1 then "" else "s"}"
      count
    }

private def findCached (query : String) (cache : Array CachedSearch) : Option RenderedSearch := Id.run do
  for entry in cache do
    if entry.query == query then return some entry.rendered
  return none

private def cacheRendering
    (query : String) (rendered : RenderedSearch) (cache : Array CachedSearch) : Array CachedSearch :=
  -- The xref data is immutable after mounting, so exact-query renderings remain valid. Keep this
  -- deliberately small: it covers ordinary typing/backspacing without turning the browser lane
  -- into an unbounded HTML store.
  let cache := if cache.size < 16 then cache else cache.extract 1 cache.size
  cache.push { query, rendered }

private def applyRendering (list status : Js Element) (rendered : RenderedSearch) : DomM Unit := do
  let html ← JsValue.ofString rendered.html
  Element.setInnerHTML list html
  setTextContentString status rendered.status
  Element.setAttribute list "data-result-count" (toString rendered.count)

private def render
    (items : Array PreparedTarget) (cache : Lean.Vir.RuntimeRef (Array CachedSearch))
    (list status : Js Element) (query : String) : DomM Unit := do
  let rendered ←
    if query.isEmpty || query.all Char.isWhitespace then
      pure (makeRendering items query)
    else
      let previous ← Lean.Vir.RuntimeRef.get cache
      match findCached query previous with
      | some rendered => pure rendered
      | none =>
          let rendered := makeRendering items query
          Lean.Vir.RuntimeRef.set cache (cacheRendering query rendered previous)
          pure rendered
  applyRendering list status rendered

/-- Mounts an entirely Lean-owned semantic quick-jump component into an opt-in DOM root. -/
def mount : DomM Unit := do
  let some root ← Document.querySelectorString "#verso-full-lean-search" | pure ()
  let some data ← Document.querySelectorString "#verso-full-lean-xref" | pure ()
  let xrefJson ← JsValue.toString (← Element.getTextContent data)
  match mapXrefJsonVIR xrefJson with
  | .error message =>
      Element.setAttribute root "data-lean-search-state" "error"
      setTextContentString root s!"Lean search could not decode xref.json: {message}"
  | .ok items =>
      let preparedItems := prepareTargets items
      let renderCache ← Lean.Vir.RuntimeRef.new (#[] : Array CachedSearch)
      let label ← Document.createElementString "label"
      Element.setAttribute label "for" "verso-full-lean-query"
      setTextContentString label "Search this manual"
      Element.appendChild root label
      let inputElement ← Document.createElementString "input"
      Element.setAttribute inputElement "id" "verso-full-lean-query"
      Element.setAttribute inputElement "type" "search"
      Element.setAttribute inputElement "autocomplete" "off"
      Element.setAttribute inputElement "role" "combobox"
      Element.setAttribute inputElement "aria-controls" "verso-full-lean-results"
      Element.setAttribute inputElement "aria-autocomplete" "list"
      Element.appendChild root inputElement
      let status ← Document.createElementString "p"
      Element.setAttribute status "id" "verso-full-lean-status"
      Element.setAttribute status "role" "status"
      Element.appendChild root status
      let list ← Document.createElementString "ul"
      Element.setAttribute list "id" "verso-full-lean-results"
      Element.setAttribute list "role" "listbox"
      Element.ClassList.add list "verso-search-results"
      Element.appendChild root list
      render preparedItems renderCache list status ""
      let _listener ← Element.addEventListener inputElement "input" fun event => do
        match ← Event.inputValue? event with
        | none => pure ()
        | some query => render preparedItems renderCache list status query
      Element.setAttribute root "data-lean-search-state" "ready"

end VersoSearchVir.FullLean
