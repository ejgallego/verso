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
  statusMark : Output.Html := .empty
  codeEntry : Output.Html := .empty

private def summaryStatusText (status : Data.ProvedStatus) : String :=
  match status with
  | .axiomLike => "axiom-like (no body)"
  | .containsSorry _ => provedStatusLocationText status
  | .proved => "unknown"

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
    (s!"{decl.name} [{summaryStatusText decl.provedStatus}]", hrefOf decl.name)

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
Render the inline Lean summary UI for an informal block heading.

Inputs come from canonical block/code data:
- `codeHref`: link to the generated Lean code block when available.
- `source`: resolved optional code source (inline/userOk/external).
-/
def renderParts (data : BlockData) (cdata : ComputedData) (hrefOf : Name → Option String) : RenderParts :=
  open Verso.Output.Html in
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
  let hasStatementSorries : Bool :=
    match inlineData? with
    | none => false
    | some codeData =>
      (codeData.definedDefs ++ codeData.definedTheorems).any (fun decl => decl.provedStatus.hasTypeGap)
  let hasProofSorries : Bool :=
    match inlineData? with
    | none => false
    | some codeData =>
      (codeData.definedDefs ++ codeData.definedTheorems).any (fun decl => decl.provedStatus.hasProofGap)
  let statusMark : Output.Html :=
    if userOk then
      {{ <span class="bp_status_mark" title="Marked complete via (leanok := true)">"✓ (manually set)"</span> }}
    else if cdata.codeHref.isNone then
      .empty
    else
      let (hasSorriesHere, whereTxt) :=
        if data.isProof then
          (hasProofSorries, "proof")
        else
          (hasStatementSorries, "statement")
      let mark := if hasSorriesHere then "✗" else "✓"
      let title := if hasSorriesHere then s!"Contains sorries in {whereTxt}" else s!"No sorries in {whereTxt}"
      {{ <span class="bp_status_mark" title={{title}}>{{.text true mark}}</span> }}
  { statusMark, codeEntry }

end CodeSummary
end Informal
