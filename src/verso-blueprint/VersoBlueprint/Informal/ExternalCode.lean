/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.ExternalRefSnapshot
import VersoBlueprint.Informal.CodeCommon
import VersoBlueprint.NameParsing

namespace Informal

/--
If enabled, unresolved or ambiguous external Lean names in `(lean := "...")` are treated as
errors instead of warnings.
-/
register_option verso.blueprint.externalCode.strictResolve : Bool := {
  defValue := false
  descr := "Treat unresolved or ambiguous `(lean := ...)` external references as errors"
}

namespace ExternalCode

open Verso Doc Elab
open Lean Elab

private def splitExternalCodeRefs (s : String) : Array String :=
  NameParsing.splitCsvNormalized s

/--
Parse and normalize `(lean := "a,b,c")` directive values into canonical external refs.

Returns `(refs, invalidEntries)` where invalid entries keep the original token plus parse error.
-/
def parseExternalCodeList (lean : Option String) : Array Data.ExternalRef × Array String :=
  match lean with
  | none => (#[], #[])
  | some s =>
    (splitExternalCodeRefs s).foldl (init := (#[], #[])) fun (acc, invalid) ref =>
      match NameParsing.parseNameE ref with
      | .ok name =>
        let extRef := Data.ExternalRef.ofName name .directiveLean
        if acc.any (fun entry => entry.canonical == extRef.canonical) then
          (acc, invalid)
        else
          (acc.push extRef, invalid)
      | .error err =>
        (acc, invalid.push s!"{ref} ({err})")

private def pushExternalRefDedup (acc : Array Data.ExternalRef) (ref : Data.ExternalRef) : Array Data.ExternalRef :=
  match acc.findIdx? (fun entry => entry.canonical == ref.canonical) with
  | some idx =>
    let current := acc[idx]!
    let merged : Data.ExternalRef := Data.ExternalRef.merge current ref
    acc.set! idx merged
  | none =>
    acc.push ref

private def parsedExternalRef (ref : Data.ExternalRef) : Data.ExternalRef :=
  { ref with canonical := ref.written.eraseMacroScopes }

private def resolvedExternalRef (ref : Data.ExternalRef) (resolved : Name) : Data.ExternalRef :=
  { written := ref.written, canonical := resolved.eraseMacroScopes, origin := ref.origin }

section
variable {m : Type → Type} [Monad m]

private def markExternalRefSnapshot [MonadOptions m] [MonadLiftT CoreM m]
    (ref : Data.ExternalRef) : m Data.ExternalRef := do
  let opts ← getOptions
  liftM <| externalRefSnapshotAtCurrentDir opts ref

private def resolveExternalNameCandidates [MonadResolveName m] [MonadOptions m] [MonadEnv m]
    [MonadLog m] [AddMessageContext m]
    (name : Name) : m (Array Name) := do
  let resolved ← Lean.resolveGlobalName name (enableLog := false)
  return resolved.foldl (init := #[]) fun acc (candidate, fieldList) =>
    if fieldList.isEmpty && !acc.contains candidate then
      acc.push candidate
    else
      acc

/--
Resolve parsed external refs in the current namespace/open scope.

Resolution keeps provenance snapshots and preserves deduplication by canonical name.
When strict mode is disabled, unresolved/ambiguous names are kept as parsed and reported as warnings.
-/
def resolveExternalCodeList [MonadResolveName m] [MonadOptions m] [MonadLiftT CoreM m] [MonadEnv m]
    [MonadLog m] [AddMessageContext m] [MonadError m]
    (label : Name) (labelSyntax : Syntax) (refs : Array Data.ExternalRef) : m (Array Data.ExternalRef) := do
  let strictResolve :=
    (← getOptions).get
      verso.blueprint.externalCode.strictResolve.name
      verso.blueprint.externalCode.strictResolve.defValue
  refs.foldlM (init := #[]) fun acc ref => do
    let candidates ← resolveExternalNameCandidates ref.written
    match candidates.toList with
    | [] =>
      let msg := m!"Label {label}: external Lean name '{ref.written}' could not be resolved in current namespace/open declarations"
      if strictResolve then
        throwErrorAt labelSyntax msg
      else
        logWarningAt labelSyntax m!"{msg}; keeping parsed name"
        let ref ← markExternalRefSnapshot (parsedExternalRef ref)
        return pushExternalRefDedup acc ref
    | [resolved] =>
      let ref ← markExternalRefSnapshot (resolvedExternalRef ref resolved)
      return pushExternalRefDedup acc ref
    | many =>
      let msg := m!"Label {label}: external Lean name '{ref.written}' is ambiguous ({String.intercalate ", " (many.map toString)})"
      if strictResolve then
        throwErrorAt labelSyntax msg
      else
        logWarningAt labelSyntax m!"{msg}; keeping parsed name"
        let ref ← markExternalRefSnapshot (parsedExternalRef ref)
        return pushExternalRefDedup acc ref

end

/--
Project external declarations from block code status.

This keeps a single extraction point for consumers that only care about external-code refs.
-/
def externalDeclsOfCodeStatus (codeStatus : BlockCodeStatus) : Array Data.ExternalRef :=
  match codeStatus with
  | .external decls => decls
  | _ => #[]

private structure LinkedExternalDecl where
  decl : Data.ExternalRef
  href : Option String := none

private def externalDeclHasSorry (decl : LinkedExternalDecl) : Bool :=
  decl.decl.present && provedStatusHasSorry decl.decl.provedStatus

private def externalDeclSorryLocation (decl : LinkedExternalDecl) : String :=
  if decl.decl.present then
    provedStatusLocationText decl.decl.provedStatus
  else
    "location unknown"

private def externalDeclRenderError? (decl : LinkedExternalDecl) : Option String :=
  if decl.decl.present then
    renderErrorMessage? decl.decl.render
  else
    none

private def externalDeclLookupError? (decl : LinkedExternalDecl) : Option Data.ExternalDeclLookupError :=
  if decl.decl.present then none else some .notPresentAtRegistration

private structure ExternalDeclAggregate where
  total : Nat
  found : Nat
  missing : Nat
  renderErrors : Nat
  withGaps : Nat

private def externalDeclAggregate (decls : Array LinkedExternalDecl) : ExternalDeclAggregate :=
  decls.foldl
      (init := { total := decls.size, found := 0, missing := 0, renderErrors := 0, withGaps := 0 })
      fun acc decl =>
        let (found, missing) :=
          if decl.decl.present then (acc.found + 1, acc.missing) else (acc.found, acc.missing + 1)
        let renderErrors := acc.renderErrors + (if (externalDeclRenderError? decl).isSome then 1 else 0)
        let withGaps := acc.withGaps + (if externalDeclHasSorry decl then 1 else 0)
        { acc with found, missing, renderErrors, withGaps }

private def externalDeclGapStatusText? (item : LinkedExternalDecl) : Option String :=
  if externalDeclHasSorry item then
    if provedStatusContainsSorry item.decl.provedStatus then
      some s!"contains sorry {externalDeclSorryLocation item}"
    else
      some (externalDeclSorryLocation item)
  else
    none

private def externalPanelStatus (agg : ExternalDeclAggregate) : String × String × String :=
  if agg.missing > 0 then
    ("bp_external_status_missing", "●", s!"External Lean references: {agg.found}/{agg.total} present ({agg.missing} missing)")
  else if agg.renderErrors > 0 then
    ("bp_external_status_error", "●", s!"External Lean references: all present, {agg.renderErrors} docgen render failures")
  else if agg.withGaps > 0 then
    ("bp_external_status_sorry", "●", s!"External Lean references: all present, {agg.withGaps} incomplete")
  else
    ("bp_external_status_ok", "●", s!"External Lean references: all {agg.total} present")

private def externalCodeEntryTitle (agg : ExternalDeclAggregate) : String :=
  if agg.missing > 0 then
    s!"External Lean references ({agg.found}/{agg.total} present)"
  else if agg.renderErrors > 0 then
    s!"External Lean references (all present: {agg.found}/{agg.total}; docgen errors: {agg.renderErrors})"
  else if agg.withGaps > 0 then
    s!"External Lean references (all present: {agg.found}/{agg.total}; incomplete: {agg.withGaps})"
  else
    s!"External Lean references (all present: {agg.found}/{agg.total})"

private def externalStatusMarkMeta (agg : ExternalDeclAggregate) : String × String :=
  if agg.missing > 0 then
    (s!"External Lean names: {agg.found} present, {agg.missing} missing", "✗")
  else if agg.renderErrors > 0 then
    (s!"External Lean names ({agg.total}) are present, but {agg.renderErrors} docgen renders failed", "✗")
  else if agg.withGaps > 0 then
    (s!"External Lean names ({agg.total}) are present, but {agg.withGaps} are incomplete", "⚠")
  else
    (s!"External Lean names ({agg.total}) are present", "✓")

private def externalDeclStatusClass (item : LinkedExternalDecl) : String :=
  if !item.decl.present then
    "bp_external_decl_missing"
  else if (renderErrorMessage? item.decl.render).isSome then
    "bp_external_decl_error"
  else if externalDeclHasSorry item then
    "bp_external_decl_sorry"
  else
    "bp_external_decl_ok"

private def externalDeclSummaryStatusText (item : LinkedExternalDecl) : String :=
  if let some err := externalDeclRenderError? item then
    s!"(has Lean declaration; docgen render failed: {err})"
  else if !item.decl.present then
    "(missing Lean declaration)"
  else
    match externalDeclGapStatusText? item with
    | some txt => s!"(has Lean declaration; {txt})"
    | none => "(has Lean declaration)"

private def externalDeclPanelStatusText (item : LinkedExternalDecl) : String :=
  if (externalDeclRenderError? item).isSome then
    "docgen render failed"
  else if !item.decl.present then
    "missing declaration"
  else
    (externalDeclGapStatusText? item).getD "complete"

private def externalDeclSorryInfo? (item : LinkedExternalDecl) : Option String :=
  if !item.decl.present then
    none
  else if externalDeclHasSorry item then
    if provedStatusContainsSorry item.decl.provedStatus then
      some s!"Contains sorry ({externalDeclSorryLocation item})"
    else
      some "Axiom-like declaration (no body)"
  else
    none

private def sourcePosText (pos : Lean.Position) : String :=
  s!"{pos.line}:{pos.column}"

private def sourceRangeText (range : Lean.DeclarationRange) : String :=
  s!"{sourcePosText range.pos}-{sourcePosText range.endPos}"

private def externalDeclNode (item : LinkedExternalDecl) : Output.Html :=
  open Verso.Output.Html in
  let declTxt := {{<code>{{.text true s!"{item.decl.written}"}}</code>}}
  if let some href := item.href then
    {{<a href={{href}}>{{declTxt}}</a>}}
  else
    declTxt

private def externalDeclSourceInfo? (item : LinkedExternalDecl) : Option String :=
  if !item.decl.present then
    none
  else
    match Data.ExternalDeclProvenance.moduleName? item.decl.provenance,
      (item.decl.selectionRange?.map sourceRangeText <|> item.decl.range?.map sourceRangeText) with
    | some moduleName, some rangeTxt => some s!"{moduleName} @ {rangeTxt}"
    | some moduleName, none => some s!"{moduleName}"
    | none, some rangeTxt => some s!"{rangeTxt}"
    | none, none => none

private def externalDeclSourceRef? (item : LinkedExternalDecl) : Option Output.Html :=
  open Verso.Output.Html in
  if !item.decl.present then
    none
  else
    item.decl.sourceHref?.map fun href =>
      {{<a class="bp_code_link" href={{href}}>"open source"</a>}}

private def externalDeclSourceRefRow? (item : LinkedExternalDecl) : Option Output.Html :=
  open Verso.Output.Html in
  (externalDeclSourceRef? item).map fun sourceRef =>
    {{<div class="bp_external_decl_meta">"source ref: " {{sourceRef}}</div>}}

private def externalDeclItem (item : LinkedExternalDecl) (statusTxt : String)
    (body : Output.Html := .empty) (headTail : Output.Html := .empty) : Output.Html :=
  open Verso.Output.Html in
  let statusClass := externalDeclStatusClass item
  {{
    <li class="bp_external_decl_item">
      <div class="bp_external_decl_head">
        {{externalDeclNode item}}
        <span class={{statusClass}}>{{.text true statusTxt}}</span>
        {{headTail}}
      </div>
      {{body}}
    </li>
  }}

private partial def docGenHtmlToOutputHtml : DocGenHtml → Output.Html
  | .element tag _inline attrs children =>
      .tag tag attrs (.seq (children.map docGenHtmlToOutputHtml))
  | .text s => .text true s
  | .raw s => .text false s

private def kindTextForDecl? (decl : Data.ExternalRef) : Option String :=
  if !decl.present then
    none
  else
    some <| decl.kind?.getD (if decl.isTheoremLike then "theorem" else "definition")

/--
Rendered fragments produced by `ExternalCode.renderParts` for heading badges and the panel.
-/
structure RenderParts where
  statusMark : Output.Html := .empty
  codeEntry : Output.Html := .empty
  externalCodePanel : Output.Html := .empty

/--
Render external-code UI fragments for an informal block.

This function owns rendering for `(lean := ...)` references:
- heading status mark,
- heading Lean entry/tooltip,
- optional external code panel body.
-/
def renderParts (data : BlockData) (codeHref : Option String)
    (externalDecls : Array Data.ExternalRef) (getDeclHref : Name → Option String) : RenderParts :=
  open Verso.Output.Html in
  if externalDecls.isEmpty then
    {}
  else
    let linkedDecls := externalDecls.map fun decl =>
      let href :=
        if decl.present then
          match getDeclHref decl.canonical with
          | some href => some href
          | none => getDeclHref decl.written
        else
          getDeclHref decl.written
      { decl, href }
    let externalAgg := externalDeclAggregate linkedDecls
    let externalSummaryListItems (items : Array LinkedExternalDecl) : Output.Html :=
      if items.isEmpty then
        {{<li class="bp_code_hover_none">"none"</li>}}
      else
        .seq <| items.map fun item =>
          let statusTxt := externalDeclSummaryStatusText item
          let hasProvenanceDetails :=
            if !item.decl.present then false else
            match item.decl.provenance with
            | .unknown => false
            | _ => true
          let headTail : Output.Html :=
            if hasProvenanceDetails then
              {{<span class="bp_external_badge">{{.text true (Data.ExternalDeclProvenance.label item.decl.provenance)}}</span>}}
            else
              .empty
          let sourcePath? := if item.decl.present then Data.ExternalDeclProvenance.sourcePath? item.decl.provenance else none
          let sourceInfo? := externalDeclSourceInfo? item
          let sorryInfo? := externalDeclSorryInfo? item
          let renderError? := externalDeclRenderError? item
          let lookupError? := (externalDeclLookupError? item).map Data.ExternalDeclLookupError.message
          let body : Output.Html := {{
            {{if let some kind := kindTextForDecl? item.decl then {{<div class="bp_external_decl_meta">"kind: " <code>{{.text true kind}}</code></div>}} else .empty}}
            {{if let some sourceInfo := sourceInfo? then {{<div class="bp_external_decl_meta">"source: " <code>{{.text true sourceInfo}}</code></div>}} else .empty}}
            {{if let some sourcePath := sourcePath? then {{<div class="bp_external_decl_meta">"source path: " <code>{{.text true sourcePath}}</code></div>}} else .empty}}
            {{if let some sourceRefRow := externalDeclSourceRefRow? item then sourceRefRow else .empty}}
            {{if let some sorryInfo := sorryInfo? then {{<div class="bp_external_decl_meta bp_external_decl_missing">{{.text true sorryInfo}}</div>}} else .empty}}
            {{if let some renderError := renderError? then {{<div class="bp_external_decl_meta bp_external_decl_error">{{.text true s!"DocGen render error: {renderError}"}}</div>}} else .empty}}
            {{if let some lookupError := lookupError? then {{<div class="bp_external_decl_meta bp_external_decl_missing">{{.text true s!"Lookup error: {lookupError}"}}</div>}} else .empty}}
          }}
          externalDeclItem item statusTxt body headTail
    let externalPanelListItems (items : Array LinkedExternalDecl) : Output.Html :=
      if items.isEmpty then
        {{<li class="bp_code_hover_none">"none"</li>}}
      else
        .seq <| items.map fun item =>
          let statusTxt := externalDeclPanelStatusText item
          let statusClass := externalDeclStatusClass item
          if !item.decl.present then
            let body : Output.Html := {{
              <pre class="bp_external_decl_stmt bp_code_hover_none">{{.text true s!"declaration not found ({Data.ExternalDeclLookupError.message .notPresentAtRegistration})"}}</pre>
            }}
            externalDeclItem item statusTxt body
          else
            match item.decl.render with
            | .ok renderedHtml =>
              {{
                <li class="bp_external_decl_item bp_external_decl_item_rendered">
                  <div class="bp_external_decl_rendered">{{docGenHtmlToOutputHtml renderedHtml}}</div>
                  <div class="bp_external_decl_rendered_meta">
                    <span class={{statusClass}}>{{.text true statusTxt}}</span>
                    {{if let some sourceRef := externalDeclSourceRef? item then
                      {{<span class="bp_external_decl_rendered_source">{{sourceRef}}</span>}}
                     else .empty}}
                  </div>
                </li>
              }}
            | .error err =>
              let body : Output.Html := {{
                {{if let some sourceRefRow := externalDeclSourceRefRow? item then sourceRefRow else .empty}}
                <pre class="bp_external_decl_stmt bp_external_decl_render_error">{{.text true s!"DocGen render failed: {err.message}"}}</pre>
              }}
              externalDeclItem item statusTxt body
    let externalSummaryTooltip : Output.Html :=
      {{
        <div class="bp_code_hover" role="tooltip">
          <div class="bp_code_hover_title">"External Lean references"</div>
          <div class="bp_code_hover_section">
            <ul class="bp_code_hover_list">
              {{externalSummaryListItems linkedDecls}}
            </ul>
          </div>
        </div>
      }}
    let codeEntryTitle := externalCodeEntryTitle externalAgg
    let linkNode : Output.Html :=
      if let some href := codeHref then
        {{<a class="bp_code_link" href={{href}} title={{codeEntryTitle}}>"L∃∀N"</a>}}
      else
        {{<span class="bp_code_link" title={{codeEntryTitle}}>"L∃∀N"</span>}}
    let codeEntry : Output.Html :=
      {{<span class="bp_code_link_wrap">{{linkNode}}{{externalSummaryTooltip}}</span>}}
    let (statusTitle, statusText) := externalStatusMarkMeta externalAgg
    let statusMark : Output.Html :=
      {{ <span class="bp_status_mark" title={{statusTitle}}>{{.text true statusText}}</span> }}
    let externalStatusIndicator : Output.Html :=
      let (iconClass, iconText, iconTitle) := externalPanelStatus externalAgg
      let icon :=
        {{<span class={{s!"bp_external_status_icon {iconClass}"}} title={{iconTitle}}>{{.text true iconText}}</span>}}
      {{<span class="bp_code_hover_wrap bp_code_summary_indicator">{{icon}}{{externalSummaryTooltip}}</span>}}
    let externalCodePanel : Output.Html :=
      if data.isProof then
        .empty
      else
        let summaryText := s!"External Lean declarations for {data.kind} {data.count}"
        mkCodePanel summaryText codeEntryTitle externalStatusIndicator
          {{<ul class="bp_code_hover_list">{{externalPanelListItems linkedDecls}}</ul>}}
    { statusMark, codeEntry, externalCodePanel }

end ExternalCode
end Informal
