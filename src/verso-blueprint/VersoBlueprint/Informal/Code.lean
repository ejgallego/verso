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

namespace Informal

open Verso Doc Elab
open Lean Elab

deriving instance Lean.ToJson for Lean.DeclarationRange
deriving instance Lean.FromJson for Lean.DeclarationRange
deriving instance Lean.Quote for Lean.DeclarationRange

inductive ExternalDeclProvenance where
  | inWorkspace (moduleName : Name) (sourcePath : String)
  | outWorkspace (moduleName : Name) (sourcePath? : Option String := none)
  | unknown
deriving Repr, Inhabited, FromJson, ToJson, Quote

def ExternalDeclProvenance.moduleName? : ExternalDeclProvenance → Option Name
  | .inWorkspace moduleName _ => some moduleName
  | .outWorkspace moduleName _ => some moduleName
  | .unknown => none

def ExternalDeclProvenance.sourcePath? : ExternalDeclProvenance → Option String
  | .inWorkspace _ sourcePath => some sourcePath
  | .outWorkspace _ sourcePath? => sourcePath?
  | .unknown => none

def ExternalDeclProvenance.label : ExternalDeclProvenance → String
  | .inWorkspace _ _ => "in workspace"
  | .outWorkspace _ _ => "out workspace"
  | .unknown => "unknown provenance"

inductive ExternalDeclLookupError where
  | notPresentAtRegistration
  | notFoundInEnvironment
deriving Repr, Inhabited, FromJson, ToJson, Quote

def ExternalDeclLookupError.message : ExternalDeclLookupError → String
  | .notPresentAtRegistration => "name was not present during directive/code-block registration"
  | .notFoundInEnvironment => "name is not present in current environment"

instance : ToJson (Except String String) where
  toJson
    | .ok html => Json.mkObj [("ok", toJson html)]
    | .error message => Json.mkObj [("error", toJson message)]

instance : FromJson (Except String String) where
  fromJson?
    | .obj obj =>
      match obj.get? "ok", obj.get? "error" with
      | some ok, none => return .ok (← fromJson? ok)
      | none, some err => return .error (← fromJson? err)
      | _, _ => throw "expected object with exactly one of fields 'ok' or 'error'"
    | _ => throw "expected object"

instance : Lean.Quote (Except String String) where
  quote
    | .ok html => Syntax.mkApp (mkCIdent ``Except.ok) #[(Lean.quote html)]
    | .error message => Syntax.mkApp (mkCIdent ``Except.error) #[(Lean.quote message)]

def renderErrorMessage? : Except String String → Option String
  | .ok _ => none
  | .error message => some message

/-- Resolved metadata for external declarations plus docgen render outcome. -/
structure ExternalDeclInfo where
  /-- Name as written in `(lean := "...")` (non-canonical display form). -/
  decl : Name
  /-- Canonical resolved name used for environment/source lookup. -/
  canonical : Name
  /-- Provenance badge and optional source-path metadata. -/
  provenance : ExternalDeclProvenance := .unknown
  /-- Full declaration range; fallback location text when no selection range exists. -/
  range? : Option Lean.DeclarationRange := none
  /-- Preferred range for location/source-link text (typically the declaration head). -/
  selectionRange? : Option Lean.DeclarationRange := none
  /-- Human-readable declaration kind (`definition`, `theorem`, `axiom`, ...). -/
  kind : String
  /-- Optional source URL generated from `verso.blueprint.externalCode.sourceLinkTemplate`. -/
  sourceHref? : Option String := none
  /-- Incompleteness metadata used by status colors/badges/tooltips. -/
  provedStatus : Data.ProvedStatus := .proved
  /-- DocGen render result for this declaration (`.ok html` or `.error message`). -/
  render : Except String String
deriving Repr, Inhabited, FromJson, ToJson, Quote

/--
Result for one external declaration reference:
- `missing`: declaration name is unresolved in the current environment.
- `info`: declaration resolves and carries typed metadata/render outcome.
-/
inductive ExternalDecl where
  | missing (decl : Name) (error : ExternalDeclLookupError := .notFoundInEnvironment)
  | info (info : ExternalDeclInfo)
deriving Repr, Inhabited, FromJson, ToJson, Quote

def ExternalDecl.displayName : ExternalDecl → Name
  | .missing decl _ => decl
  | .info declInfo => declInfo.decl

def ExternalDecl.canonical? : ExternalDecl → Option Name
  | .missing _ _ => none
  | .info declInfo => some declInfo.canonical

def ExternalDecl.info? : ExternalDecl → Option ExternalDeclInfo
  | .missing _ _ => none
  | .info declInfo => some declInfo

inductive BlockCodeStatus where
  | none
  | userOk
  | external (decls : Array ExternalDecl)
deriving Repr, Inhabited, FromJson, ToJson, Quote

structure BlockData where
  kind : Data.NodeKind
  label : Data.Label
  count : Nat
  isProof : Bool := false
  codeStatus : BlockCodeStatus := .none
deriving FromJson, ToJson, Quote

structure CodeDeclData where
  name : Name
  commandIndex : Nat := 0
  weight : Nat := 1
  provedStatus : Data.ProvedStatus := .proved
deriving FromJson, ToJson, Quote

def CodeDeclData.ofLiterateDef (d : Data.LiterateDef) : CodeDeclData :=
  {
    name := d.name
    commandIndex := d.commandIndex
    weight := max d.commandLines 1
    provedStatus := d.provedStatus
  }

def CodeDeclData.ofLiterateThm (d : Data.LiterateThm) : CodeDeclData :=
  {
    name := d.name
    commandIndex := d.commandIndex
    weight := max d.commandLines 1
    provedStatus := d.provedStatus
  }

structure CodeBlockData where
  label : Data.Label
  definedDefs : Array CodeDeclData := #[]
  definedTheorems : Array CodeDeclData := #[]
  foldProofs : Bool := true
deriving FromJson, ToJson, Quote

register_option verso.blueprint.foldProofs : Bool := {
  defValue := true
  descr := "Enable proof folding in VersoBlueprint Lean code blocks (hide text after `by` behind a toggle)"
}

structure CodeHoverDecl where
  text : String
  href : Option String := none

structure CodeHoverData where
  label : Data.Label
  definedDefs : Array CodeHoverDecl := #[]
  definedTheorems : Array CodeHoverDecl := #[]
  sorries : Array CodeHoverDecl := #[]

/--
View model used by `Block.informal.toHtml` for one external Lean declaration.
This extends resolved external declaration data with optional in-site links.
-/
structure ExternalHoverDecl where
  decl : ExternalDecl
  /-- Optional link to local docs/example declaration pages. -/
  href : Option String := none

/-- Build hover/render data from status facts and an optional in-site declaration link. -/
def ExternalHoverDecl.ofDecl (decl : ExternalDecl) (href : Option String := none) : ExternalHoverDecl :=
  {
    decl
    href
  }

structure ComputedData where
  proved : Bool := false
  codeHref : Option String := none
  codeHover : Option CodeHoverData := none
  manualStatus : Bool := false
  externalDecls : Array ExternalHoverDecl := #[]
  hasStatementSorries : Bool := false
  hasProofSorries : Bool := false

def provedStatusHasSorry (status : Data.ProvedStatus) : Bool :=
  status.isIncomplete

def provedStatusLocationText (status : Data.ProvedStatus) : String :=
  match status with
  | .axiomLike => "axiom-like (no body)"
  | .containsSorry info =>
    let hasType := info.any (·.location == .statement)
    let hasProof := info.any (·.location == .proof)
    if hasType && hasProof then
      "in statement and proof"
    else if hasType then
      "in statement"
    else if hasProof then
      "in proof"
    else
      "location unknown"
  | .proved => "location unknown"

def provedStatusContainsSorry (status : Data.ProvedStatus) : Bool :=
  match status with
  | .containsSorry _ => true
  | _ => false

def mkCodeHoverData
    (label : Data.Label)
    (definedDefs definedTheorems : Array CodeDeclData)
    (hrefOf : Name → Option String) : CodeHoverData :=
  let toDecl (d : CodeDeclData) : CodeHoverDecl :=
    { text := toString d.name, href := hrefOf d.name }
  let toSorry (d : CodeDeclData) : CodeHoverDecl :=
    let kind :=
      match d.provedStatus with
      | .axiomLike => "axiom-like (no body)"
      | .containsSorry _ => provedStatusLocationText d.provedStatus
      | .proved => "unknown"
    { text := s!"{d.name} [{kind}]", href := hrefOf d.name }
  {
    label
    definedDefs := definedDefs.map toDecl
    definedTheorems := definedTheorems.map toDecl
    sorries := (definedDefs ++ definedTheorems).filter (provedStatusHasSorry ∘ (·.provedStatus)) |>.map toSorry
  }

def codeHoverText (label : Data.Label) (definedDefs definedTheorems : Array CodeDeclData) : String :=
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
    let sorryDecls := (definedDefs ++ definedTheorems).filter (provedStatusHasSorry ∘ (·.provedStatus))
    let sorries :=
      if sorryDecls.isEmpty then
        "none"
      else
        String.intercalate ", " <| sorryDecls.toList.map fun d =>
          let kind :=
            match d.provedStatus with
            | .axiomLike => "axiom-like (no body)"
            | .containsSorry _ => provedStatusLocationText d.provedStatus
            | .proved => "unknown"
          s!"{d.name} [{kind}]"
    s!"{label}\nLean definitions: {defs}\nLean theorems/lemmas: {thms}\nSorries: {sorries}"

def sortDeclsByCommand (decls : Array CodeDeclData) : Array CodeDeclData :=
  decls.qsort (fun a b =>
    a.commandIndex < b.commandIndex ||
    (a.commandIndex == b.commandIndex && a.name.toString < b.name.toString))

def codeDeclSorryLocation (decl : CodeDeclData) : String :=
  provedStatusLocationText decl.provedStatus

private def externalDeclHasSorry (decl : ExternalHoverDecl) : Bool :=
  match decl.decl.info? with
  | some info => provedStatusHasSorry info.provedStatus
  | none => false

private def externalDeclSorryLocation (decl : ExternalHoverDecl) : String :=
  match decl.decl.info? with
  | some info => provedStatusLocationText info.provedStatus
  | none => "location unknown"

private def externalDeclRenderError? (decl : ExternalHoverDecl) : Option String :=
  match decl.decl.info? with
  | some info => renderErrorMessage? info.render
  | none => none

private def externalDeclLookupError? (decl : ExternalHoverDecl) : Option ExternalDeclLookupError :=
  match decl.decl with
  | .missing _ error => some error
  | .info _ => none

private structure ExternalDeclAggregate where
  total : Nat
  found : Nat
  missing : Nat
  renderErrors : Nat
  withGaps : Nat

private def externalDeclAggregate (decls : Array ExternalHoverDecl) : ExternalDeclAggregate :=
  let total := decls.size
  let found := decls.foldl (init := 0) fun acc decl =>
    let isFound :=
      match decl.decl with
      | .info _ => true
      | .missing _ _ => false
    acc + (if isFound then 1 else 0)
  let missing := decls.foldl (init := 0) fun acc decl =>
    let isMissing :=
      match decl.decl with
      | .missing _ _ => true
      | .info _ => false
    acc + (if isMissing then 1 else 0)
  let renderErrors := decls.foldl (init := 0) fun acc decl =>
    acc + (if (externalDeclRenderError? decl).isSome then 1 else 0)
  let withGaps := decls.foldl (init := 0) fun acc decl => acc + (if externalDeclHasSorry decl then 1 else 0)
  {
    total
    found
    missing
    renderErrors
    withGaps
  }

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
  match item.decl with
  | .missing _ _ => "bp_external_decl_missing"
  | .info info =>
    if (renderErrorMessage? info.render).isSome then
      "bp_external_decl_error"
    else if externalDeclHasSorry item then
      "bp_external_decl_sorry"
    else
      "bp_external_decl_ok"

private def externalDeclHoverStatusText (item : ExternalHoverDecl) : String :=
  if let some err := externalDeclRenderError? item then
    s!"(has Lean declaration; docgen render failed: {err})"
  else
    match item.decl with
    | .info _ =>
      if externalDeclHasSorry item then
        if let some info := item.decl.info? then
          if provedStatusContainsSorry info.provedStatus then
            s!"(has Lean declaration; contains sorry {externalDeclSorryLocation item})"
          else
            s!"(has Lean declaration; {externalDeclSorryLocation item})"
        else
          s!"(has Lean declaration; contains sorry {externalDeclSorryLocation item})"
      else
        "(has Lean declaration)"
    | .missing _ _ =>
      "(missing Lean declaration)"

private def externalDeclPanelStatusText (item : ExternalHoverDecl) : String :=
  if (externalDeclRenderError? item).isSome then
    "docgen render failed"
  else
    match item.decl with
    | .info _ =>
      if externalDeclHasSorry item then
        if let some info := item.decl.info? then
          if provedStatusContainsSorry info.provedStatus then
            s!"contains sorry {externalDeclSorryLocation item}"
          else
            externalDeclSorryLocation item
        else
          s!"contains sorry {externalDeclSorryLocation item}"
      else
        "complete"
    | .missing _ _ =>
      "missing declaration"

private def externalDeclSorryInfo? (item : ExternalHoverDecl) : Option String :=
  match item.decl.info? with
  | none => none
  | some info =>
    if externalDeclHasSorry item then
      if provedStatusContainsSorry info.provedStatus then
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
  let declTxt := {{<code>{{.text true s!"{item.decl.displayName}"}}</code>}}
  if let some href := item.href then
    {{<a href={{href}}>{{declTxt}}</a>}}
  else
    declTxt

private def externalDeclSourceInfo? (item : ExternalHoverDecl) : Option String :=
  match item.decl.info? with
  | none => none
  | some info =>
    match info.provenance.moduleName?,
      (info.selectionRange?.map sourceRangeText <|> info.range?.map sourceRangeText) with
    | some moduleName, some rangeTxt => some s!"{moduleName} @ {rangeTxt}"
    | some moduleName, none => some s!"{moduleName}"
    | none, some rangeTxt => some s!"{rangeTxt}"
    | none, none => none

private def externalDeclSourceRef? (item : ExternalHoverDecl) : Option Output.Html :=
  open Verso.Output.Html in
  (item.decl.info?.bind (·.sourceHref?)).map fun href =>
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

def progressSegmentClass (missing hasSorry : Bool) : String :=
  if missing then
    "bp_code_progress_segment bp_code_progress_segment_missing"
  else if hasSorry then
    "bp_code_progress_segment bp_code_progress_segment_sorry"
  else
    "bp_code_progress_segment bp_code_progress_segment_ok"

def codePanelSummary (data : BlockData) : String :=
  if data.isProof then
    "Code for proof"
  else
    s!"Code for {data.kind} {data.count}"

def mkCodePanel
    (summaryText summaryTitle : String)
    (progressBar body : Output.Html)
    (attrs : Array (String × String) := #[]) : Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_wrapper bp_code_panel_wrapper">
      <details class="bp_code_block bp_code_panel" {{attrs}}>
        <summary title={{summaryTitle}}>
          <span class="bp_code_summary_text">{{.text true summaryText}}</span>
          {{progressBar}}
          <span class="bp_code_expand_hint"></span>
        </summary>
        {{body}}
      </details>
    </div>
  }}

def codeHoverDeclItems (items : Array CodeHoverDecl) : Output.Html :=
  open Verso.Output.Html in
  if items.isEmpty then
    {{<li class="bp_code_hover_none">"none"</li>}}
  else
    .seq <| items.map fun item =>
      let txt := {{<code>{{.text true item.text}}</code>}}
      {{<li>{{if let some href := item.href then {{<a href={{href}}>{{txt}}</a>}} else txt}}</li>}}

def toHtml (data : BlockData) (cdata : ComputedData) (_domain : Json) (attrs : Array (String × String))
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
        let info? := item.decl.info?
        let hasProvenanceDetails : Bool :=
          match info? with
          | none => false
          | some info =>
            match info.provenance with
            | .unknown => false
            | _ => true
        let headTail : Output.Html :=
          if hasProvenanceDetails then
            {{<span class="bp_external_badge">{{.text true ((info?.map (·.provenance.label)).getD "")}}</span>}}
          else
            .empty
        let sourcePath? := info?.bind (·.provenance.sourcePath?)
        let sourceInfo? := externalDeclSourceInfo? item
        let sorryInfo? := externalDeclSorryInfo? item
        let renderError? := externalDeclRenderError? item
        let lookupError? := (externalDeclLookupError? item).map ExternalDeclLookupError.message
        let body : Output.Html := {{
          {{if let some kind := info?.map (·.kind) then {{<div class="bp_external_decl_meta">"kind: " <code>{{.text true kind}}</code></div>}} else .empty}}
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
        match item.decl with
        | .info info =>
          match info.render with
          | .ok renderedHtml =>
            {{
              <li class="bp_external_decl_item bp_external_decl_item_rendered">
                <div class="bp_external_decl_rendered">{{.text false renderedHtml}}</div>
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
              <pre class="bp_external_decl_stmt bp_external_decl_render_error">{{.text true s!"DocGen render failed: {err}"}}</pre>
            }}
            externalDeclItem item statusTxt body
        | .missing _ lookupError =>
          let body : Output.Html := {{
            <pre class="bp_external_decl_stmt bp_code_hover_none">{{.text true s!"declaration not found ({lookupError.message})"}}</pre>
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
