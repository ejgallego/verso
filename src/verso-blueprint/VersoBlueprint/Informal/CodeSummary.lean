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

private structure ExternalHeadingAggregate where
  total : Nat
  found : Nat
  missing : Nat
  withGaps : Nat

private def externalHeadingAggregate (decls : Array Data.ExternalRef) : ExternalHeadingAggregate :=
  decls.foldl (init := { total := decls.size, found := 0, missing := 0, withGaps := 0 }) fun acc decl =>
    let (found, missing) :=
      if decl.present then (acc.found + 1, acc.missing) else (acc.found, acc.missing + 1)
    let withGaps := acc.withGaps + (if externalDeclHasGap decl then 1 else 0)
    { acc with found, missing, withGaps }

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

private def externalStatusMark (agg : ExternalHeadingAggregate) : BlockStatusMark :=
  if agg.missing > 0 then
    {
      status := .missing
      title := s!"External Lean names: {agg.found} present, {agg.missing} missing"
    }
  else if agg.withGaps > 0 then
    {
      status := .containsSorry #[]
      title := s!"External Lean names ({agg.total}) are present, but {agg.withGaps} are incomplete"
      symbolOverride? := some "⚠"
    }
  else
    {
      status := .proved
      title := s!"External Lean names ({agg.total}) are present"
    }

/--
Render Lean summary UI for an informal block heading.

Inputs come from canonical block/code data:
- `codeHref`: link to the generated Lean code block when available.
- `source`: resolved optional code source (inline/userOk/external).
-/
def renderParts (data : BlockData) (cdata : ComputedData) (hrefOf : Name → Option String) : RenderParts :=
  open Verso.Output.Html in
  match data.kind with
  | none => {}
  | some statement =>
    let statementKind := statement.kind
    let externalDecls := cdata.source.map BlockCodeData.externalDecls |>.getD #[]
    if !externalDecls.isEmpty then
      let agg := externalHeadingAggregate externalDecls
      let codeEntryTitle := externalCodeEntryTitle agg.found agg.total agg.missing agg.withGaps
      let codeEntryTooltip := renderExternalSummaryTooltip externalDecls hrefOf
      let linkNode : Output.Html :=
        if let some href := cdata.codeHref then
          {{<a class="bp_code_link" href={{href}} title={{codeEntryTitle}}>"L∃∀N"</a>}}
        else
          {{<span class="bp_code_link" title={{codeEntryTitle}}>"L∃∀N"</span>}}
      {
        statusMark := some (externalStatusMark agg)
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
      let hasBlockingSorries : Bool :=
        match inlineData? with
        | none => false
        | some codeData =>
          Data.ProvedStatus.anyBlocksStatementCompletion statementKind
            (codeData.definedDefs ++ codeData.definedTheorems) (·.provedStatus)
      let statusMark : Option BlockStatusMark :=
        if userOk then
          some {
            status := .proved
            title := "Marked complete via (leanok := true)"
            symbolOverride? := some "✓ (manually set)"
          }
        else if cdata.codeHref.isNone then
          none
        else
          let title :=
            if hasBlockingSorries then
              "Contains sorries that block completion"
            else
              "No sorries that block completion"
          some {
            status := if hasBlockingSorries then .containsSorry #[] else .proved
            title
          }
      { statusMark, codeEntry }

end CodeSummary
end Informal
