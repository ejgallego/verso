/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.Blueprint.Support

namespace Verso.Tests.BlueprintExternalHeadingStatus

open Lean
open Informal
open Informal.Data
open Verso.Tests.Blueprint.Support

private def inlineProofGapStatus : Data.ProvedStatus :=
  .containsSorry #[{ location := .proof, refs? := some 1 }]

private def missingExternalRef (name : Lean.Name) : Data.ExternalRef :=
  {
    (Data.ExternalRef.ofName name) with
      present := false
      kind := .definition
  }

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
    match mark.status with
    | .containsSorry info =>
      !info.isEmpty &&
      info.any (·.location == Data.SorryWhere.proof) &&
      !info.any (·.location == Data.SorryWhere.statement) &&
      hasSubstr mark.title "Statement: completed" &&
      hasSubstr mark.title "Proof: with sorries"
    | _ => false
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
    match mark.status with
    | .containsSorry info =>
      !info.isEmpty &&
      info.any (·.location == Data.SorryWhere.proof) &&
      !info.any (·.location == Data.SorryWhere.statement) &&
      hasSubstr mark.title "Statement: completed" &&
      hasSubstr mark.title "Proof: with sorries"
    | _ => false
  | none => false

/-- info: true -/
#guard_msgs in
#eval!
  let codeData : InlineCodeData := {
    label := `status.inline.panel
    definedDefs := #[{ name := `inlineDef, provedStatus := .proved }]
    definedTheorems := #[{ name := `inlineThm, provedStatus := inlineProofGapStatus }]
  }
  let headingData : BlockData := {
    kind := .statement .definition
    codeData := some (.inline codeData)
    label := `status.inline.panel
    count := 1
  }
  let headingHtml := (CodeSummary.renderParts headingData { source := some (.inline codeData) } (fun _ => none)).codeEntry.asString
  let parts := CodeSummary.renderPanelIndicator
    `status.inline.panel
    { source := some (.inline codeData) }
    (fun _ => none)
  let html := parts.indicator.asString
  hasSubstr parts.summaryTitle "status.inline.panel" &&
  hasSubstr parts.summaryTitle "inlineThm [in proof]" &&
  hasSubstr headingHtml "L∃∀N" &&
  hasSubstr headingHtml "class=\"bp_code_decl_item\"" &&
  hasSubstr headingHtml "Associated Lean declarations" &&
  hasSubstr html "bp_code_progress" &&
  hasSubstr html "class=\"bp_code_decl_item\"" &&
  hasSubstr html "inlineDef" &&
  hasSubstr html "inlineThm" &&
  hasSubstr html ">[complete]</span>" &&
  hasSubstr html ">[in proof]</span>"

/-- info: true -/
#guard_msgs in
#eval!
  let decls := #[
    proofGapExternalRef `Ext.external.proof_gap,
    missingExternalRef `Ext.external.missing
  ]
  let parts := CodeSummary.renderPanelIndicator
    `status.external.panel
    { source := some (.external decls) }
    (fun _ => none)
  let headingData : BlockData := {
    kind := .statement .theorem
    codeData := some (.external decls)
    label := `status.external.panel
    count := 1
  }
  let headingHtml := (CodeSummary.renderParts headingData { source := some (.external decls) } (fun _ => none)).codeEntry.asString
  let html := parts.indicator.asString
  hasSubstr parts.summaryTitle "Lean declarations (1/2 present)" &&
  hasSubstr headingHtml "L∃∀N" &&
  hasSubstr headingHtml "class=\"bp_code_decl_item\"" &&
  hasSubstr html "bp_external_status_badge" &&
  hasSubstr html "class=\"bp_code_decl_item\"" &&
  hasSubstr html "Ext.external.proof_gap" &&
  hasSubstr html "Ext.external.missing" &&
  hasSubstr html ">[in proof]</span>" &&
  hasSubstr html ">[missing declaration]</span>"

end Verso.Tests.BlueprintExternalHeadingStatus
