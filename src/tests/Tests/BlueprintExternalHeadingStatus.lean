/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import VersoBlueprint

namespace Verso.Tests.BlueprintExternalHeadingStatus

open Lean
open Informal
open Informal.Data

private def hasSubstr (s needle : String) : Bool :=
  (s.splitOn needle).length > 1

private def proofGapExternalRef (name : Lean.Name) : Data.ExternalRef :=
  {
    (Data.ExternalRef.ofName name) with
      present := true
      kind := .theorem
      provedStatus := .containsSorry #[{ location := .proof, refs? := some 1 }]
  }

/-- info: true -/
#guard_msgs in
#eval!
  let data : BlockData := {
    kind := .statement .theorem
    codeData := some (.external #[proofGapExternalRef `Ext.thm.proof_only])
    label := `status.theorem.external
    count := 1
  }
  let cdata : CodeSummary.ComputedData := {
    source := data.codeData
  }
  match (CodeSummary.renderParts data cdata (fun _ => none)).statusMark with
  | some mark =>
    mark.status == Data.ProvedStatus.proved &&
    hasSubstr mark.title "No statement blockers in external Lean names"
  | none => false

/-- info: true -/
#guard_msgs in
#eval!
  let ref : Data.ExternalRef := {
    (proofGapExternalRef `Ext.def.proof_only) with
      kind := .definition
  }
  let data : BlockData := {
    kind := .statement .definition
    codeData := some (.external #[ref])
    label := `status.definition.external
    count := 1
  }
  let cdata : CodeSummary.ComputedData := {
    source := data.codeData
  }
  match (CodeSummary.renderParts data cdata (fun _ => none)).statusMark with
  | some mark =>
    mark.status.containsExplicitSorry &&
    hasSubstr mark.title "block statement completion"
  | none => false

end Verso.Tests.BlueprintExternalHeadingStatus
