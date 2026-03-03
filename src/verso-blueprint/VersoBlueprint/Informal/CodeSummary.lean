/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Data
import VersoBlueprint.DocGenNameRender
import VersoBlueprint.Informal.CodeCommon

namespace Informal

open Verso Doc Elab
open Lean Elab

private def externalDeclHasSorry (decl : ExternalHoverDecl) : Bool :=
  decl.decl.present && provedStatusHasSorry decl.decl.provedStatus

private def externalDeclSorryLocation (decl : ExternalHoverDecl) : String :=
  if decl.decl.present then
    provedStatusLocationText decl.decl.provedStatus
  else
    "location unknown"

private def externalDeclRenderError? (decl : ExternalHoverDecl) : Option String :=
  if decl.decl.present then
    renderErrorMessage? decl.decl.render
  else
    none

private def externalDeclLookupError? (decl : ExternalHoverDecl) : Option Data.ExternalDeclLookupError :=
  if decl.decl.present then none else some .notPresentAtRegistration

private structure ExternalDeclAggregate where
  total : Nat
  found : Nat
  missing : Nat
  renderErrors : Nat
  withGaps : Nat

private def externalDeclAggregate (decls : Array ExternalHoverDecl) : ExternalDeclAggregate :=
  decls.foldl
      (init := { total := decls.size, found := 0, missing := 0, renderErrors := 0, withGaps := 0 })
      fun acc decl =>
        let (found, missing) :=
          if decl.decl.present then (acc.found + 1, acc.missing) else (acc.found, acc.missing + 1)
        let renderErrors := acc.renderErrors + (if (externalDeclRenderError? decl).isSome then 1 else 0)
        let withGaps := acc.withGaps + (if externalDeclHasSorry decl then 1 else 0)
        { acc with found, missing, renderErrors, withGaps }

private def externalDeclGapStatusText? (item : ExternalHoverDecl) : Option String :=
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

private def externalDeclStatusClass (item : ExternalHoverDecl) : String :=
  if !item.decl.present then
    "bp_external_decl_missing"
  else if (renderErrorMessage? item.decl.render).isSome then
    "bp_external_decl_error"
  else if externalDeclHasSorry item then
    "bp_external_decl_sorry"
  else
    "bp_external_decl_ok"

private def externalDeclHoverStatusText (item : ExternalHoverDecl) : String :=
  if let some err := externalDeclRenderError? item then
    s!"(has Lean declaration; docgen render failed: {err})"
  else if !item.decl.present then
    "(missing Lean declaration)"
  else
    match externalDeclGapStatusText? item with
    | some txt => s!"(has Lean declaration; {txt})"
    | none => "(has Lean declaration)"

private def externalDeclPanelStatusText (item : ExternalHoverDecl) : String :=
  if (externalDeclRenderError? item).isSome then
    "docgen render failed"
  else if !item.decl.present then
    "missing declaration"
  else
    (externalDeclGapStatusText? item).getD "complete"

private def externalDeclSorryInfo? (item : ExternalHoverDecl) : Option String :=
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

private def externalDeclNode (item : ExternalHoverDecl) : Output.Html :=
  open Verso.Output.Html in
  let declTxt := {{<code>{{.text true s!"{item.decl.written}"}}</code>}}
  if let some href := item.href then
    {{<a href={{href}}>{{declTxt}}</a>}}
  else
    declTxt

private def externalDeclSourceInfo? (item : ExternalHoverDecl) : Option String :=
  if !item.decl.present then
    none
  else
    match Data.ExternalDeclProvenance.moduleName? item.decl.provenance,
      (item.decl.selectionRange?.map sourceRangeText <|> item.decl.range?.map sourceRangeText) with
    | some moduleName, some rangeTxt => some s!"{moduleName} @ {rangeTxt}"
    | some moduleName, none => some s!"{moduleName}"
    | none, some rangeTxt => some s!"{rangeTxt}"
    | none, none => none

private def externalDeclSourceRef? (item : ExternalHoverDecl) : Option Output.Html :=
  open Verso.Output.Html in
  if !item.decl.present then
    none
  else
    item.decl.sourceHref?.map fun href =>
      {{<a class="bp_code_link" href={{href}}>"open source"</a>}}

private def externalDeclSourceRefRow? (item : ExternalHoverDecl) : Option Output.Html :=
  open Verso.Output.Html in
  (externalDeclSourceRef? item).map fun sourceRef =>
    {{<div class="bp_external_decl_meta">"source ref: " {{sourceRef}}</div>}}

private def externalDeclItem (item : ExternalHoverDecl) (statusTxt : String)
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

def toHtml (data : BlockData) (cdata : ComputedData) (attrs : Array (String × String))
    (content : Array Output.Html) : Output.Html :=
  open Verso.Output.Html in
  let codeHover : Output.Html :=
    match cdata.codeHover with
    | none => .empty
    | some hover => {{
      <div class="bp_code_hover" role="tooltip">
        <div class="bp_code_hover_title">{{.text true s!"{hover.label}"}}</div>
        <div class="bp_code_hover_section">
          <span class="bp_code_hover_label">"Lean definitions"</span>
          <ul class="bp_code_hover_list">
            {{codeHoverDeclItems hover.definedDefs}}
          </ul>
        </div>
        <div class="bp_code_hover_section">
          <span class="bp_code_hover_label">"Lean theorems/lemmas"</span>
          <ul class="bp_code_hover_list">
            {{codeHoverDeclItems hover.definedTheorems}}
          </ul>
        </div>
        <div class="bp_code_hover_section">
          <span class="bp_code_hover_label">"Sorries"</span>
          <ul class="bp_code_hover_list">
            {{codeHoverDeclItems hover.sorries}}
          </ul>
        </div>
      </div>
    }}
  let externalHoverListItems (items : Array ExternalHoverDecl) : Output.Html :=
    if items.isEmpty then
      {{<li class="bp_code_hover_none">"none"</li>}}
    else
      .seq <| items.map fun item =>
        let statusTxt := externalDeclHoverStatusText item
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
  let externalPanelListItems (items : Array ExternalHoverDecl) : Output.Html :=
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
  let externalHover : Output.Html :=
    if cdata.externalDecls.isEmpty then
      .empty
    else
      {{
        <div class="bp_code_hover" role="tooltip">
          <div class="bp_code_hover_title">"External Lean references"</div>
          <div class="bp_code_hover_section">
            <ul class="bp_code_hover_list">
              {{externalHoverListItems cdata.externalDecls}}
            </ul>
          </div>
        </div>
      }}
  let manualHover : Output.Html :=
    if cdata.manualStatus then
      {{
        <div class="bp_code_hover" role="tooltip">
          <div class="bp_code_hover_title">"Lean status"</div>
          <div class="bp_code_hover_section">
            <span class="bp_code_hover_none">"Marked complete via (leanok := true)."</span>
          </div>
        </div>
      }}
    else
      .empty
  let hasExternal := !cdata.externalDecls.isEmpty
  let externalAgg := externalDeclAggregate cdata.externalDecls
  let hasInline := cdata.codeHref.isSome || cdata.codeHover.isSome
  let hasCodeEntry := hasExternal || hasInline || cdata.manualStatus
  let codeEntryHover : Output.Html :=
    if hasExternal then
      externalHover
    else if cdata.codeHover.isSome then
      codeHover
    else if cdata.manualStatus then
      manualHover
    else
      .empty
  let codeEntryTitle : String :=
    if hasExternal then
      externalCodeEntryTitle externalAgg
    else if cdata.manualStatus then
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
      {{<span class="bp_code_link_wrap">{{linkNode}}{{codeEntryHover}}</span>}}
  let externalStatusIndicator : Output.Html :=
    if !hasExternal then
      .empty
    else
      let (iconClass, iconText, iconTitle) := externalPanelStatus externalAgg
      let icon :=
        {{<span class={{s!"bp_external_status_icon {iconClass}"}} title={{iconTitle}}>{{.text true iconText}}</span>}}
      {{<span class="bp_code_hover_wrap bp_code_summary_indicator">{{icon}}{{externalHover}}</span>}}
  let externalCodePanel : Output.Html :=
    if !hasExternal || data.isProof then
      .empty
    else
      let summaryText :=
        if data.isProof then
          "External Lean declarations for proof"
        else
          s!"External Lean declarations for {data.kind} {data.count}"
      mkCodePanel summaryText codeEntryTitle externalStatusIndicator
        {{<ul class="bp_code_hover_list">{{externalPanelListItems cdata.externalDecls}}</ul>}}
  let kindText := if data.isProof then "Proof" else s!"{data.kind}"
  let labelTextNum := s!"{data.count}"
  let labelText := s!"{data.label}"
  let showLabel := !data.isProof
  let (kindCss, wrapperCss, headingCss, captionCss, labelCss, contentCss) :=
    if data.isProof then
      ("proof", "proof_wrapper bp_kind_proof",
        "proof_heading", "proof_caption", "proof_label", "proof_content")
    else
      match data.kind with
      | .definition =>
        ("definition", "definition_thmwrapper theorem-style-definition bp_kind_definition",
          "definition_thmheading", "definition_thmcaption", "definition_thmlabel", "definition_thmcontent")
      | .theorem =>
        ("theorem", "theorem_thmwrapper theorem-style-plain bp_kind_theorem",
          "theorem_thmheading", "theorem_thmcaption", "theorem_thmlabel", "theorem_thmcontent")
      | .lemma =>
        ("lemma", "lemma_thmwrapper theorem-style-plain bp_kind_lemma",
          "lemma_thmheading", "lemma_thmcaption", "lemma_thmlabel", "lemma_thmcontent")
      | .corollary =>
        ("corollary", "corollary_thmwrapper theorem-style-plain bp_kind_corollary",
          "corollary_thmheading", "corollary_thmcaption", "corollary_thmlabel", "corollary_thmcontent")
  let wrapperClass := s!"bp_wrapper {kindCss}_thmwrapper {wrapperCss}"
  let headingClass := s!"bp_heading {headingCss}"
  let captionClass := s!"bp_caption {captionCss}"
  let labelClass := s!"bp_label {labelCss}"
  let contentClass := s!"bp_content {contentCss}"
  let statusMark : Output.Html :=
    if hasExternal then
      let (title, mark) := externalStatusMarkMeta externalAgg
      {{ <span class="bp_status_mark" title={{title}}>{{.text true mark}}</span> }}
    else if cdata.manualStatus then
      {{ <span class="bp_status_mark" title="Marked complete via (leanok := true)">"✓ (manually set)"</span> }}
    else if cdata.codeHref.isNone then
      .empty
    else
      let (hasSorriesHere, whereTxt) :=
        if data.isProof then
          (cdata.hasProofSorries, "proof")
        else
          (cdata.hasStatementSorries, "statement")
      let mark := if hasSorriesHere then "✗" else "✓"
      let title := if hasSorriesHere then s!"Contains sorries in {whereTxt}" else s!"No sorries in {whereTxt}"
      {{ <span class="bp_status_mark" title={{title}}>{{.text true mark}}</span> }}
  let informalBlock : Output.Html := {{
    <div class={{wrapperClass}} title={{labelText}} {{attrs}}>
      <div class={{headingClass}}>
        <span class={{captionClass}} title={{labelText}}> {{.text true kindText}} </span>
        {{ if showLabel then {{<span class={{labelClass}}> {{.text true labelTextNum}} </span>}} else .empty }}
        <div class="bp_extras thm_header_extras">
          {{statusMark}}
          {{codeEntry}}
        </div>
        <div class="bp_hiddenextras thm_header_hidden_extras"> </div>
      </div>
      <div class={{contentClass}}> {{ content }} </div>
    </div>
  }}
  .seq #[informalBlock, externalCodePanel]

end Informal
