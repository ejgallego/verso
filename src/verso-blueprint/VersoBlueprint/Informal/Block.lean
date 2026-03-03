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

import VersoBlueprint.Data
import VersoBlueprint.ExternalRefSnapshot
import VersoBlueprint.Environment
import VersoBlueprint.Attribute
import VersoBlueprint.Cite
import VersoBlueprint.Commands.Graph
import VersoBlueprint.Commands.Summary
import VersoBlueprint.Commands.Bibliography
import VersoBlueprint.Informal.Code
import VersoBlueprint.DocGenNameRender
import VersoBlueprint.Lean
import VersoBlueprint.NameParsing
import VersoBlueprint.PreviewCache
import VersoBlueprint.Resolve
import VersoBlueprint.StyleSwitcher
import VersoBlueprint.TexPrelude
import VersoBlueprint.Widget
import VersoBlueprint.Profiling

set_option doc.verso true

open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse
open Lean.Doc.Syntax
open Lean Elab

namespace Informal

/- "Informal" Verso objects:

  - An informal verso object is identified by a label, and lives in the `informal` Verso domain.
  - For IO (Informal Object), we associate a `Data` entry, which mainly captures other objects the IO depends on
  - Objects are declared via directives / code blocks
  - Dependencies are declared via the {uses ...}`...` role, which _must_ be inside a directive.

Elaboration, traversal, and rendering are standard, using {ref VersoManual} helpers for custom blocks and inlines.

-/

/-- Domain for informal-like objects; each informal object is
  characterized by its canonical name declared by the user. -/
def _informal : Domain := {}

/-- Name used in {name}`TraverseState.domains` for informal objects. -/
def informalDomain : Name := Resolve.informalDomainName

/-- Name used in {name}`TraverseState.domains` for informal Lean code blocks. -/
def informalCodeDomain : Name := Resolve.informalCodeDomainName

/-- Name used in {name}`TraverseState.domains` for informal preview payloads. -/
def informalPreviewDomain : Name := Resolve.informalPreviewDomainName

/--
If enabled, unresolved or ambiguous external Lean names in `(lean := "...")` are treated as
errors instead of warnings.
-/
register_option verso.blueprint.externalCode.strictResolve : Bool := {
  defValue := false
  descr := "Treat unresolved or ambiguous `(lean := ...)` external references as errors"
}

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

private def splitExternalCodeRefs (s : String) : Array String :=
  NameParsing.splitCsvNormalized s

private def parseExternalCodeList (lean : Option String) : Array Data.ExternalRef × Array String :=
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

private def markExternalRefSnapshot [MonadOptions m] (ref : Data.ExternalRef) : m Data.ExternalRef := do
  let opts ← getOptions
  liftM <| externalRefSnapshotAtCurrentDir opts ref

private def resolveExternalNameCandidates [MonadResolveName m] [MonadOptions m]
    [MonadLog m] [AddMessageContext m]
    (name : Name) : m (Array Name) := do
  let resolved ← Lean.resolveGlobalName name (enableLog := false)
  return resolved.foldl (init := #[]) fun acc (candidate, fieldList) =>
    if fieldList.isEmpty && !acc.contains candidate then
      acc.push candidate
    else
      acc

private def resolveExternalCodeList [MonadResolveName m] [MonadOptions m] [MonadEnv m]
    [MonadLog m] [AddMessageContext m] [MonadError m]
    (label : Name) (refs : Array Data.ExternalRef) : m (Array Data.ExternalRef) := do
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
        throwError msg
      else
        logWarning m!"{msg}; keeping parsed name"
        let ref ← markExternalRefSnapshot (parsedExternalRef ref)
        return pushExternalRefDedup acc ref
    | [resolved] =>
      let ref ← markExternalRefSnapshot (resolvedExternalRef ref resolved)
      return pushExternalRefDedup acc ref
    | many =>
      let msg := m!"Label {label}: external Lean name '{ref.written}' is ambiguous ({String.intercalate ", " (many.map toString)})"
      if strictResolve then
        throwError msg
      else
        logWarning m!"{msg}; keeping parsed name"
        let ref ← markExternalRefSnapshot (parsedExternalRef ref)
        return pushExternalRefDedup acc ref

def Config.parse  : ArgParse m Config :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) lean leanok parent =>
    let (externalCode, invalidExternalCode) := parseExternalCodeList lean
    {
      label := Name.mkSimple labelArg.val
      labelSyntax := labelArg.syntax
      lean := lean
      leanok := leanok
      parent := parent.map Name.mkSimple
      externalCode := externalCode
      invalidExternalCode := invalidExternalCode
    }) <$> .positional `label (.withSyntax .string) <*> .named `lean .string true
        <*> .named `leanok .bool true <*> .named `parent .string true

instance : FromArgs Config m where
  fromArgs := Config.parse

structure GroupConfig where
  label : Data.Label
  labelSyntax : Syntax := Syntax.missing

def GroupConfig.parse : ArgParse m GroupConfig :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) =>
    {
      label := Name.mkSimple labelArg.val
      labelSyntax := labelArg.syntax
    }) <$> .positional `label (.withSyntax .string)

instance : FromArgs GroupConfig m where
  fromArgs := GroupConfig.parse

end

private def externalDeclStatus (decl : Data.ExternalRef) : ExternalDecl :=
  let canonical := decl.canonical
  if !decl.present then
    .missing decl.written .notPresentAtRegistration
  else
    let fallbackKind := if decl.isTheoremLike then "theorem" else "definition"
    let declInfo : ExternalDeclInfo := {
      decl := decl.written
      canonical
      provenance := decl.provenance
      range? := decl.range?
      selectionRange? := decl.selectionRange?
      kind := decl.kind?.getD fallbackKind
      sourceHref? := decl.sourceHref?
      provedStatus := decl.provedStatus
      render := decl.render
    }
    .info declInfo

def BlockCodeStatus.ofCodeRef (codeRef? : Option Data.CodeRef) : BlockCodeStatus :=
  match codeRef? with
  | some .userOk => .userOk
  | some (.external decls) => .external (decls.map externalDeclStatus)
  | _ => .none

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

.bp_code_hover_section {
  margin-top: 0.28rem;
}

.bp_code_hover_label {
  font-weight: 600;
  color: #334155;
}

.bp_code_hover_list {
  margin: 0.12rem 0 0;
  padding-left: 1.1rem;
}

.bp_code_hover_list code {
  font-size: 0.76rem;
}

.bp_code_hover_none {
  color: #64748b;
  font-style: italic;
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
      let previewKey := PreviewCache.keyOf label blockData.isProof
      let previewData := toJson (PreviewCache.Entry.ofBlocks label blockData.isProof _contents)
      if let .some _d := (← get).getDomainObject? informalPreviewDomain previewKey then
        modify λ s => s.saveDomainObjectData informalPreviewDomain previewKey previewData
      else
        let path ← (·.path) <$> read
        let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-preview-{previewKey}"
        modify λ s => s.saveDomainObject informalPreviewDomain previewKey id
        modify λ s => s.saveDomainObjectData informalPreviewDomain previewKey previewData
      if let .some _d := (← get).getDomainObject? informalDomain label.toString then
        return none
      else
        let path ← (·.path) <$> read
        let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-{label}"
        modify λ s => s.saveDomainObject informalDomain label.toString id
        modify λ s => s.saveDomainObjectData informalDomain label.toString (toJson blockData)
        return none
  toTeX := none
  extraCss := ([blueprintCss, blueprintStyleSwitcherCss] : List String)
  extraJs := ([blueprintStyleSwitcherJs] : List String)
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
        let dentry : Json := ((s.getDomainObject? informalDomain data.label.toString).map (·.data)).getD (.str "")
        let codeHref : Option String :=
          match s.resolveDomainObject informalCodeDomain data.label.toString with
          | .ok dest => some dest.relativeLink
          | .error _ => none
        let codeData? : Option CodeBlockData :=
          match s.getDomainObject? informalCodeDomain data.label.toString with
          | none => none
          | some obj =>
            match fromJson? (α := CodeBlockData) obj.data with
            | .ok cdata => some cdata
            | .error _ => none
        let getDeclHref (decl : Name) : Option String :=
          Resolve.resolveExampleDeclHref? s decl
        let codeHover : Option CodeHoverData := codeData?.map (fun cdata =>
          mkCodeHoverData data.label cdata.definedDefs cdata.definedTheorems getDeclHref)
        let externalDecls : Array ExternalHoverDecl :=
          match data.codeStatus with
          | .external decls =>
            decls.map fun decl =>
              let href :=
                match decl.canonical? with
                | some canonical =>
                  match getDeclHref canonical with
                  | some href => some href
                  | none => getDeclHref decl.displayName
                | none =>
                  getDeclHref decl.displayName
              ExternalHoverDecl.ofDecl decl href
          | _ => #[]
        let manualStatus : Bool :=
          match data.codeStatus with
          | .userOk => true
          | _ => false
        let hasSorries : Bool :=
          match codeData? with
          | none => false
          | some cdata => (cdata.definedDefs ++ cdata.definedTheorems).any (provedStatusHasSorry ∘ (·.provedStatus))
        let hasStatementSorries : Bool :=
          match codeData? with
          | none => false
          | some cdata =>
            (cdata.definedDefs ++ cdata.definedTheorems).any (fun decl => decl.provedStatus.hasTypeGap)
        let hasProofSorries : Bool :=
          match codeData? with
          | none => false
          | some cdata =>
            (cdata.definedDefs ++ cdata.definedTheorems).any (fun decl => decl.provedStatus.hasProofGap)
        let cdata := {
          proved := codeData?.isSome && !hasSorries
          codeHref
          codeHover
          manualStatus
          externalDecls
          hasStatementSorries
          hasProofSorries
        }
        return toHtml data cdata dentry attrs (← blocks.mapM goB)

block_extension Block.informalCode (data : CodeBlockData) where
  data := toJson data
  traverse id data _contents := do
    let .ok cdata@{ label, definedDefs := _, definedTheorems := _, foldProofs := _ } := fromJson? (α := CodeBlockData) data
      | logError s!"Malformed data: {data}"
        pure none
    if let .some _d := (← get).getDomainObject? informalCodeDomain label.toString then
      pure none
    else
      let path ← (·.path) <$> read
      let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-code-{label}"
      modify λ s => s.saveDomainObject informalCodeDomain label.toString id
      modify λ s => s.saveDomainObjectData informalCodeDomain label.toString (toJson cdata)
      pure none
  toTeX := none
  extraCss := ([blueprintCss, blueprintStyleSwitcherCss] : List String)
  extraJs := ([blueprintStyleSwitcherJs] : List String)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB id data blocks => do
      let .ok { label, definedDefs, definedTheorems, foldProofs } := fromJson? (α := CodeBlockData) data
        | HtmlT.logError s!"Malformed data: {data}"
          pure .empty
      let s ← HtmlT.state
      let attrs := s.htmlId id
      let summaryText :=
        match s.getDomainObject? informalDomain label.toString with
        | some obj =>
          match fromJson? (α := BlockData) obj.data with
          | .ok b => codePanelSummary b
          | .error _ => "Code"
        | none => "Code"
      let orderedDecls := sortDeclsByCommand (definedDefs ++ definedTheorems)
      let getDeclHref (decl : Name) : Option String :=
        Resolve.resolveExampleDeclHref? s decl
      let summaryHoverData := mkCodeHoverData label definedDefs definedTheorems getDeclHref
      let progressHover : Output.Html := {{
        <div class="bp_code_hover" role="tooltip">
          <div class="bp_code_hover_title">{{.text true s!"{summaryHoverData.label}"}}</div>
          <div class="bp_code_hover_section">
            <span class="bp_code_hover_label">"Lean definitions"</span>
            <ul class="bp_code_hover_list">
              {{codeHoverDeclItems summaryHoverData.definedDefs}}
            </ul>
          </div>
          <div class="bp_code_hover_section">
            <span class="bp_code_hover_label">"Lean theorems/lemmas"</span>
            <ul class="bp_code_hover_list">
              {{codeHoverDeclItems summaryHoverData.definedTheorems}}
            </ul>
          </div>
          <div class="bp_code_hover_section">
            <span class="bp_code_hover_label">"Sorries"</span>
            <ul class="bp_code_hover_list">
              {{codeHoverDeclItems summaryHoverData.sorries}}
            </ul>
          </div>
        </div>
      }}
      let progressBar : Output.Html :=
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
                  s!"{decl.name}: contains sorry {codeDeclSorryLocation decl}"
                else
                  s!"{decl.name}: {codeDeclSorryLocation decl}"
              else
                s!"{decl.name}: complete"
            {{<span class={{cls}} title={{title}} style={{s!"flex: {weight} 1 0%"}}></span>}}
          let bar := {{<span class="bp_code_progress" aria-label="Lean declaration progress">{{segments}}</span>}}
          {{<span class="bp_code_hover_wrap bp_code_summary_indicator">{{bar}}{{progressHover}}</span>}}
      let summaryHover := codeHoverText label definedDefs definedTheorems
      let panelAttrs := attrs.push ("data-bp-proof-fold", if foldProofs then "on" else "off")
      let panelBody := .seq (← blocks.mapM goB)
      pure <| mkCodePanel summaryText summaryHover progressBar panelBody panelAttrs

private def expanderImpl (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let blockRef ← getRef
    let label := cfg.label
    let kind? := if isProof then none else some kind
    let resolvedExternalCode ← resolveExternalCodeList label cfg.externalCode
    let hasExternal := !resolvedExternalCode.isEmpty
    let hasLeanok := cfg.leanok.getD false
    if !cfg.invalidExternalCode.isEmpty then
      logWarning m!"Label {label}: ignoring malformed names in '(lean := ...)' ({String.intercalate ", " cfg.invalidExternalCode.toList})"
    if hasExternal && hasLeanok then
      logError m!"Label {label} cannot use '(leanok := true)' together with '(lean := ...)'"
    let codeHint : Option Data.CodeRef :=
      if hasExternal then
        some (.external resolvedExternalCode)
      else if hasLeanok then
        some .userOk
      else
        none
    Environment.push label kind? isProof codeHint cfg.parent
    let contents ← contents.mapM elabBlock
    if !isProof then
      -- TODO: consolidate this widget-oriented elaboration cache with the traversal preview cache
      -- once we have a phase-safe representation that can serve both pipelines.
      Environment.setStatementElab contents
    let count ← Environment.pop blockRef
    let node? ← Environment.getNode? label
    let nodeCodeRef? := node?.bind (·.code)
    let nodeKind := node?.map (·.kind) |>.getD kind
    let codeStatus := BlockCodeStatus.ofCodeRef nodeCodeRef?
    -- Make the blueprint widget available when selecting this labeled block.
    activateForLabelDoc label blockRef
    let data : BlockData := { kind := nodeKind, label, count, isProof, codeStatus }
    ``(Block.other (Block.informal $(quote data)) #[$contents,*])

private def directiveName (kind : Data.NodeKind) (isProof : Bool): String :=
  if isProof then "proof" else (toString kind).toLower

private def expander (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let label := (directiveName kind isProof)
    Profile.withDocElab "directive" label <|
      (expanderImpl kind isProof) cfg contents

private def collapseWhitespace (s : String) : String :=
  let s := s.replace "\n" " "
  let s := s.replace "\r" " "
  let s := s.replace "\t" " "
  String.intercalate " " <| (s.splitOn " ").filter (fun chunk => !chunk.isEmpty)

private def normalizeGroupChunk (s : String) : String :=
  let s := s.trimAscii.toString
  let s := s.replace "para{\"" ""
  let s := s.replace "para{" ""
  let s := s.replace "\"}" ""
  let s := s.replace "}" ""
  let s := s.replace "\"" ""
  s.trimAscii.toString

private def groupHeaderFromContents (contents : Array (TSyntax `block)) : String :=
  let raw := contents.foldl (init := "") fun acc block =>
    let chunk := normalizeGroupChunk <| (Syntax.reprint block.raw).getD ""
    if chunk.isEmpty then
      acc
    else if acc.isEmpty then
      chunk
    else
      acc ++ "\n" ++ chunk
  collapseWhitespace raw

private def groupExpanderImpl : DirectiveExpanderOf GroupConfig
  | cfg, contents => do
    let header := groupHeaderFromContents contents
    if header.isEmpty then
      logWarning m!"Group {cfg.label} has an empty body; using the group label as header text"
    Environment.registerGroup cfg.label (if header.isEmpty then cfg.label.toString else header)
    ``(Block.concat #[])

@[directive] def «definition» := expander .definition
@[directive] def «lemma_» := expander .lemma
@[directive] def «theorem» := expander .theorem
@[directive] def «corollary» := expander .corollary
@[directive] def «proof» := expander .lemma (isProof := true)
@[directive] def «group» : DirectiveExpanderOf GroupConfig
  | cfg, contents => do
    Profile.withDocElab "directive" "group" <|
      groupExpanderImpl cfg contents

/-- Interpreting Embedded Lean Code blocks -/
private def leanImpl : CodeBlockExpanderOf Config
  | cfg, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with name := some (cfg.label : Lean.Name) }
    let res ← Lean.elabCommands leanCfg contents
    let codeBlock := res.block
    let definedDefs := res.definedDefs.map CodeDeclData.ofLiterateDef
    let definedTheorems := res.definedTheorems.map CodeDeclData.ofLiterateThm
    let data : CodeBlockData := {
      label := cfg.label
      definedDefs
      definedTheorems
      foldProofs := verso.blueprint.foldProofs.get (← getOptions)
    }
    let codeRef ← getRef
    Environment.registerCode cfg.label codeRef res.definedDefs res.definedTheorems
    activateForLabelDoc cfg.label codeRef
    ``(Block.other (Block.informalCode $(quote data)) #[$codeBlock])

@[code_block]
def lean : CodeBlockExpanderOf Config
  | cfg, contents => do
    Profile.withDocElab "code_block" "lean" <| leanImpl cfg contents

/-- Internal Lean setup blocks:
executed but not rendered and not tracked as blueprint code blocks. -/
private def internalImpl : CodeBlockExpanderOf Unit
  | _, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with «show» := false, name := none }
    let _ ← Lean.elabCommands leanCfg contents
    ``(Block.concat #[])

@[code_block]
def internal : CodeBlockExpanderOf Unit
  | cfg, contents => do
    Profile.withDocElab "code_block" "internal" <| internalImpl cfg contents

private def rocqImpl : CodeBlockExpanderOf Unit
  | _cfg, contents => do
    ``(Block.code $contents)

@[code_block]
def rocq : CodeBlockExpanderOf Unit
  | cfg, contents => do
    Profile.withDocElab "code_block" "rocq" <| rocqImpl cfg contents

end Informal
