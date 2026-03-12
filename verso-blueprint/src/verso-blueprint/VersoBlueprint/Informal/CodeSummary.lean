/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Graph
import VersoBlueprint.Informal.CodeCommon
import VersoBlueprint.Informal.LeanCodeLink

namespace Informal
namespace CodeSummary

open Verso Doc Elab
open Lean Elab

/-!
`CodeSummary` computes the heading-level Lean status/summary fragments for informal blocks.

This module intentionally owns the high-level overview for one informal node:
status marks, declaration-summary tooltips, and code-panel indicators.

It does not own manifest-backed code-preview hovers for explicit links to code;
that narrower responsibility lives in `Informal.LeanCodeLink` /
`Informal.LeanCodePreview`.

Public API:
- `ComputedData`: normalized code inputs for one block heading.
- `RenderParts`: rendered heading fragments consumed by callers.
- `renderParts`: main entry point that derives status badge + Lean link node.
-/

/--
Canonical inputs used to compute Lean summary UI for one informal block.

`source` is the resolved optional code source for this block (`none` / `some userOk` /
`some inline` / `some external`).
Inline declaration summaries come from `.inline`; `codeHref` is used for heading link rendering.

Callers should pass `source` after applying code-source precedence
(typically via `BlockCodeData.ofHintAndInline`).
-/
structure ComputedData where
  /-- URL to the rendered Lean panel for this block, when available. -/
  codeHref : Option String := none
  /-- Canonical resolved source used for status and tooltip semantics. -/
  source : Option BlockCodeData := none

/--
Rendered fragments produced by `CodeSummary.renderParts` for an informal block heading.
-/
structure RenderParts where
  /-- Optional status icon rendered next to the statement heading. -/
  statusMark : Option BlockStatusMark := none
  /-- Optional Lean badge/link node (`L∃∀N`) with tooltip wrapper. -/
  codeEntry : Output.Html := .empty

structure PanelIndicatorParts where
  /-- Summary text exposed on the enclosing code-panel `<summary>` title. -/
  summaryTitle : String := ""
  /-- Top-right indicator node for the code panel summary row. -/
  indicator : Output.Html := .empty

inductive DeclSummaryKind where
  | definition
  | theoremLike
deriving Inhabited, Repr, BEq

/--
Normalized declaration summary row shared by inline and external Lean summary UI.

`present = false` is used only for external references that failed to resolve.
-/
structure DeclSummaryItem where
  name : Name
  href : Option String := none
  kind : DeclSummaryKind := .definition
  status : Data.ProvedStatus := .proved
  present : Bool := true
deriving Inhabited, Repr

private structure SummaryTooltipSection where
  title : String := ""
  items : Array DeclSummaryItem := #[]
  emptyText : String := "No associated Lean declarations."

private def declSummaryStatusText (item : DeclSummaryItem) : String :=
  if !item.present then
    "missing declaration"
  else if item.status.isIncomplete then
    provedStatusSummaryText item.status
  else
    "complete"

private def declSummaryStatusClass (item : DeclSummaryItem) : String :=
  if !item.present || item.status.isMissing then
    "bp_code_decl_status_missing"
  else if item.status.isAxiomLike then
    "bp_code_decl_status_axiom"
  else if item.status.isIncomplete then
    "bp_code_decl_status_warning"
  else
    "bp_code_decl_status_ok"

private def renderDeclSummaryItems (items : Array DeclSummaryItem) : Output.Html :=
  open Verso.Output.Html in
  if items.isEmpty then
    .empty
  else
    .seq <| items.map fun item =>
      let nameNode : Output.Html :=
        let txt := {{<code>{{.text true s!"{item.name}"}}</code>}}
        match item.href with
        | some href =>
          Informal.LeanCodeLink.renderResolved
            item.name txt "" (some href)
            (previewTitle := s!"{item.name}")
        | none => txt
      {{
        <li class="bp_code_decl_item">
          <span class="bp_code_decl_name">{{nameNode}}</span>
          <span class={{s!"bp_code_decl_status {declSummaryStatusClass item}"}}>
            {{.text true s!"[{declSummaryStatusText item}]"}}
          </span>
        </li>
      }}

private def summaryTooltipSection (tooltipSection : SummaryTooltipSection) : Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_code_hover_section">
      <span class="bp_code_hover_label">{{.text true tooltipSection.title}}</span>
      <ul class="bp_code_hover_list">
        {{if tooltipSection.items.isEmpty then
            {{<li class="bp_code_hover_none">{{.text true tooltipSection.emptyText}}</li>}}
          else
            renderDeclSummaryItems tooltipSection.items}}
      </ul>
    </div>
  }}

private def renderSummaryTooltip (title : String) (sections : Array SummaryTooltipSection) : Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_code_hover" role="tooltip">
      <div class="bp_code_hover_title">{{.text true title}}</div>
      {{.seq (sections.map summaryTooltipSection)}}
    </div>
  }}

private def inlineDeclSummaryItems (definedDefs definedTheorems : Array CodeDeclData)
    (hrefOf : Name → Option String) : Array DeclSummaryItem :=
  let defs := definedDefs.map fun decl =>
    {
      name := decl.name
      href := hrefOf decl.name
      kind := .definition
      status := decl.provedStatus
    }
  let theoremLikes := definedTheorems.map fun decl =>
    {
      name := decl.name
      href := hrefOf decl.name
      kind := .theoremLike
      status := decl.provedStatus
    }
  defs ++ theoremLikes

private def incompleteSummaryItems (items : Array DeclSummaryItem) : Array DeclSummaryItem :=
  items.filter fun item => !item.present || item.status.isIncomplete

def externalDeclKindText? (decl : Data.ExternalRef) : Option String :=
  if !decl.present then
    none
  else
    match decl.kind with
    | .definition => some "definition"
    | .lemma => some "lemma"
    | .theorem => some "theorem"
    | .corollary => some "corollary"

private def externalSummaryKind (decl : Data.ExternalRef) : DeclSummaryKind :=
  match decl.kind with
  | .definition => .definition
  | .lemma | .theorem | .corollary => .theoremLike

private def externalDeclHref (decl : Data.ExternalRef) (hrefOf : Name → Option String) : Option String :=
  if decl.present then
    match hrefOf decl.canonical with
    | some href => some href
    | none => hrefOf decl.written
  else
    hrefOf decl.written

private def externalDeclSummaryItems (decls : Array Data.ExternalRef)
    (hrefOf : Name → Option String) : Array DeclSummaryItem :=
  decls.map fun decl =>
    {
      name := decl.written
      href := externalDeclHref decl hrefOf
      kind := externalSummaryKind decl
      status := decl.provedStatus
      present := decl.present
    }

private def summaryPreviewItems (cdata : ComputedData)
    (hrefOf : Name → Option String) : Array DeclSummaryItem :=
  match cdata.source with
  | some (.inline codeData) =>
    inlineDeclSummaryItems codeData.definedDefs codeData.definedTheorems hrefOf
  | some (.external decls) =>
    externalDeclSummaryItems decls hrefOf
  | some .userOk | none =>
    #[]

private def summaryPreviewEmptyText (cdata : ComputedData) : String :=
  match cdata.source with
  | some .userOk => "Marked complete via (leanok := true)."
  | _ => "No associated Lean code or declarations."

private def renderSummaryPreview (label : Data.Label) (cdata : ComputedData)
    (hrefOf : Name → Option String) : Output.Html :=
  let items := summaryPreviewItems cdata hrefOf
  let sectionTitle :=
    if items.isEmpty then "Lean status" else "Associated Lean declarations"
  renderSummaryTooltip s!"{label}" #[
    {
      title := sectionTitle
      items
      emptyText := summaryPreviewEmptyText cdata
    }
  ]

private inductive CodeEntryVisual where
  | absent
  | proved
  | warning
  | missing
  | axiom
deriving BEq

private def CodeEntryVisual.symbol : CodeEntryVisual → String
  | .absent => "X"
  | .proved => "✓"
  | .warning => "⚠"
  | .missing => "!"
  | .axiom => "A"

private def CodeEntryVisual.classSuffix : CodeEntryVisual → String
  | .absent => "absent"
  | .proved => "proved"
  | .warning => "warning"
  | .missing => "missing"
  | .axiom => "axiom"

private def codeEntryVisual (hasSource : Bool) (statusMark : BlockStatusMark) : CodeEntryVisual :=
  if !hasSource then
    .absent
  else
    match statusMark.status with
    | .proved => .proved
    | .containsSorry _ => .warning
    | .missing => .missing
    | .axiomLike => .axiom

private def renderCodeEntryNode (href : Option String) (title : String) (visual : CodeEntryVisual) : Output.Html :=
  open Verso.Output.Html in
  let linkClass := s!"bp_code_link bp_code_link_status bp_code_link_status_{visual.classSuffix}" ++
    (if visual == .absent then " bp_code_link_empty" else "")
  let body : Output.Html := {{
    <span class="bp_code_status_symbol">{{.text true visual.symbol}}</span>
    <span class="bp_code_link_label">"L∃∀N"</span>
  }}
  match href with
  | some href =>
      {{<a class={{linkClass}} href={{href}} title={{title}}>{{body}}</a>}}
  | none =>
      {{<span class={{linkClass}} title={{title}}>{{body}}</span>}}

private def renderCodeEntryWrap (href : Option String) (title : String)
    (tooltip : Output.Html) (visual : CodeEntryVisual) : Output.Html :=
  open Verso.Output.Html in
  {{
    <span class="bp_code_link_wrap">
      {{renderCodeEntryNode href title visual}}
      {{tooltip}}
    </span>
  }}

private def axisCompletionText : Nat → String
  | 0 => "completed"
  | _ + 1 => "with sorries"

private def completionAxisText (statementSorryCount proofSorryCount : Nat) : String :=
  s!"Statement: {axisCompletionText statementSorryCount}; Proof: {axisCompletionText proofSorryCount}"

/--
Build completion status from declaration-level axis counts.

Counts are only used as presence signals (non-zero means "with sorries" on that axis);
they are not interpreted as precise sorry-reference totals.
-/
private def completionStatusFromCounts (statementSorryCount proofSorryCount : Nat) : Data.ProvedStatus :=
  Data.ProvedStatus.ofSorryFlags (statementSorryCount > 0) (proofSorryCount > 0)

private def completionStatusMark (statementSorryCount proofSorryCount : Nat) : BlockStatusMark :=
  let status := completionStatusFromCounts statementSorryCount proofSorryCount
  if status.isProved then
    {
      status
      title := completionAxisText statementSorryCount proofSorryCount
    }
  else
    {
      status
      title := completionAxisText statementSorryCount proofSorryCount
      symbolOverride? := some "⚠"
    }

private def statusMarkFromHealth (health : Informal.Graph.CodeHealth) : BlockStatusMark :=
  if health.hasMissingExternalDecls then
    {
      status := .missing
      title := s!"External Lean names: {health.presentDecls} present, {health.missingDecls} missing (statement/proof completion unknown)"
    }
  else
    if health.hasAxiomLike then
      {
        status := .axiomLike
        title := "Lean declarations include at least one axiom-like constant (no body)"
      }
    else
      completionStatusMark health.statementAxisCount health.proofAxisCount

private def inlineStatusMark (codeData : InlineCodeData) : BlockStatusMark :=
  let health := Informal.Graph.codeHealthOfBlockSource .definition {} (some (.inline codeData))
  if health.hasAxiomLike then
    {
      status := .axiomLike
      title := "Lean declarations include at least one axiom-like constant (no body)"
    }
  else
    statusMarkFromHealth health

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
    statusMarkFromHealth (Informal.Graph.codeHealthOfBlockSource .definition {} (some (.external decls)))
  | .inline codeData =>
    inlineStatusMark codeData

private def statusMarkFromCodeSource
    (source? : Option BlockCodeData) : BlockStatusMark :=
  source?.map statusMarkFromResolvedCodeSource |>.getD (completionStatusMark 0 0)

private def sortDeclsByCommand (decls : Array CodeDeclData) : Array CodeDeclData :=
  decls.qsort (fun a b =>
    a.commandIndex < b.commandIndex ||
    (a.commandIndex == b.commandIndex && a.name.toString < b.name.toString))

private def progressSegmentClass (missing hasSorry : Bool) : String :=
  if missing then
    "bp_code_progress_segment bp_code_progress_segment_missing"
  else if hasSorry then
    "bp_code_progress_segment bp_code_progress_segment_sorry"
  else
    "bp_code_progress_segment bp_code_progress_segment_ok"

private def codeSummaryText (label : Data.Label)
    (definedDefs definedTheorems : Array CodeDeclData) : String :=
  if definedDefs.isEmpty && definedTheorems.isEmpty then
    s!"{label}"
  else
    let definedDefNames := definedDefs.map (·.name)
    let definedTheoremNames := definedTheorems.map (·.name)
    let defs :=
      if definedDefNames.isEmpty then
        "none"
      else
        String.intercalate ", " (definedDefNames.toList.map toString)
    let thms :=
      if definedTheoremNames.isEmpty then
        "none"
      else
        String.intercalate ", " (definedTheoremNames.toList.map toString)
    let summaryItems := inlineDeclSummaryItems definedDefs definedTheorems (fun _ => none)
    let sorries := incompleteSummaryItems summaryItems
    let sorriesTxt :=
      if sorries.isEmpty then
        "none"
      else
        String.intercalate ", " (sorries.toList.map fun item => s!"{item.name} [{declSummaryStatusText item}]")
    s!"{label}\nLean definitions: {defs}\nLean theorems/lemmas: {thms}\nSorries: {sorriesTxt}"

private def wrapPanelIndicator (node tooltip : Output.Html) : Output.Html :=
  open Verso.Output.Html in
  {{<span class="bp_code_hover_wrap bp_code_summary_indicator">{{node}}{{tooltip}}</span>}}

private def renderInlinePanelIndicator (label : Data.Label) (codeData : InlineCodeData)
    (hrefOf : Name → Option String) : PanelIndicatorParts :=
  open Verso.Output.Html in
  let orderedDecls := sortDeclsByCommand (codeData.definedDefs ++ codeData.definedTheorems)
  let tooltip := renderSummaryPreview label { source := some (.inline codeData) } hrefOf
  let indicator : Output.Html :=
    if orderedDecls.isEmpty then
      .empty
    else
      let segments := orderedDecls.map fun decl =>
        let hasSorry := provedStatusHasSorry decl.provedStatus
        let cls := progressSegmentClass false hasSorry
        let weight := max decl.weight 1
        let title :=
          if hasSorry then
            if provedStatusContainsSorry decl.provedStatus then
              s!"{decl.name}: contains sorry {provedStatusLocationText decl.provedStatus}"
            else
              s!"{decl.name}: {provedStatusLocationText decl.provedStatus}"
          else
            s!"{decl.name}: complete"
        {{
          <span class={{cls}} title={{title}} style={{s!"flex: {weight} 1 0%"}}></span>
        }}
      let bar := {{<span class="bp_code_progress" aria-label="Lean declaration progress">{{segments}}</span>}}
      wrapPanelIndicator bar tooltip
  {
    summaryTitle := codeSummaryText label codeData.definedDefs codeData.definedTheorems
    indicator
  }

private def pluralizeKindText (kind : String) : String :=
  match kind with
  | "lemma" => "lemmas"
  | "theorem" => "theorems"
  | "definition" => "definitions"
  | "corollary" => "corollaries"
  | _ => kind ++ "s"

private def externalIndicatorKindText?
    (decls : Array Data.ExternalRef) (health : Informal.Graph.CodeHealth) : Option String :=
  if health.missingDecls > 0 || decls.isEmpty then
    none
  else
    let kinds := decls.filterMap externalDeclKindText?
    if kinds.size != decls.size || kinds.isEmpty then
      none
    else
      let first := kinds[0]!
      if kinds.all (· == first) then
        some first
      else
        none

private def externalIndicatorText
    (decls : Array Data.ExternalRef) (health : Informal.Graph.CodeHealth) : String :=
  let declText :=
    match externalIndicatorKindText? decls health with
    | some kind =>
      if health.totalDecls == 1 then
        s!"1 {kind}"
      else
        s!"{health.totalDecls} {pluralizeKindText kind}"
    | none =>
      if health.totalDecls == 1 then
        "1 declaration"
      else
        s!"{health.totalDecls} declarations"
  if health.missingDecls > 0 then
    s!"{declText}, {health.missingDecls} missing"
  else if health.anyGapCount > 0 then
    if health.totalDecls == 1 then
      s!"{declText}, incomplete"
    else
      s!"{declText}, {health.anyGapCount} incomplete"
  else
    declText

private def externalIndicatorStatus
    (health : Informal.Graph.CodeHealth) : String × String × String :=
  if health.missingDecls > 0 then
    ("bp_external_status_missing", "●", s!"Lean declarations: {health.presentDecls}/{health.totalDecls} present ({health.missingDecls} missing)")
  else if health.anyGapCount > 0 then
    ("bp_external_status_sorry", "●", s!"Lean declarations: all present, {health.anyGapCount} incomplete")
  else
    ("bp_external_status_ok", "●", s!"Lean declarations: all {health.totalDecls} present")

private def renderExternalPanelIndicator (decls : Array Data.ExternalRef)
    (label : Data.Label) (hrefOf : Name → Option String) : PanelIndicatorParts :=
  open Verso.Output.Html in
  let health := Informal.Graph.codeHealthOfBlockSource .definition {} (some (.external decls))
  let tooltip := renderSummaryPreview label { source := some (.external decls) } hrefOf
  let (iconClass, iconText, iconTitle) := externalIndicatorStatus health
  let badgeText := externalIndicatorText decls health
  let badge : Output.Html := {{
    <span class={{s!"bp_external_status_badge bp_external_status_badge_summary {iconClass}"}} title={{iconTitle}}>
      <span class={{s!"bp_external_status_icon {iconClass}"}}>{{.text true iconText}}</span>
      <span class="bp_external_status_badge_text">{{.text true badgeText}}</span>
    </span>
  }}
  {
    summaryTitle := externalCodeEntryTitle health.presentDecls health.totalDecls health.missingDecls health.anyGapCount
    indicator := wrapPanelIndicator badge tooltip
  }

/--
Render the top-right code-panel indicator from canonical code-source data.

Inline blocks use the weighted progress bar; external references keep the pill-style
indicator for now, but both paths share the same normalized declaration summary model
for hover content.
-/
def renderPanelIndicator (label : Data.Label) (cdata : ComputedData)
    (hrefOf : Name → Option String) : PanelIndicatorParts :=
  match cdata.source with
  | some (.inline codeData) =>
    renderInlinePanelIndicator label codeData hrefOf
  | some (.external decls) =>
    renderExternalPanelIndicator decls label hrefOf
  | some .userOk =>
    { summaryTitle := "Marked complete via (leanok := true)" }
  | none =>
    { summaryTitle := "No associated Lean declarations" }

/--
Render Lean summary UI for an informal block heading.

Inputs come from canonical block/code data:
- `codeHref`: link to the generated Lean code block when available.
- `source`: resolved optional code source (inline/userOk/external).

Output policy:
- `.proof` headings return an empty `RenderParts`.
- statement headings with external refs always render a status mark and an external-summary tooltip.
- inline/no-hint headings hide the status mark when `codeHref` is absent,
  except for manual `(leanok := true)` where the explicit override mark is kept.
-/
def renderParts (data : BlockData) (cdata : ComputedData) (hrefOf : Name → Option String) : RenderParts :=
  open Verso.Output.Html in
  match data.kind with
  | .proof => {}
  | .statement statementKind =>
    let externalDecls := cdata.source.map BlockCodeData.externalDecls |>.getD #[]
    let codeEntryTooltip := renderSummaryPreview data.label cdata hrefOf
    if !externalDecls.isEmpty then
      let health := Informal.Graph.codeHealthOfBlockSource statementKind {} cdata.source
      let codeEntryTitle := externalCodeEntryTitle health.presentDecls health.totalDecls health.missingDecls health.anyGapCount
      let statusMark := statusMarkFromCodeSource cdata.source
      {
        statusMark := some statusMark
        codeEntry := renderCodeEntryWrap cdata.codeHref codeEntryTitle codeEntryTooltip
          (codeEntryVisual true statusMark)
      }
    else
      let inlineData? := cdata.source.bind BlockCodeData.inlineData?
      let userOk := cdata.source.map BlockCodeData.isUserOk |>.getD false
      let hasInline := cdata.codeHref.isSome || inlineData?.isSome
      let hasSource := hasInline || userOk
      let codeEntryTitle : String :=
        if hasInline then
          "Lean declarations"
        else if userOk then
          "Marked complete via (leanok := true)"
        else
          "No associated Lean declarations"
      let statusMarkCandidate := statusMarkFromCodeSource cdata.source
      let codeEntry : Output.Html :=
        renderCodeEntryWrap cdata.codeHref codeEntryTitle codeEntryTooltip
          (codeEntryVisual hasSource statusMarkCandidate)
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
