/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module

public section

namespace Verso.Search.ExperimentalVIR

/-- One raw semantic-search hit after JavaScript has expanded it to a specific searchable item. -/
public structure SemanticHit where
  sourceIndex : Nat
  rawScore : Float
  semanticPriority : Option Int := none
  domainPriority : Option Int := none
  itemPriority : Option Int := none
deriving Repr

/-- One raw full-text hit returned by the current JavaScript elasticlunr engine. -/
public structure FullTextHit where
  sourceIndex : Nat
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
  sourceIndex : Nat
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

private def priorityFactor (deviation : Int) : Float :=
  if deviation < 0 then
    floatOne / powNat priorityStep deviation.natAbs
  else
    powNat priorityStep deviation.natAbs

private def combineScore (rawScore : Float) (priorities : Array (Option Int)) : Float :=
  let deviation := priorities.foldl (init := 0) fun total priority =>
    total + priorityDeviation priority
  rawScore * priorityFactor deviation

private def insertRanked (candidate : RankedCandidate)
    (sorted : Array RankedCandidate) : Array RankedCandidate := Id.run do
  let mut result := #[]
  let mut inserted := false
  for next in sorted do
    if !inserted && candidate.score > next.score then
      result := result.push candidate
      inserted := true
    result := result.push next
  if !inserted then
    result := result.push candidate
  return result

private def stableSort (candidates : Array RankedCandidate) : Array RankedCandidate := Id.run do
  let mut sorted := #[]
  for candidate in candidates do
    sorted := insertRanked candidate sorted
  return sorted

/--
Normalize, prioritize, merge, and stably sort raw semantic and full-text candidates.

The browser retains the original fuzzysort/elasticlunr objects and uses `sourceIndex` to rehydrate
the ordered candidates, so no DOM or third-party JavaScript object crosses the native boundary.
-/
public def rankCandidates
    (semanticHits : Array SemanticHit) (fullTextHits : Array FullTextHit) :
    Array RankedCandidate := Id.run do
  let mut maxTextScore : Option Float := none
  for hit in fullTextHits do
    maxTextScore := match maxTextScore with
      | none => some hit.rawScore
      | some current => some (if hit.rawScore > current then hit.rawScore else current)
  let textFactor := match maxTextScore with
    | some score =>
        if score > bestPossibleTextScore then bestPossibleTextScore / score else floatOne
    | none => floatOne

  let mut candidates := #[]
  for hit in semanticHits do
    candidates := candidates.push {
      kind := .semantic
      sourceIndex := hit.sourceIndex
      score := combineScore hit.rawScore #[
        hit.semanticPriority,
        hit.domainPriority,
        hit.itemPriority
      ]
    }
  for hit in fullTextHits do
    candidates := candidates.push {
      kind := .fullText
      sourceIndex := hit.sourceIndex
      score := combineScore (hit.rawScore * textFactor) #[
        hit.fullTextPriority,
        hit.documentPriority
      ]
    }
  return stableSort candidates

end Verso.Search.ExperimentalVIR
