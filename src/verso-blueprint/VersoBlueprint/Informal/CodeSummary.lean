/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Informal.CodeCommon

namespace Informal
namespace CodeSummary

open Verso Doc Elab
open Lean Elab

/--
Canonical inputs used to compute Lean summary UI for one informal block.

`source` is the resolved optional code source for this block (`none` / `some userOk` /
`some inline` / `some external`).
Inline declaration summaries come from `.inline`; `codeHref` is used for heading link rendering.
-/
structure ComputedData where
  codeHref : Option String := none
  source : Option BlockCodeData := none

/--
Rendered fragments produced by `CodeSummary.renderParts` for an informal block heading.
-/
structure RenderParts where
  statusMark : Option BlockStatusMark := none
  codeEntry : Output.Html := .empty

private def summaryDeclItems (items : Array (String × Option String)) : Output.Html :=
  open Verso.Output.Html in
  if items.isEmpty then
    {{<li class="bp_code_hover_none">"none"</li>}}
  else
    .seq <| items.map fun item =>
      let txtVal := item.1
      let href := item.2
      let txt := {{<code>{{.text true txtVal}}</code>}}
      {{<li>{{if let some href := href then {{<a href={{href}}>{{txt}}</a>}} else txt}}</li>}}

private def declSummaryItems (decls : Array CodeDeclData) (hrefOf : Name → Option String)
    : Array (String × Option String) :=
  decls.map fun decl => (toString decl.name, hrefOf decl.name)

private def sorrySummaryItems (decls : Array CodeDeclData) (hrefOf : Name → Option String)
    : Array (String × Option String) :=
  decls.filter (provedStatusHasSorry ∘ (·.provedStatus)) |>.map fun decl =>
    (s!"{decl.name} [{provedStatusSummaryText decl.provedStatus}]", hrefOf decl.name)

/--
Tooltip body for the Lean summary badge. It lists definitions, theorems/lemmas, and incomplete declarations.
-/
def renderCodeSummaryTooltip (label : Data.Label)
    (definedDefs definedTheorems : Array CodeDeclData) (hrefOf : Name → Option String) : Output.Html :=
  open Verso.Output.Html in
  let allDecls := definedDefs ++ definedTheorems
  {{
    <div class="bp_code_hover" role="tooltip">
      <div class="bp_code_hover_title">{{.text true s!"{label}"}}</div>
      <div class="bp_code_hover_section">
        <span class="bp_code_hover_label">"Lean definitions"</span>
        <ul class="bp_code_hover_list">
          {{summaryDeclItems (declSummaryItems definedDefs hrefOf)}}
        </ul>
      </div>
      <div class="bp_code_hover_section">
        <span class="bp_code_hover_label">"Lean theorems/lemmas"</span>
        <ul class="bp_code_hover_list">
          {{summaryDeclItems (declSummaryItems definedTheorems hrefOf)}}
        </ul>
      </div>
      <div class="bp_code_hover_section">
        <span class="bp_code_hover_label">"Sorries"</span>
        <ul class="bp_code_hover_list">
          {{summaryDeclItems (sorrySummaryItems allDecls hrefOf)}}
        </ul>
      </div>
    </div>
  }}

private def userOkSummaryTooltip : Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_code_hover" role="tooltip">
      <div class="bp_code_hover_title">"Lean status"</div>
      <div class="bp_code_hover_section">
        <span class="bp_code_hover_none">"Marked complete via (leanok := true)."</span>
      </div>
    </div>
  }}

/--
Aggregate counts used to compute the external-heading status mark and tooltip text.

The counters track statement-side and proof-side incompleteness independently.
-/
private structure ExternalHeadingAggregate where
  /-- Total number of external declaration references attached to the block. -/
  total : Nat
  /-- Number of references resolved/present in the snapshot. -/
  found : Nat
  /-- Number of references missing from the snapshot/environment. -/
  missing : Nat
  /-- Present declarations with statement-side (`type`) sorries. -/
  withStatementSorries : Nat
  /-- Present declarations with proof/body-side sorries. -/
  withProofSorries : Nat
  /-- Present declarations with any sorry-side incompleteness. -/
  withSorries : Nat

/-- Per-status increments: `(statementAxis, proofAxis, anyAxis)`. -/
private def statusGapIncrements (status : Data.ProvedStatus) : Nat × Nat × Nat :=
  match status.hasTypeGap, status.hasProofGap with
  | false, false => (0, 0, 0)
  | true, false => (1, 0, 1)
  | false, true => (0, 1, 1)
  | true, true => (1, 1, 1)

private def externalHeadingAggregate (decls : Array Data.ExternalRef) : ExternalHeadingAggregate :=
  decls.foldl
      (init := {
        total := decls.size
        found := 0
        missing := 0
        withStatementSorries := 0
        withProofSorries := 0
        withSorries := 0
      })
      fun acc decl =>
    if decl.present then
      let (statementInc, proofInc, anyInc) := statusGapIncrements decl.provedStatus
      {
        acc with
          found := acc.found + 1
          withStatementSorries := acc.withStatementSorries + statementInc
          withProofSorries := acc.withProofSorries + proofInc
          withSorries := acc.withSorries + anyInc
      }
    else
      { acc with missing := acc.missing + 1 }

private def externalDeclStatusText (decl : Data.ExternalRef) : String :=
  if !decl.present then
    "missing declaration"
  else if provedStatusContainsSorry decl.provedStatus then
    s!"contains sorry {provedStatusLocationText decl.provedStatus}"
  else if externalDeclHasGap decl then
    provedStatusLocationText decl.provedStatus
  else
    "complete"

private def externalDeclHref (decl : Data.ExternalRef) (hrefOf : Name → Option String) : Option String :=
  if decl.present then
    match hrefOf decl.canonical with
    | some href => some href
    | none => hrefOf decl.written
  else
    hrefOf decl.written

private def externalSummaryItems (decls : Array Data.ExternalRef) (hrefOf : Name → Option String)
    : Array (String × Option String) :=
  decls.map fun decl =>
    (s!"{decl.written} [{externalDeclStatusText decl}]", externalDeclHref decl hrefOf)

private def renderExternalSummaryTooltip (decls : Array Data.ExternalRef)
    (hrefOf : Name → Option String) : Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_code_hover" role="tooltip">
      <div class="bp_code_hover_title">"External Lean references"</div>
      <div class="bp_code_hover_section">
        <ul class="bp_code_hover_list">
          {{summaryDeclItems (externalSummaryItems decls hrefOf)}}
        </ul>
      </div>
    </div>
  }}

private def axisCompletionText : Nat → String
  | 0 => "completed"
  | _ + 1 => "with sorries"

private def completionAxisText (statementSorryCount proofSorryCount : Nat) : String :=
  s!"Statement: {axisCompletionText statementSorryCount}; Proof: {axisCompletionText proofSorryCount}"

private def completionStatusMark (statementSorryCount proofSorryCount : Nat) : BlockStatusMark :=
  match Data.ProvedStatus.ofRefCounts statementSorryCount proofSorryCount with
  | .proved =>
    {
      status := .proved
      title := completionAxisText statementSorryCount proofSorryCount
    }
  | _ =>
    {
      status := .containsSorry #[]
      title := completionAxisText statementSorryCount proofSorryCount
      symbolOverride? := some "⚠"
    }

private def externalStatusMark (agg : ExternalHeadingAggregate) : BlockStatusMark :=
  if agg.missing > 0 then
    {
      status := .missing
      title := s!"External Lean names: {agg.found} present, {agg.missing} missing (statement/proof completion unknown)"
    }
  else
    completionStatusMark agg.withStatementSorries agg.withProofSorries

private def inlineCompletionCounts (codeData : InlineCodeData) : Nat × Nat :=
  let decls := codeData.definedDefs ++ codeData.definedTheorems
  decls.foldl
      (init := (0, 0))
      fun (statementSorryCount, proofSorryCount) decl =>
    let (statementInc, proofInc, _) := statusGapIncrements decl.provedStatus
    (statementSorryCount + statementInc, proofSorryCount + proofInc)

private def inlineStatusMark (codeData : InlineCodeData) : BlockStatusMark :=
  let (statementSorryCount, proofSorryCount) := inlineCompletionCounts codeData
  completionStatusMark statementSorryCount proofSorryCount

/--
Compute heading status semantics from canonical block code source using explicit
statement/proof axis wording.

Case semantics:
- `.userOk`: always returns a proved mark with explicit manual override text.
- `.inline`: evaluates statement (`type`) and proof (`body`) sorries independently.
- `.external`: uses `externalHeadingAggregate` + `externalStatusMark`
  (missing references dominate).
- `none`: defaults to a completed statement/proof mark.

This function computes mark semantics only. Visibility gating
(for example requiring a `codeHref` in some inline/no-hint paths) is handled by
`renderParts`.
-/
private def statusMarkFromResolvedCodeSource : BlockCodeData → BlockStatusMark
  | .userOk =>
    {
      status := .proved
      title := "Marked complete via (leanok := true)"
      symbolOverride? := some "✓ (manually set)"
    }
  | .external decls =>
    externalStatusMark (externalHeadingAggregate decls)
  | .inline codeData =>
    inlineStatusMark codeData

private def statusMarkFromCodeSource
    (source? : Option BlockCodeData) : BlockStatusMark :=
  source?.map statusMarkFromResolvedCodeSource |>.getD (completionStatusMark 0 0)

/--
Render Lean summary UI for an informal block heading.

Inputs come from canonical block/code data:
- `codeHref`: link to the generated Lean code block when available.
- `source`: resolved optional code source (inline/userOk/external).
-/
def renderParts (data : BlockData) (cdata : ComputedData) (hrefOf : Name → Option String) : RenderParts :=
  open Verso.Output.Html in
  match data.kind with
  | .proof => {}
  | .statement _statementKind =>
    let externalDecls := cdata.source.map BlockCodeData.externalDecls |>.getD #[]
    if !externalDecls.isEmpty then
      let agg := externalHeadingAggregate externalDecls
      let codeEntryTitle := externalCodeEntryTitle agg.found agg.total agg.missing agg.withSorries
      let codeEntryTooltip := renderExternalSummaryTooltip externalDecls hrefOf
      let linkNode : Output.Html :=
        if let some href := cdata.codeHref then
          {{<a class="bp_code_link" href={{href}} title={{codeEntryTitle}}>"L∃∀N"</a>}}
        else
          {{<span class="bp_code_link" title={{codeEntryTitle}}>"L∃∀N"</span>}}
      {
        statusMark := some (statusMarkFromCodeSource cdata.source)
        codeEntry := {{<span class="bp_code_link_wrap">{{linkNode}}{{codeEntryTooltip}}</span>}}
      }
    else
      let inlineData? := cdata.source.bind BlockCodeData.inlineData?
      let userOk := cdata.source.map BlockCodeData.isUserOk |>.getD false
      let hasInline := cdata.codeHref.isSome || inlineData?.isSome
      let hasCodeEntry := hasInline || userOk
      let codeEntryTooltip : Output.Html :=
        match inlineData? with
        | some codeData => renderCodeSummaryTooltip data.label codeData.definedDefs codeData.definedTheorems hrefOf
        | none =>
          if userOk then
            userOkSummaryTooltip
          else
            .empty
      let codeEntryTitle : String :=
        if hasInline then
          "Lean declarations"
        else if userOk then
          "Marked complete via (leanok := true)"
        else
          "Lean declarations"
      let codeEntry : Output.Html :=
        if !hasCodeEntry then
          .empty
        else
          let linkNode : Output.Html :=
            if let some href := cdata.codeHref then
              {{<a class="bp_code_link" href={{href}} title={{codeEntryTitle}}>"L∃∀N"</a>}}
            else
              {{<span class="bp_code_link" title={{codeEntryTitle}}>"L∃∀N"</span>}}
          {{<span class="bp_code_link_wrap">{{linkNode}}{{codeEntryTooltip}}</span>}}
      let statusMarkCandidate := statusMarkFromCodeSource cdata.source
      let statusMark : Option BlockStatusMark :=
        if userOk then
          some statusMarkCandidate
        else if cdata.codeHref.isNone then
          none
        else
          some statusMarkCandidate
      { statusMark, codeEntry }

end CodeSummary
end Informal
