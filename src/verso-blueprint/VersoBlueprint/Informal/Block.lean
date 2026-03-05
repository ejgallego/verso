/-
Copyright (c) 2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias, David Thrane Christiansen
-/

-- XXX VersoManual is not module yet
-- module

-- Blueprint library extending the Verso `Manual` genre.

import Lean.Elab.InfoTree.Types

import VersoManual

import VersoBlueprint.Commands.Common
import VersoBlueprint.Data
import VersoBlueprint.Environment
import VersoBlueprint.Informal.CodeCommon
import VersoBlueprint.Informal.CodeSummary
import VersoBlueprint.Informal.ExternalCode
import VersoBlueprint.LabelNameParsing
import VersoBlueprint.PreviewCache
import VersoBlueprint.Resolve
import VersoBlueprint.StyleSwitcher
import VersoBlueprint.Widget
import VersoBlueprint.Profiling

set_option doc.verso true

open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse
open Lean.Doc.Syntax
open Lean Elab

namespace Informal
open CodeSummary

/- "Informal" Verso objects:

  - An informal verso object is identified by a label, and lives in the `informal` Verso domain.
  - For IO (Informal Object), we associate a `Data` entry, which mainly captures other objects the IO depends on
  - Objects are declared via directives / code blocks
  - Dependencies are declared via the {uses ...}`...` role, which _must_ be inside a directive.

Elaboration, traversal, and rendering are standard, using {ref VersoManual} helpers for custom blocks and inlines.

-/

/-- Domain for informal-like objects; each informal object is
  characterized by its canonical name declared by the user. -/
def informalDomain : Name := Resolve.informalDomainName

/-- Name used in {name}`TraverseState.domains` for informal Lean code blocks. -/
def informalCodeDomain : Name := Resolve.informalCodeDomainName

/-- Name used in {name}`TraverseState.domains` for informal preview payloads. -/
def informalPreviewDomain : Name := Resolve.informalPreviewDomainName

/-- Name used in {name}`TraverseState.domains` for rendered external declaration anchors. -/
def informalExternalDeclDomain : Name := Resolve.externalRenderedDeclDomainName

/-- Configuration for directives / code-blocks. Q: should we allow non-labelled informal objects? -/
structure Config where
  label : Data.Label
  labelSyntax : Syntax := Syntax.missing
  lean : Option String := none
  leanok : Option Bool := none
  parent : Option Data.Parent := none
  externalCode : Array Data.ExternalRef := #[]
  invalidExternalCode : Array String := #[]
--  hide : Bool := false

section
variable [Monad m] [MonadInfoTree m] [MonadLiftT CoreM m] [MonadEnv m] [MonadError m] [MonadFileMap m]

def Config.parse  : ArgParse m Config :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) lean leanok parent =>
    let (externalCode, invalidExternalCode) := ExternalCode.parseExternalCodeList lean
    {
      label := LabelNameParsing.parse labelArg.val
      labelSyntax := labelArg.syntax
      lean := lean
      leanok := leanok
      parent := parent.map LabelNameParsing.parse
      externalCode := externalCode
      invalidExternalCode := invalidExternalCode
    }) <$> .positional `label (.withSyntax .string) <*> .named `lean .string true
        <*> .named `leanok .bool true <*> .named `parent .string true

instance : FromArgs Config m where
  fromArgs := Config.parse

end

def blueprintCss : String := r##"
.bp_wrapper {
  scroll-margin-top: 1rem;
  margin: 0.85rem 0;
}

.bp_heading {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  font-style: normal;
  font-weight: bold;
}

.bp_caption {
  display: inline;
}

.bp_label {
  margin-left: 0.5rem;
}

span[class$="_thmlabel"]::after {
  content: ".";
}

.bp_extras {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  margin-left: auto;
}

.bp_code_link {
  display: inline;
  font-size: 0.8rem;
  color: inherit;
  text-decoration: none;
}

.bp_code_hover_wrap,
.bp_code_link_wrap {
  position: relative;
  display: inline-flex;
  align-items: center;
  padding-bottom: 0.45rem;
  margin-bottom: -0.45rem;
}

.bp_code_hover_wrap::after,
.bp_code_link_wrap::after {
  content: "";
  position: absolute;
  left: -0.25rem;
  right: -0.25rem;
  top: 100%;
  height: 0.45rem;
}

.bp_code_hover {
  position: absolute;
  left: 50%;
  top: 100%;
  transform: translateX(-50%);
  min-width: 20rem;
  max-width: min(34rem, 75vw);
  z-index: 20;
  border: 1px solid #cbd5e1;
  border-radius: 0.45rem;
  padding: 0.45rem 0.55rem;
  background: #ffffff;
  box-shadow: 0 8px 20px rgba(15, 23, 42, 0.15);
  display: none;
  font-size: 0.78rem;
  font-style: normal;
  font-weight: 400;
}

.bp_code_hover_wrap:is(:hover, :focus-within) > .bp_code_hover,
.bp_code_link_wrap:is(:hover, :focus-within) > .bp_code_hover {
  display: block;
}

.bp_code_hover_title {
  font-weight: 700;
  margin-bottom: 0.3rem;
}

.bp_code_block summary {
  display: flex;
  align-items: center;
  gap: 0.55rem;
}

.bp_code_summary_text {
  white-space: nowrap;
}

.bp_code_summary_indicator {
  margin-left: auto;
  display: inline-flex;
  align-items: center;
}

.bp_code_progress {
  display: inline-flex;
  min-width: 9rem;
  max-width: 24rem;
  width: min(24rem, 40vw);
  height: 0.64rem;
  border-radius: 999px;
  overflow: hidden;
  border: 1px solid #94a3b8;
  background: linear-gradient(180deg, #f8fafc, #e2e8f0);
  box-shadow: inset 0 1px 1px rgba(15, 23, 42, 0.08);
}

.bp_code_progress_segment {
  min-width: 0.22rem;
}

.bp_code_progress_segment + .bp_code_progress_segment {
  border-left: 1px solid rgba(15, 23, 42, 0.35);
}

.bp_code_progress_segment_ok {
  background: #16a34a;
}

.bp_code_progress_segment_sorry {
  background: #eab308;
}

.bp_code_progress_segment_missing {
  background: #dc2626;
}

.bp_external_status_icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 0.95rem;
  height: 0.95rem;
  border-radius: 999px;
  font-size: 0.68rem;
  line-height: 1;
  color: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.22);
}

.bp_external_status_ok {
  background: #16a34a;
}

.bp_external_status_sorry {
  background: #ca8a04;
}

.bp_external_status_missing {
  background: #dc2626;
}

.bp_external_status_error {
  background: #7c3aed;
}

.bp_code_expand_hint {
  color: #64748b;
  font-size: 0.74rem;
  white-space: nowrap;
}

.bp_code_expand_hint::before {
  content: "expand";
}

details[open] > summary .bp_code_expand_hint::before {
  content: "collapse";
}

.bp_code_panel {
  margin: 0;
}

.bp_code_panel_wrapper {
  margin-top: 0.5rem;
}

.bp_code_panel_wrapper .bp_code_block > summary {
  cursor: pointer;
}

.bp_decl_target {
  background: rgba(59, 130, 246, 0.18);
  border-radius: 0.18rem;
  box-shadow: 0 0 0 0.12rem rgba(59, 130, 246, 0.22);
  animation: bp-decl-target-pulse 1.8s ease-out;
}

.bp_decl_target_block {
  border-radius: 0.3rem;
  box-shadow: 0 0 0 0.18rem rgba(59, 130, 246, 0.2);
  background: linear-gradient(180deg, rgba(59, 130, 246, 0.08), rgba(59, 130, 246, 0.04));
  animation: bp-decl-block-pulse 2.2s ease-out;
}

@keyframes bp-decl-target-pulse {
  0% {
    background: rgba(59, 130, 246, 0.28);
    box-shadow: 0 0 0 0.2rem rgba(59, 130, 246, 0.3);
  }
  100% {
    background: rgba(59, 130, 246, 0.1);
    box-shadow: 0 0 0 0.08rem rgba(59, 130, 246, 0.16);
  }
}

@keyframes bp-decl-block-pulse {
  0% {
    background: rgba(59, 130, 246, 0.14);
    box-shadow: 0 0 0 0.28rem rgba(59, 130, 246, 0.24);
  }
  100% {
    background: rgba(59, 130, 246, 0.04);
    box-shadow: 0 0 0 0.14rem rgba(59, 130, 246, 0.16);
  }
}

.bp_code_link:hover {
  text-decoration: underline;
}

.bp_status_mark {
  font-size: 0.78rem;
  font-weight: 600;
}

.bp_external_badge {
  font-size: 0.74rem;
  font-weight: 600;
  border: 1px solid #cbd5e1;
  border-radius: 0.3rem;
  padding: 0.08rem 0.35rem;
  background: #f8fafc;
}

.bp_external_decl_ok {
  color: #166534;
}

.bp_external_decl_sorry {
  color: #a16207;
}

.bp_external_decl_missing {
  color: #b91c1c;
}

.bp_external_decl_error {
  color: #7c3aed;
}

.bp_external_decl_meta {
  margin-top: 0.12rem;
  color: #334155;
  font-size: 0.72rem;
}

.bp_external_decl_item {
  margin-top: 0.18rem;
}

.bp_external_decl_head {
  display: inline-flex;
  align-items: baseline;
  gap: 0.35rem;
  flex-wrap: wrap;
}

.bp_external_decl_details {
  margin-top: 0.12rem;
}

.bp_external_decl_details summary {
  cursor: pointer;
  font-size: 0.72rem;
  color: #334155;
}

.bp_external_decl_preview {
  margin-top: 0.2rem;
  border-left: 2px solid #e2e8f0;
  padding-left: 0.45rem;
}

.bp_external_decl_preview summary {
  cursor: pointer;
  font-size: 0.72rem;
  color: #1e293b;
}

.bp_external_decl_preview pre {
  margin: 0.2rem 0 0;
  max-height: 8.5rem;
  overflow: auto;
  white-space: pre-wrap;
  font-size: 0.7rem;
  line-height: 1.35;
}

.bp_external_decl_stmt {
  margin: 0.22rem 0 0;
  padding: 0.36rem 0.5rem;
  border-left: 2px solid #cbd5e1;
  background: #f8fafc;
  white-space: pre-wrap;
  font-size: 0.74rem;
  line-height: 1.35;
  color: #0f172a;
}

.bp_external_decl_rendered {
  margin: 0.22rem 0 0;
  border: 0;
  background: transparent;
  padding: 0;
  overflow-x: auto;
}

.bp_external_decl_rendered .declaration {
  margin: 0;
  padding: 0;
}

.bp_external_decl_rendered .decl {
  padding-left: 8px;
  padding-right: 8px;
}

.bp_external_decl_rendered .decl.def,
.bp_external_decl_rendered .decl.instance {
  border-left: 10px solid var(--text-color, #0f172a);
  border-top: 2px solid var(--text-color, #0f172a);
}

.bp_external_decl_rendered .decl.theorem {
  border-left: 10px solid var(--theorem-color, #8fe388);
  border-top: 2px solid var(--theorem-color, #8fe388);
}

.bp_external_decl_rendered .decl.axiom,
.bp_external_decl_rendered .decl.opaque {
  border-left: 10px solid var(--axiom-and-constant-color, #f44708);
  border-top: 2px solid var(--axiom-and-constant-color, #f44708);
}

.bp_external_decl_rendered .decl.structure,
.bp_external_decl_rendered .decl.inductive,
.bp_external_decl_rendered .decl.class {
  border-left: 10px solid var(--structure-and-inductive-color, #f0a202);
  border-top: 2px solid var(--structure-and-inductive-color, #f0a202);
}

.bp_external_decl_item_rendered .bp_external_decl_head {
  display: none;
}

.bp_external_decl_rendered .decl_kind,
.bp_external_decl_rendered .decl_name,
.bp_external_decl_rendered .decl_extends {
  font-weight: bold;
}

.bp_external_decl_rendered .decl_header {
  text-indent: -8ex;
  padding-left: 8ex;
  line-height: 1.45;
}

.bp_external_decl_rendered .decl_name {
  overflow-wrap: break-word;
}

.bp_external_decl_rendered .decl_name::after {
  content: "\A";
  white-space: pre;
}

.bp_external_decl_rendered .decl_type {
  margin-top: 2px;
  margin-left: 4ex;
}

.bp_external_decl_rendered .decl_args,
.bp_external_decl_rendered .decl_type .decl_parent {
  font-weight: normal;
}

.bp_external_decl_rendered .implicits,
.bp_external_decl_rendered .impl_arg {
  color: inherit;
  white-space: normal;
}

.bp_external_decl_rendered .decl_type code {
  margin-top: 0;
}

.bp_external_decl_rendered .decl_header,
.bp_external_decl_rendered .attributes,
.bp_external_decl_rendered .equation,
.bp_external_decl_rendered .constructor,
.bp_external_decl_rendered .structure_field_info,
.bp_external_decl_rendered .structure_ext_ctor,
.bp_external_decl_rendered code {
  font-size: 92%;
  font-family: "JuliaMono", var(--verso-code-font-family, ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace);
}

.bp_external_decl_rendered code,
.bp_external_decl_rendered pre {
  background: var(--code-bg, #f3f3f3);
  border-radius: 5px;
}

.bp_external_decl_rendered code {
  padding: 1px 3px;
  font-variant-ligatures: none;
  white-space: break-spaces;
}

.bp_external_decl_rendered pre {
  padding: 1ex;
  white-space: break-spaces;
}

.bp_external_decl_rendered pre code {
  padding: 0;
}

.bp_external_decl_rendered .docstring {
  margin-top: 0.45rem;
  padding: 0;
  border: 0;
  background: transparent;
  color: inherit;
  font-family: var(--verso-text-font-family, inherit);
  font-size: 0.95em;
  line-height: 1.5;
  white-space: pre-wrap;
  overflow: visible;
  max-height: none;
}

.bp_external_decl_rendered details {
  margin-top: 0.55rem;
}

.bp_external_decl_rendered details > summary {
  cursor: pointer;
  font-size: 92%;
  font-family: "JuliaMono", var(--verso-code-font-family, ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace);
}

.bp_external_decl_rendered details > ul {
  display: block;
  padding-inline-start: 0;
  margin-top: 0.45rem;
  text-indent: -2ex;
  padding-left: 2ex;
}

.bp_external_decl_rendered details > ul > li {
  display: block;
  margin-left: 2ex;
  overflow-wrap: anywhere;
  font-size: 92%;
  font-family: "JuliaMono", var(--verso-code-font-family, ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace);
}

.bp_external_decl_rendered details.constructors > ul > li::before {
  content: "| ";
  color: #6b7280;
}

.bp_external_decl_rendered_meta {
  margin-top: 0.24rem;
  display: inline-flex;
  align-items: center;
  gap: 0.6rem;
  flex-wrap: wrap;
  font-size: 0.72rem;
}

.bp_external_decl_rendered_source .bp_code_link {
  font-size: 0.72rem;
}

.bp_content {
  padding-left: 0.65rem;
}

.bp_content > :first-child {
  margin-top: 0;
}

.bp_content > :last-child {
  margin-bottom: 0;
}

.bp-proof-tail-hidden {
  display: none;
}

.bp-proof-gap-hidden {
  display: none;
}

.bp-proof-by-toggle {
  cursor: pointer;
  text-decoration: underline dotted;
  text-decoration-thickness: 1px;
}

.bp-proof-by-toggle::after {
  content: " ...";
  color: #64748b;
}

.bp-proof-by-toggle.bp-proof-open::after {
  content: "";
}

div.theorem-style-plain div[class$="_thmheading"] {
  font-style: normal;
  font-weight: bold;
}

div.theorem-style-plain div[class$="_thmcontent"] {
  font-style: italic;
  font-weight: normal;
}

div.theorem-style-definition div[class$="_thmheading"] {
  font-style: normal;
  font-weight: bold;
}

div.theorem_thmcontent {
  border-left: 0.15rem solid black;
}

div.proposition_thmcontent {
  border-left: 0.15rem solid black;
}

div.lemma_thmcontent {
  border-left: 0.1rem solid black;
}

div.corollary_thmcontent {
  border-left: 0.1rem solid black;
}

div.proof_content {
  border-left: 0.08rem solid grey;
}

.bp_wrapper:target {
  animation: bp-target-pulse 1.6s ease-out;
  box-shadow: 0 0 0 0.18rem rgba(37, 99, 235, 0.22);
  border-radius: 0.35rem;
}

@keyframes bp-target-pulse {
  0% {
    background-color: rgba(37, 99, 235, 0.14);
    box-shadow: 0 0 0 0.28rem rgba(37, 99, 235, 0.28);
  }
  100% {
    background-color: transparent;
    box-shadow: 0 0 0 0.18rem rgba(37, 99, 235, 0.22);
  }
}
"##

def blueprintStyleSwitcherCss : String := StyleSwitcher.css

def blueprintStyleSwitcherJs : String := StyleSwitcher.jsInteractive

def shouldWritePreviewDataByIds [BEq α] (existingIds : Array α) (currentId : α) : Bool :=
  existingIds.isEmpty || existingIds.contains currentId

private def shouldWritePreviewData (existing? : Option Verso.Multi.Object) (id : Verso.Multi.InternalId) : Bool :=
  shouldWritePreviewDataByIds ((existing?.map (·.ids.toArray)).getD #[]) id

private def renderInformalBlock (data : BlockData) (attrs : Array (String × String))
    (statusMark : Option BlockStatusMark) (codeEntry : Output.Html) (content : Array Output.Html) : Output.Html :=
  open Verso.Output.Html in
  let labelTextNum := s!"{data.count}"
  let labelText := s!"{data.label}"
  let (kindText, showLabel, kindCss, wrapperCss, headingCss, captionCss, labelCss, contentCss) :=
    match data.kind with
    | .proof =>
      ("Proof", false, "proof", "proof_wrapper bp_kind_proof",
        "proof_heading", "proof_caption", "proof_label", "proof_content")
    | .statement nodeKind =>
      match nodeKind with
      | .definition =>
        (s!"{nodeKind}", true, "definition",
          "definition_thmwrapper theorem-style-definition bp_kind_definition",
          "definition_thmheading", "definition_thmcaption", "definition_thmlabel", "definition_thmcontent")
      | .theorem =>
        (s!"{nodeKind}", true, "theorem",
          "theorem_thmwrapper theorem-style-plain bp_kind_theorem",
          "theorem_thmheading", "theorem_thmcaption", "theorem_thmlabel", "theorem_thmcontent")
      | .lemma =>
        (s!"{nodeKind}", true, "lemma",
          "lemma_thmwrapper theorem-style-plain bp_kind_lemma",
          "lemma_thmheading", "lemma_thmcaption", "lemma_thmlabel", "lemma_thmcontent")
      | .corollary =>
        (s!"{nodeKind}", true, "corollary",
          "corollary_thmwrapper theorem-style-plain bp_kind_corollary",
          "corollary_thmheading", "corollary_thmcaption", "corollary_thmlabel", "corollary_thmcontent")
  let wrapperClass := s!"bp_wrapper {kindCss}_thmwrapper {wrapperCss}"
  let headingClass := s!"bp_heading {headingCss}"
  let captionClass := s!"bp_caption {captionCss}"
  let labelClass := s!"bp_label {labelCss}"
  let contentClass := s!"bp_content {contentCss}"
  {{
    <div class={{wrapperClass}} title={{labelText}} {{attrs}}>
      <div class={{headingClass}}>
        <span class={{captionClass}} title={{labelText}}> {{.text true kindText}} </span>
        {{ if showLabel then {{<span class={{labelClass}}> {{.text true labelTextNum}} </span>}} else .empty }}
        <div class="bp_extras thm_header_extras">
          {{match statusMark with | some mark => mark.toHtml | none => .empty}}
          {{codeEntry}}
        </div>
        <div class="bp_hiddenextras thm_header_hidden_extras"> </div>
      </div>
      <div class={{contentClass}}> {{ content }} </div>
    </div>
  }}

/- Informal custom blocks -/
block_extension Block.informal (data : BlockData) where
  -- for TOC
  -- localContentItem _ _ _ := none
  data := toJson data
  traverse id data _contents := do
    -- XXX: (maybe) lift the Except into the main monad error thread
    match fromJson? (α := BlockData) data with
    | .error err =>
      logError s!"Malformed data ({err}): {data}"
      pure none
    | .ok blockData =>
      let label := blockData.label
      let previewFacet := PreviewCache.Facet.ofInProgressKind blockData.kind
      let previewKey := PreviewCache.key label previewFacet
      let previewData := toJson (PreviewCache.Entry.ofBlocks label previewFacet _contents blockData.texPrelude)
      let existingPreview? := (← get).getDomainObject? informalPreviewDomain previewKey
      if shouldWritePreviewData existingPreview? id then
        modify λ s => s.saveDomainObjectData informalPreviewDomain previewKey previewData
      if existingPreview?.isNone then
        let path ← (·.path) <$> read
        let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-preview-{previewKey}"
        modify λ s => s.saveDomainObject informalPreviewDomain previewKey id
      let externalDecls :=
        match blockData.kind, blockData.codeData with
        | .statement _, some codeData => codeData.externalDecls
        | _, _ => #[]
      for decl in externalDecls do
        let key := Resolve.externalRenderedDeclTargetKey label decl.canonical
        if ((← get).getDomainObject? informalExternalDeclDomain key).isNone then
          let declId ← Verso.Genre.Manual.freshId
          let path ← (·.path) <$> read
          let _ ← Verso.Genre.Manual.externalTag declId path
            s!"--informal-external-decl-{label}-{decl.canonical}"
          modify λ s => s.saveDomainObject informalExternalDeclDomain key declId
      if let .some _d := (← get).getDomainObject? informalDomain label.toString then
        return none
      else
        let path ← (·.path) <$> read
        let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-{label}"
        modify λ s => s.saveDomainObject informalDomain label.toString id
        modify λ s => s.saveDomainObjectData informalDomain label.toString (toJson blockData)
        return none
  toTeX := none
  extraCss := ([blueprintCss, Informal.Commands.inlinePreviewCss, blueprintStyleSwitcherCss, Verso.Genre.Manual.docstringStyle] : List String)
  extraJs := ([Informal.Commands.previewHoverUtilsJs, Informal.Commands.inlineLinkPreviewJs, blueprintStyleSwitcherJs] : List String)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB id data blocks => do
      match fromJson? (α := BlockData) data with
      | .error err =>
        HtmlT.logError s!"Malformed data ({err}): {data}"
        pure .empty
      | .ok data =>
        let s ← HtmlT.state
        let attrs := s.htmlId id
        let codeHref : Option String :=
          match s.resolveDomainObject informalCodeDomain data.label.toString with
          | .ok dest => some dest.relativeLink
          | .error _ => none
        let codeData? : Option InlineCodeData ←
          match s.getDomainObject? informalCodeDomain data.label.toString with
          | none => pure none
          | some obj =>
            match fromJson? (α := InlineCodeData) obj.data with
            | .ok cdata => pure (some cdata)
            | .error err =>
                HtmlT.logError s!"Malformed informal code data for {data.label}: {err}"
                pure none
        let codeHint? :=
          match data.kind with
          | .proof => none
          | .statement _ => data.codeData
        let codeSource := BlockCodeData.ofHintAndInline codeHint? codeData?
        let getDeclHref (decl : Name) : Option String :=
          Resolve.resolveInlineLeanDeclHref? s decl
        let getDeclAnchorAttrs (decl : Data.ExternalRef) : Array (String × String) :=
          let attrsFor (declName : Name) : Array (String × String) :=
            let key := Resolve.externalRenderedDeclTargetKey data.label declName
            match s.getDomainObject? informalExternalDeclDomain key with
            | none => #[]
            | some obj =>
              match obj.ids.toArray[0]? with
              | some targetId => s.htmlId targetId
              | none => #[]
          -- Targets are keyed by canonical declaration name; fallback to the written name keeps
          -- links stable if older cached objects were keyed before canonicalization.
          let canonicalAttrs := attrsFor decl.canonical
          if canonicalAttrs.isEmpty then attrsFor decl.written else canonicalAttrs
        let cdata := {
          codeHref
          source := codeSource
        }
        let headingParts? : Option CodeSummary.RenderParts :=
          match data.kind with
          | .statement _ => some <| CodeSummary.renderParts data cdata getDeclHref
          | .proof => none
        let externalParts? : Option ExternalCode.RenderParts :=
          match data.kind, codeSource with
          | .statement _, some (.external decls) =>
            if decls.isEmpty then
              none
            else
              some <| ExternalCode.renderParts data decls getDeclHref getDeclAnchorAttrs
          | _, _ => none
        let externalPanel := (externalParts?.map (·.externalCodePanel)).getD .empty
        let content := (← blocks.mapM goB)
        let statusMark := headingParts?.bind (·.statusMark)
        let codeEntry := (headingParts?.map (·.codeEntry)).getD .empty
        let informalBlock := renderInformalBlock data attrs statusMark codeEntry content
        return .seq #[informalBlock, externalPanel]

private def expanderImpl (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let blockRef ← getRef
    let label := cfg.label
    let envKind : Data.InProgressKind :=
      if isProof then .proof else .statement kind
    let resolvedExternalCode ← ExternalCode.resolveExternalCodeList label cfg.labelSyntax cfg.externalCode
    let hasExternalRaw := !resolvedExternalCode.isEmpty
    let hasLeanok := cfg.leanok.getD false
    if !cfg.invalidExternalCode.isEmpty then
      logWarningAt cfg.labelSyntax m!"Label {label}: ignoring malformed names in '(lean := ...)' ({String.intercalate ", " cfg.invalidExternalCode.toList})"
    if hasExternalRaw && hasLeanok then
      logErrorAt cfg.labelSyntax m!"Label {label} cannot use '(leanok := true)' together with '(lean := ...)'"
    if isProof && hasExternalRaw then
      logErrorAt cfg.labelSyntax m!"Label {label} cannot use '(lean := ...)' in a proof block"
    let hasExternal := hasExternalRaw && !isProof
    let codeHint : Option Data.CodeRef :=
      if isProof then
        none
      else if hasExternal then
        some (.external resolvedExternalCode)
      else if hasLeanok then
        some .userOk
      else
        none
    Environment.push label envKind codeHint cfg.parent
    let contents ← contents.mapM elabBlock
    if !isProof then
      -- TODO: consolidate this widget-oriented elaboration cache with the traversal preview cache
      -- once we have a phase-safe representation that can serve both pipelines.
      Environment.setStatementElab contents
    let count ← Environment.pop blockRef
    let node? ← Environment.getNode? label
    let nodeCodeRef? := node?.bind (·.code)
    let blockKind : Data.InProgressKind ←
      if isProof then
        pure .proof
      else
        let nodeKind ←
          match node? with
            | some node => pure node.kind
            | none =>
              logErrorAt cfg.labelSyntax m!"Internal error: missing node '{label}' after environment registration"
              pure kind
        pure <| .statement nodeKind
    let codeData :=
      match blockKind with
      | .proof => none
      | .statement _ => BlockCodeData.ofCodeRefHint nodeCodeRef?
    let texPrelude ← Environment.getTexPrelude
    -- Make the blueprint widget available when selecting this labeled block.
    activateForLabelDoc label blockRef
    let data : BlockData := { kind := blockKind, codeData, label, count, texPrelude }
    ``(Block.other (Block.informal $(quote data)) #[$contents,*])

private def directiveName (kind : Data.NodeKind) (isProof : Bool): String :=
  if isProof then "proof" else (toString kind).toLower

private def expander (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let label := (directiveName kind isProof)
    Profile.withDocElab "directive" label <|
      (expanderImpl kind isProof) cfg contents

@[directive] def «definition» := expander .definition
@[directive] def «lemma_» := expander .lemma
@[directive] def «theorem» := expander .theorem
@[directive] def «corollary» := expander .corollary
@[directive] def «proof» := expander .lemma (isProof := true)

end Informal
