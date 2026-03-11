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
import VersoBlueprint.Informal.LeanCodePreview
import VersoBlueprint.Informal.CodeSummary
import VersoBlueprint.Informal.ExternalCode
import VersoBlueprint.Informal.Group
import VersoBlueprint.LabelNameParsing
import VersoBlueprint.Lib.HoverRender
import VersoBlueprint.PreviewCache
import VersoBlueprint.PreviewRender
import VersoBlueprint.Resolve
import VersoBlueprint.StyleSwitcher
import VersoBlueprint.Widget
import VersoBlueprint.Profiling

set_option doc.verso true

open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse
open Verso.Output.Html
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
  priority : Option String := none
  owner : Option Data.AuthorId := none
  tags : Array String := #[]
  effort : Option String := none
  prUrl : Option String := none
  externalCode : Array Data.ExternalRef := #[]
  invalidExternalCode : Array String := #[]
--  hide : Bool := false

section
variable [Monad m] [MonadInfoTree m] [MonadLiftT CoreM m] [MonadEnv m] [MonadError m] [MonadFileMap m]

private def normalizePriority? (raw : String) : Option String :=
  match raw.trimAscii.toString.toLower with
  | "high" => some "high"
  | "medium" => some "medium"
  | "low" => some "low"
  | _ => none

private def normalizeEffort? (raw : String) : Option String :=
  match raw.trimAscii.toString.toLower with
  | "small" | "s" => some "small"
  | "medium" | "m" => some "medium"
  | "large" | "l" => some "large"
  | _ => none

private def normalizeTags (raw : String) : Array String :=
  raw.splitOn ","
    |>.toArray
    |>.map (fun tag => tag.trimAscii.toString.toLower)
    |>.filter (fun tag => !tag.isEmpty)
    |>.foldl (init := #[]) fun acc tag => if acc.contains tag then acc else acc.push tag

def Config.parse  : ArgParse m Config :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) lean leanok parent priority owner tags effort prUrl =>
    let (externalCode, invalidExternalCode) := ExternalCode.parseExternalCodeList lean
    {
      label := LabelNameParsing.parse labelArg.val
      labelSyntax := labelArg.syntax
      lean := lean
      leanok := leanok
      parent := parent.map LabelNameParsing.parse
      priority := priority
      owner := owner.map LabelNameParsing.parse
      tags := normalizeTags (tags.getD "")
      effort := effort
      prUrl := prUrl.map (·.trimAscii.toString)
      externalCode := externalCode
      invalidExternalCode := invalidExternalCode
    }) <$> .positional `label (.withSyntax .string) <*> .named `lean .string true
        <*> .named `leanok .bool true <*> .named `parent .string true <*> .named `priority .string true
        <*> .named `owner .string true <*> .named `tags .string true <*> .named `effort .string true
        <*> .named `pr_url .string true

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
  gap: 0.55rem;
  flex-wrap: wrap;
  font-style: normal;
  font-weight: bold;
}

.bp_heading_title_row {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.bp_heading_title_row_statement {
  display: inline-grid;
  grid-template-columns: 11ch 3ch;
  align-items: baseline;
  column-gap: 0.45rem;
}

.bp_caption {
  display: inline;
}

.bp_label {
  margin-left: 0.5rem;
}

.bp_heading_title_row_statement .bp_label {
  margin-left: 0;
  min-width: 0;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.bp_label::after,
span[class$="_thmlabel"]::after {
  content: ".";
}

.bp_extras {
  display: inline-grid;
  align-items: baseline;
  justify-content: end;
  column-gap: 0.55rem;
  grid-template-columns: minmax(7.2rem, max-content) max-content;
  grid-template-areas: "used code";
  margin-left: auto;
}

.bp_extras_with_group {
  grid-template-columns: minmax(5rem, max-content) minmax(7.2rem, max-content) max-content;
  grid-template-areas: "group used code";
}

.bp_extra_slot {
  display: inline-flex;
  align-items: center;
  min-height: 1.1rem;
  min-width: 0;
}

.bp_extra_slot_code {
  grid-area: code;
  justify-content: flex-end;
}

.bp_extra_slot_group {
  grid-area: group;
  justify-content: flex-start;
}

.bp_extra_slot_used_by {
  grid-area: used;
  justify-content: flex-start;
}

.bp_metadata_panel {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem 0.5rem;
  align-items: center;
  margin: 0.45rem 0 0.7rem;
  padding: 0.45rem 0.55rem;
  border: 1px solid var(--bp-color-border-panel);
  border-radius: var(--bp-radius-xl);
  background: var(--bp-color-surface-muted);
  font-size: 0.78rem;
  font-style: normal;
  font-weight: 400;
}

.bp_metadata_item {
  display: inline-flex;
  align-items: center;
  gap: 0.28rem;
  min-width: 0;
  flex-wrap: wrap;
}

.bp_metadata_owner {
  gap: 0.4rem;
}

.bp_metadata_key {
  font-weight: 700;
  color: var(--bp-color-text-subtle);
}

.bp_metadata_value {
  color: var(--bp-color-text-strong);
}

.bp_metadata_tags {
  display: inline-flex;
  flex-wrap: wrap;
  gap: 0.24rem;
}

.bp_metadata_tag {
  display: inline-flex;
  align-items: center;
  border: 1px solid var(--bp-color-border);
  border-radius: var(--bp-radius-pill);
  background: var(--bp-color-surface);
  color: var(--bp-color-text-muted);
  padding: 0.06rem 0.38rem;
  font-size: 0.72rem;
  font-weight: 600;
}

.bp_metadata_link {
  color: inherit;
  text-decoration: none;
  font-weight: 600;
}

.bp_metadata_link:hover {
  text-decoration: underline;
}

.bp_metadata_avatar {
  width: 1.6rem;
  height: 1.6rem;
  border-radius: 999px;
  object-fit: cover;
  border: 1px solid var(--bp-color-border);
  background: var(--bp-color-surface);
}

.bp_code_link {
  display: inline-flex;
  align-items: center;
  gap: 0.28rem;
  font-size: 0.8rem;
  color: inherit;
  text-decoration: none;
}

.bp_code_link_label {
  display: inline-flex;
  align-items: center;
}

.bp_code_status_symbol {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 0.9rem;
  font-size: 0.78rem;
  font-weight: 700;
  line-height: 1;
}

.bp_code_link_status_proved .bp_code_status_symbol {
  color: inherit;
}

.bp_code_link_status_warning .bp_code_status_symbol {
  color: var(--bp-color-accent-warning);
}

.bp_code_link_status_missing .bp_code_status_symbol,
.bp_code_link_status_axiom .bp_code_status_symbol {
  color: var(--bp-color-accent-danger);
}

.bp_code_link_status_absent .bp_code_status_symbol {
  color: inherit;
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
  border: 1px solid var(--bp-color-border);
  border-radius: var(--bp-radius-md);
  padding: 0.45rem 0.55rem;
  background: var(--bp-color-surface);
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
  border: 1px solid var(--bp-color-border-strong);
  background: linear-gradient(180deg, var(--bp-color-surface-muted), var(--bp-color-border-soft));
  box-shadow: inset 0 1px 1px rgba(15, 23, 42, 0.08);
}

.bp_code_progress_segment {
  min-width: 0.22rem;
}

.bp_code_progress_segment + .bp_code_progress_segment {
  border-left: 1px solid rgba(15, 23, 42, 0.35);
}

.bp_code_progress_segment_ok {
  background: var(--bp-color-accent-success);
}

.bp_code_progress_segment_sorry {
  background: var(--bp-color-accent-warning);
}

.bp_code_progress_segment_missing {
  background: var(--bp-color-accent-danger);
}

.bp_external_status_icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.08rem;
  height: 1.08rem;
  border-radius: 999px;
  font-size: 0.74rem;
  line-height: 1;
  color: var(--bp-color-surface);
  border: 1px solid rgba(15, 23, 42, 0.14);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.18);
}

.bp_external_status_ok {
  background: var(--bp-color-accent-success);
}

.bp_external_status_sorry {
  background: var(--bp-color-accent-warning);
}

.bp_external_status_missing {
  background: var(--bp-color-accent-danger);
}

.bp_external_status_error {
  background: var(--bp-color-accent-info);
}

.bp_code_panel {
  margin: 0;
}

.bp_code_panel_wrapper {
  margin-top: 0.6rem;
}

.bp_code_panel_wrapper .bp_code_block > summary {
  cursor: pointer;
}

.bp_decl_target {
  background: var(--bp-color-selection);
  border-radius: 0.18rem;
  box-shadow: 0 0 0 0.12rem var(--bp-color-selection-ring);
  animation: bp-decl-target-pulse 1.8s ease-out;
}

.bp_decl_target_block {
  border-radius: 0.3rem;
  box-shadow: 0 0 0 0.18rem var(--bp-color-selection-ring);
  background: linear-gradient(180deg, var(--bp-color-selection-surface-soft), rgba(59, 130, 246, 0.04));
  animation: bp-decl-block-pulse 2.2s ease-out;
}

@keyframes bp-decl-target-pulse {
  0% {
    background: var(--bp-color-selection-surface-strong);
    box-shadow: 0 0 0 0.2rem var(--bp-color-selection-shadow-strong);
  }
  100% {
    background: var(--bp-color-selection-surface-faint);
    box-shadow: 0 0 0 0.08rem var(--bp-color-selection-shadow-faint);
  }
}

@keyframes bp-decl-block-pulse {
  0% {
    background: var(--bp-color-selection-surface-soft);
    box-shadow: 0 0 0 0.28rem var(--bp-color-selection-shadow-soft);
  }
  100% {
    background: rgba(59, 130, 246, 0.04);
    box-shadow: 0 0 0 0.14rem var(--bp-color-selection-shadow-faint);
  }
}

.bp_code_link:hover {
  text-decoration: underline;
}

.bp_code_link_empty:hover {
  text-decoration: none;
}

.bp_used_by_wrap {
  position: relative;
  display: inline-flex;
  align-items: center;
  padding-bottom: 0.45rem;
  margin-bottom: -0.45rem;
}

.bp_used_by_wrap::after {
  content: "";
  position: absolute;
  left: -0.25rem;
  right: -0.25rem;
  top: 100%;
  height: 0.45rem;
}

.bp_used_by_chip {
  display: inline-flex;
  align-items: center;
  appearance: none;
  border: 0;
  background: none;
  padding: 0;
  color: inherit;
  font: inherit;
  line-height: inherit;
  text-align: left;
  font-size: 0.78rem;
  font-weight: 600;
  color: var(--bp-color-text-muted);
  white-space: nowrap;
  cursor: default;
}

.bp_used_by_chip_empty {
  color: var(--bp-color-text-faint);
  font-weight: 500;
}

.bp_used_by_chip_warn {
  color: var(--bp-color-status-warning-text);
}

.bp_used_by_panel {
  position: absolute;
  top: 100%;
  right: 0;
  min-width: 26rem;
  width: min(50rem, 92vw);
  z-index: 26;
  border: 1px solid var(--bp-color-border);
  border-radius: var(--bp-radius-xl);
  background: var(--bp-color-surface);
  box-shadow: var(--bp-shadow-lg);
  display: none;
  font-style: normal;
  font-weight: 400;
}

.bp_used_by_wrap:is(:hover, :focus-within) > .bp_used_by_panel {
  display: block;
}

.bp_used_by_wrap.bp_used_by_wrap_open > .bp_used_by_panel {
  display: block;
}

.bp_used_by_panel_header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.55rem;
  padding: 0.55rem 0.7rem 0.45rem;
  border-bottom: 1px solid var(--bp-color-border-soft);
  background: linear-gradient(180deg, var(--bp-color-surface-muted), var(--bp-color-surface));
}

.bp_used_by_panel_title {
  font-size: 0.82rem;
  font-weight: 700;
  color: var(--bp-color-text-strong);
}

.bp_used_by_panel_meta {
  font-size: 0.72rem;
  color: var(--bp-color-text-faint);
}

.bp_used_by_panel_body {
  display: grid;
  grid-template-columns: minmax(14rem, 18rem) minmax(18rem, 1fr);
  gap: 0.75rem;
  align-items: start;
  padding: 0.7rem;
}

.bp_used_by_list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  max-height: min(20rem, 62vh);
  overflow: auto;
}

.bp_used_by_item {
  border: 1px solid var(--bp-color-border-panel);
  border-radius: var(--bp-radius-md);
  background: var(--bp-color-surface-muted);
  transition: border-color 120ms ease, box-shadow 120ms ease, background 120ms ease;
}

.bp_used_by_item:hover,
.bp_used_by_item:focus-within,
.bp_used_by_item.bp_used_by_item_active {
  border-color: var(--bp-color-focus-border);
  background: var(--bp-color-focus-surface);
  box-shadow: inset 0 0 0 1px var(--bp-color-focus-ring);
}

.bp_used_by_target {
  display: block;
  padding: 0.5rem 0.58rem;
  color: inherit;
  text-decoration: none;
}

.bp_used_by_target:hover {
  text-decoration: none;
}

.bp_used_by_target_title {
  display: block;
  font-size: 0.8rem;
  font-weight: 700;
  color: var(--bp-color-text-strong);
}

.bp_used_by_target_meta {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  flex-wrap: wrap;
  margin-top: 0.26rem;
  color: var(--bp-color-text-subtle);
  font-size: 0.72rem;
}

.bp_used_by_target_meta code {
  font-size: 0.72rem;
}

.bp_used_by_axis_badge {
  display: inline-flex;
  align-items: center;
  border: 1px solid var(--bp-color-border);
  border-radius: var(--bp-radius-pill);
  background: var(--bp-color-surface);
  color: var(--bp-color-text-muted);
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  padding: 0.08rem 0.34rem;
}

.bp_used_by_preview_surface {
  min-height: 14rem;
  border: 1px solid var(--bp-color-border-soft);
  border-radius: var(--bp-radius-lg);
  background: var(--bp-color-surface-muted);
  overflow: hidden;
}

.bp_used_by_preview_header {
  padding: 0.5rem 0.62rem 0.44rem;
  border-bottom: 1px solid var(--bp-color-border-soft);
  background: linear-gradient(180deg, var(--bp-color-surface-muted), var(--bp-color-surface));
}

.bp_used_by_preview_label {
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: var(--bp-color-text-faint);
}

.bp_used_by_preview_title {
  margin-top: 0.16rem;
  font-size: 0.8rem;
  font-weight: 700;
  color: var(--bp-color-text-strong);
}

.bp_used_by_preview_body {
  max-height: min(20rem, 62vh);
  overflow: auto;
  padding: 0.62rem 0.68rem 0.72rem;
  background: var(--bp-color-surface);
}

.bp_used_by_preview_empty {
  color: var(--bp-color-text-faint);
  font-size: 0.76rem;
  font-style: italic;
}

.bp_used_by_preview_notice {
  margin-bottom: 0.62rem;
  padding: 0.48rem 0.58rem;
  border: 1px solid var(--bp-color-status-note-border);
  border-radius: 0.45rem;
  background: var(--bp-color-surface-note);
  color: var(--bp-color-status-note-text);
  font-size: 0.74rem;
}

.bp_used_by_preview_store {
  display: none;
}

@media (max-width: 900px) {
  .bp_used_by_panel {
    right: auto;
    left: 0;
    width: min(34rem, calc(100vw - 1.4rem));
  }

  .bp_used_by_panel_body {
    grid-template-columns: 1fr;
  }

  .bp_used_by_list,
  .bp_used_by_preview_body {
    max-height: min(12rem, 36vh);
  }
}

.bp_status_mark {
  font-size: 0.78rem;
  font-weight: 600;
}

.bp_external_badge {
  font-size: 0.74rem;
  font-weight: 600;
  color: var(--bp-color-text-muted);
  border: 1px solid var(--bp-color-border-panel);
  border-radius: var(--bp-radius-pill);
  padding: 0.12rem 0.45rem;
  background: linear-gradient(180deg, var(--bp-color-surface), var(--bp-color-surface-muted));
}

.bp_external_badge_kind {
  text-transform: capitalize;
}

.bp_external_status_badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  border-radius: 999px;
  border: 1px solid currentColor;
  padding: 0.14rem 0.48rem;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.2;
  white-space: nowrap;
}

.bp_external_status_badge_summary {
  padding-right: 0.58rem;
}

.bp_external_status_badge_text {
  display: inline-block;
}

.bp_external_decl_ok {
  color: var(--bp-color-status-success-text);
}

.bp_external_decl_sorry {
  color: var(--bp-color-status-warning-text);
}

.bp_external_decl_missing {
  color: var(--bp-color-status-error-text);
}

.bp_external_decl_error {
  color: #7c3aed;
}

.bp_external_status_badge.bp_external_decl_ok,
.bp_external_status_badge.bp_external_status_ok {
  background: rgba(22, 101, 52, 0.08);
  border-color: rgba(22, 101, 52, 0.18);
}

.bp_external_status_badge.bp_external_decl_sorry,
.bp_external_status_badge.bp_external_status_sorry {
  background: rgba(161, 98, 7, 0.09);
  border-color: rgba(161, 98, 7, 0.2);
}

.bp_external_status_badge.bp_external_decl_missing,
.bp_external_status_badge.bp_external_status_missing {
  background: rgba(185, 28, 28, 0.08);
  border-color: rgba(185, 28, 28, 0.18);
}

.bp_external_status_badge.bp_external_decl_error,
.bp_external_status_badge.bp_external_status_error {
  background: rgba(124, 58, 237, 0.08);
  border-color: rgba(124, 58, 237, 0.18);
}

.bp_external_decl_meta {
  margin-top: 0.18rem;
  color: #475569;
  font-size: 0.75rem;
  line-height: 1.45;
}

.bp_external_decl_rendered_meta {
  display: flex;
  align-items: center;
  gap: 0.3rem 0.7rem;
  flex-wrap: wrap;
}

.bp_external_decl_footer_status {
  padding: 0.1rem 0.42rem;
  font-size: 0.7rem;
  font-weight: 700;
}

.bp_external_decl_list {
  list-style: none;
  margin: 0.45rem 0 0;
  padding-left: 0;
}

.bp_external_decl_item {
  margin: 0;
  padding: 0;
}

.bp_external_decl_item_rendered {
  padding: 0;
}

.bp_external_decl_list > .bp_external_decl_item + .bp_external_decl_item {
  margin-top: 0.85rem;
  padding-top: 0.85rem;
  border-top: 1px solid var(--bp-color-border-soft);
}

.bp_external_decl_head {
  display: flex;
  align-items: baseline;
  gap: 0.3rem 0.7rem;
  flex-wrap: wrap;
  line-height: 1.5;
}

.bp_external_decl_head_meta {
  color: #64748b;
  font-size: 0.76rem;
}

.bp_external_decl_rendered_source {
  margin-left: auto;
}

.bp_external_decl_details {
  margin-top: 0.12rem;
}

.bp_external_decl_details summary {
  cursor: pointer;
  font-size: 0.72rem;
  color: var(--bp-color-text-muted);
}

.bp_external_decl_preview {
  margin-top: 0.2rem;
  border-left: 2px solid var(--bp-color-border-soft);
  padding-left: 0.45rem;
}

.bp_external_decl_preview summary {
  cursor: pointer;
  font-size: 0.72rem;
  color: var(--bp-color-text-strong);
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
  margin: 0.32rem 0 0;
  padding: 0.1rem 0 0.1rem 0.7rem;
  border: 0;
  border-left: 0.18rem solid var(--bp-color-border-strong);
  border-radius: 0;
  background: transparent;
  white-space: pre-wrap;
  font-size: 0.8rem;
  line-height: 1.5;
  color: var(--bp-color-text-strong);
}

.bp_external_decl_rendered {
  margin: 0.35rem 0 0;
  border: 0;
  border-radius: 0;
  background: transparent;
  box-shadow: none;
  padding: 0;
  overflow-x: auto;
}

.bp_external_decl_rendered .declaration {
  margin: 0;
  padding: 0;
  min-width: 100%;
}

.bp_external_decl_rendered .bp_external_decl_body {
  margin-top: 0.6rem;
}

.bp_external_decl_rendered .bp_external_decl_body > :first-child {
  margin-top: 0;
}

.bp_external_decl_rendered .bp_external_decl_body > :last-child {
  margin-bottom: 0;
}

.bp_external_decl_rendered .bp_external_decl_body h1 {
  margin: 0.85rem 0 0.35rem;
  color: inherit;
  font-size: 0.82rem;
  font-weight: 600;
  letter-spacing: 0;
  text-transform: none;
}

.bp_external_decl_rendered pre {
  overflow-x: auto;
}

.bp_external_decl_rendered .constructor + .constructor,
.bp_external_decl_rendered .subdocs + .subdocs {
  margin-top: 0.6rem;
}

.bp_external_decl_rendered .name-and-type {
  margin: 0;
}

.bp_external_decl_rendered .docs {
  margin-top: 0.35rem;
}

.bp_external_decl_rendered .inheritance {
  margin-top: 0.25rem;
  color: #64748b;
  font-size: 0.82rem;
}

.bp_external_decl_rendered .inheritance ol {
  display: inline;
  margin: 0;
  padding: 0;
}

.bp_external_decl_rendered .inheritance li {
  display: inline;
  list-style: none;
}

.bp_external_decl_rendered .inheritance li + li::before {
  content: " > ";
}

.bp_external_decl_rendered .docstring {
  margin-top: 0.6rem;
  padding: 0;
  border: 0;
  background: transparent;
  color: inherit;
  font-family: var(--verso-text-font-family, inherit);
  font-size: 0.98em;
  line-height: 1.6;
  white-space: pre-wrap;
  overflow: visible;
  max-height: none;
}

.bp_external_decl_rendered details {
  margin-top: 0.55rem;
}

.bp_external_decl_rendered details > summary {
  cursor: pointer;
  font-weight: 600;
}

.bp_external_decl_rendered details > ul {
  margin: 0.4rem 0 0;
  padding-left: 1rem;
}

.bp_external_decl_rendered details > ul > li {
  margin: 0.18rem 0;
  overflow-wrap: anywhere;
}

.bp_external_decl_rendered_source .bp_code_link {
  font-size: 0.76rem;
  white-space: nowrap;
}

@media (max-width: 700px) {
  .bp_code_block summary {
    align-items: flex-start;
    flex-wrap: wrap;
  }

  .bp_code_summary_text {
    white-space: normal;
  }

  .bp_code_summary_indicator {
    margin-left: 0;
  }

  .bp_external_decl_head_meta,
  .bp_external_decl_rendered_source {
    width: 100%;
    margin-left: 0;
  }

  .bp_external_decl_list > .bp_external_decl_item + .bp_external_decl_item {
    margin-top: 0.7rem;
    padding-top: 0.7rem;
  }
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
  color: var(--bp-color-text-faint);
}

.bp-proof-by-toggle.bp-proof-open::after {
  content: "";
}

.bp_wrapper.bp_style_plain .bp_heading,
div.theorem-style-plain div[class$="_thmheading"] {
  font-style: normal;
  font-weight: bold;
}

.bp_wrapper.bp_style_plain .bp_content,
div.theorem-style-plain div[class$="_thmcontent"] {
  font-style: italic;
  font-weight: normal;
}

.bp_wrapper.bp_style_definition .bp_heading,
div.theorem-style-definition div[class$="_thmheading"] {
  font-style: normal;
  font-weight: bold;
}

.bp_kind_theorem_content,
div.theorem_thmcontent {
  border-left: 0.15rem solid black;
}

div.proposition_thmcontent {
  border-left: 0.15rem solid black;
}

.bp_kind_lemma_content,
div.lemma_thmcontent {
  border-left: 0.1rem solid black;
}

.bp_kind_corollary_content,
div.corollary_thmcontent {
  border-left: 0.1rem solid black;
}

.bp_kind_proof_content,
div.proof_content {
  border-left: 0.08rem solid grey;
}

.bp_wrapper:target {
  animation: bp-target-pulse 1.6s ease-out;
  box-shadow: 0 0 0 0.18rem var(--bp-color-target-ring);
  border-radius: 0.35rem;
}

@keyframes bp-target-pulse {
  0% {
    background-color: var(--bp-color-target-surface);
    box-shadow: 0 0 0 0.28rem var(--bp-color-target-ring-strong);
  }
  100% {
    background-color: transparent;
    box-shadow: 0 0 0 0.18rem var(--bp-color-target-ring);
  }
}
"##

def blueprintStyleSwitcherCss : String := StyleSwitcher.css

def blueprintStyleSwitcherJs : String := StyleSwitcher.jsInteractive

def shouldWritePreviewDataByIds [BEq α] (existingIds : Array α) (currentId : α) : Bool :=
  existingIds.isEmpty || existingIds.contains currentId

private def shouldWritePreviewData (existing? : Option Verso.Multi.Object) (id : Verso.Multi.InternalId) : Bool :=
  shouldWritePreviewDataByIds ((existing?.map (·.ids.toArray)).getD #[]) id

private def mergeLabelArrays (xs ys : Array Data.Label) : Array Data.Label :=
  ys.foldl (init := xs) fun acc label =>
    if acc.contains label then acc else acc.push label

private def mergeStringArrays (xs ys : Array String) : Array String :=
  ys.foldl (init := xs) fun acc value =>
    if acc.contains value then acc else acc.push value

private def mergeStoredBlockData (existing incoming : BlockData) : BlockData :=
  let kind :=
    match existing.kind, incoming.kind with
    | .statement _, _ => existing.kind
    | .proof, .statement _ => incoming.kind
    | .proof, .proof => existing.kind
  let codeData :=
    match existing.codeData, incoming.codeData with
    | some existingData, _ => some existingData
    | none, some incomingData => some incomingData
    | none, none => none
  { existing with
      kind
      codeData
      parent := existing.parent <|> incoming.parent
      partPrefix := existing.partPrefix <|> incoming.partPrefix
      globalCount := existing.globalCount <|> incoming.globalCount
      statementDeps := mergeLabelArrays existing.statementDeps incoming.statementDeps
      proofDeps := mergeLabelArrays existing.proofDeps incoming.proofDeps
      owner := existing.owner <|> incoming.owner
      ownerDisplayName := existing.ownerDisplayName <|> incoming.ownerDisplayName
      ownerUrl := existing.ownerUrl <|> incoming.ownerUrl
      ownerImageUrl := existing.ownerImageUrl <|> incoming.ownerImageUrl
      tags := mergeStringArrays existing.tags incoming.tags
      effort := existing.effort <|> incoming.effort
      priority := existing.priority <|> incoming.priority
      prUrl := existing.prUrl <|> incoming.prUrl
  }

private def blockSummaryTitle (state : Verso.Genre.Manual.TraverseState) (data : BlockData) : String :=
  data.displayTitle state

private def sortBlockData (entries : Array BlockData) : Array BlockData :=
  entries.qsort fun a b =>
    let aNum := a.globalCount.getD a.count
    let bNum := b.globalCount.getD b.count
    aNum < bNum ||
      (aNum == bNum && a.label.toString < b.label.toString)

private def collectStoredBlocks
    (state : Verso.Genre.Manual.TraverseState) : Array BlockData :=
  match state.domains.get? informalDomain with
  | none => #[]
  | some domain =>
    sortBlockData <| domain.objects.foldl (init := #[]) fun acc _canonical obj =>
      match fromJson? (α := BlockData) obj.data with
      | .ok block => acc.push block
      | .error _ => acc

private def resolveStoredGroupData?
    (state : Verso.Genre.Manual.TraverseState) (label : Data.Label) : Option GroupBlockData :=
  match state.getDomainObject? Resolve.informalGroupDomainName label.toString with
  | none => none
  | some obj =>
    match fromJson? (α := GroupBlockData) obj.data with
    | .ok groupData => some groupData
    | .error _ => none

private structure GroupRenderInfo where
  label : Data.Label
  title : String
  declared : Bool := false

private def groupRenderInfo?
    (state : Verso.Genre.Manual.TraverseState) (data : BlockData) : Option GroupRenderInfo := do
  let parent ← data.parent
  match resolveStoredGroupData? state parent with
  | some groupData => some { label := parent, title := groupData.header, declared := true }
  | none => some { label := parent, title := parent.toString, declared := false }

private structure RelatedPanelEntry where
  source : BlockData
  previewId : String
  previewKey : String
  previewTitle : String
  href : Option String := none
  previewFallbackBody : Output.Html := .empty
  metaHtml : Output.Html := .empty

private structure RelatedPanelConfig where
  chipText : Nat → String
  chipTitle : Nat → String
  singleTitle : RelatedPanelEntry → String
  panelTitle : Nat → String
  panelMeta : String
  panelMetaClass : String := "bp_used_by_panel_meta"
  previewDefaultTitle : String := "Hover an entry"
  previewEmptyText : String := "Hover an entry to preview it."
  chipClass : String := "bp_used_by_chip"
  emptyChipClass : String := "bp_used_by_chip bp_used_by_chip_empty"

private structure UsedByEntry where
  source : BlockData
  inStatement : Bool := false
  inProof : Bool := false

private def sortUsedByEntries (entries : Array UsedByEntry) : Array UsedByEntry :=
  entries.qsort fun a b =>
    let aNum := a.source.globalCount.getD a.source.count
    let bNum := b.source.globalCount.getD b.source.count
    aNum < bNum ||
      (aNum == bNum && a.source.label.toString < b.source.label.toString)

private def collectUsedByEntries
    (state : Verso.Genre.Manual.TraverseState) (target : Data.Label) : Array UsedByEntry :=
  sortUsedByEntries <| (collectStoredBlocks state).foldl (init := #[]) fun acc source =>
    if source.label == target then
      acc
    else
      let inStatement := source.statementDeps.contains target
      let inProof := source.proofDeps.contains target
      if !inStatement && !inProof then
        acc
      else
        acc.push { source, inStatement, inProof }

private def collectGroupEntries
    (state : Verso.Genre.Manual.TraverseState) (target : BlockData) (group : GroupRenderInfo) :
    Array BlockData :=
  (collectStoredBlocks state).foldl (init := #[]) fun acc source =>
    if source.label == target.label then
      acc
    else if source.parent == some group.label then
      match source.kind with
      | .statement _ => acc.push source
      | .proof => acc
    else
      acc

private def usedByPreviewId (targetLabel sourceLabel : Data.Label) : String :=
  s!"bp-used-by-{Informal.HoverRender.previewKey (toString targetLabel)}-{Informal.HoverRender.previewKey (toString sourceLabel)}"

private def usedByPreviewLookupKey (source : BlockData) : String :=
  PreviewCache.key source.label (PreviewCache.Facet.ofInProgressKind source.kind)

private def usedByChipText (count : Nat) : String :=
  s!"used by {count}"

private def renderUsedByAxisBadges (entry : UsedByEntry) : Output.Html :=
  open Verso.Output.Html in
  let statementBadge : Array Output.Html :=
    if entry.inStatement then
      #[{{<span class="bp_used_by_axis_badge">"statement"</span>}}]
    else
      #[]
  let proofBadge : Array Output.Html :=
    if entry.inProof then
      #[{{<span class="bp_used_by_axis_badge">"proof"</span>}}]
    else
      #[]
  .seq (statementBadge ++ proofBadge)

private def usedByPreviewFallbackBody (entry : UsedByEntry) : Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_code_hover_section">
      <span class="bp_code_hover_label">"Blueprint label"</span>
      <ul class="bp_code_hover_list">
        <li><code>s!"{entry.source.label}"</code></li>
      </ul>
    </div>
    <div class="bp_code_hover_section">
      <span class="bp_code_hover_label">"Uses target in"</span>
      <ul class="bp_code_hover_list">
        {{if entry.inStatement then {{<li>"statement"</li>}} else .empty}}
        {{if entry.inProof then {{<li>"proof"</li>}} else .empty}}
      </ul>
    </div>
  }}

private def groupPreviewFallbackBody (group : GroupRenderInfo) (entry : BlockData) : Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_code_hover_section">
      <span class="bp_code_hover_label">"Blueprint label"</span>
      <ul class="bp_code_hover_list">
        <li><code>s!"{entry.label}"</code></li>
      </ul>
    </div>
    <div class="bp_code_hover_section">
      <span class="bp_code_hover_label">"Group"</span>
      <ul class="bp_code_hover_list">
        <li>{{.text true group.title}}</li>
      </ul>
    </div>
  }}

private def groupMissingNotice (group : GroupRenderInfo) : Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_used_by_preview_notice">
      "No matching " <code>":::group"</code> " declaration was found for parent "
      <code>s!"{group.label}"</code> "."
    </div>
  }}

private def mkRelatedPanelEntry {m}
    [Monad m]
    (state : Verso.Genre.Manual.TraverseState)
    (source : BlockData) (previewId : String) (fallbackBody : Output.Html)
    (metaHtml : Output.Html := .empty) :
    Verso.Doc.Html.HtmlT Verso.Genre.Manual m RelatedPanelEntry := do
  let previewTitle := blockSummaryTitle state source
  let href := Resolve.resolveDomainHref? state Resolve.informalDomainName source.label.toString
  pure {
    source
    previewId
    previewKey := usedByPreviewLookupKey source
    previewTitle
    href
    previewFallbackBody := fallbackBody
    metaHtml
  }

private def renderRelatedPanel (cfg : RelatedPanelConfig) (entries : Array RelatedPanelEntry) :
    Output.Html :=
  open Verso.Output.Html in
  let renderChip (chipClass : String) (chipTitle : String) (n : Nat) : Output.Html :=
    {{<span class={{chipClass}} title={{chipTitle}}>{{.text true (cfg.chipText n)}}</span>}}
  if entries.isEmpty then
    renderChip cfg.emptyChipClass (cfg.chipTitle 0) 0
  else if h : entries.size = 1 then
    let entry := entries[0]'(by simp [h])
    let chipNode : Output.Html :=
      if let some href := entry.href then
        {{<a class={{s!"{cfg.chipClass} bp_code_link"}} href={{href}} title={{cfg.singleTitle entry}}>
            {{.text true (cfg.chipText 1)}}
          </a>}}
      else
        renderChip cfg.chipClass (cfg.singleTitle entry) 1
    Informal.HoverRender.inlinePreviewNode
      false chipNode .empty entry.previewId entry.previewTitle
      (previewLookupKey? := some entry.previewKey)
      (previewFallbackLabel? := some s!"{entry.source.label}")
  else
    let rows : Array Output.Html :=
      entries.map fun entry =>
        let rowNode : Output.Html :=
          let titleNode := {{<span class="bp_used_by_target_title">{{.text true entry.previewTitle}}</span>}}
          let metaNode := {{
            <span class="bp_used_by_target_meta">
              {{entry.metaHtml}}
            </span>
          }}
          if let some href := entry.href then
            {{<a class="bp_used_by_target" href={{href}}>{{titleNode}}{{metaNode}}</a>}}
          else
            {{<span class="bp_used_by_target">{{titleNode}}{{metaNode}}</span>}}
        {{
          <li class="bp_used_by_item"
              "data-bp-used-preview-id"={{entry.previewId}}
              "data-bp-used-preview-key"={{entry.previewKey}}
              "data-bp-used-preview-title"={{entry.previewTitle}}>
            {{rowNode}}
            <template class="bp_used_by_preview_fallback_tpl" "data-bp-used-preview-id"={{entry.previewId}}>
              {{entry.previewFallbackBody}}
            </template>
          </li>
        }}
    {{
      <div class="bp_used_by_wrap">
        <button type="button" class={{cfg.chipClass}} title={{cfg.chipTitle entries.size}} "aria-expanded"="false">
          {{.text true (cfg.chipText entries.size)}}
        </button>
        <div class="bp_used_by_panel">
          <div class="bp_used_by_panel_header">
            <div class="bp_used_by_panel_title">{{.text true (cfg.panelTitle entries.size)}}</div>
            <div class={{cfg.panelMetaClass}}>{{.text true cfg.panelMeta}}</div>
          </div>
          <div class="bp_used_by_panel_body">
            <ul class="bp_used_by_list">
              {{rows}}
            </ul>
            <div class="bp_used_by_preview_surface">
              <div class="bp_used_by_preview_header">
                <div class="bp_used_by_preview_label">"Preview"</div>
                <div class="bp_used_by_preview_title">{{.text true cfg.previewDefaultTitle}}</div>
              </div>
              <div class="bp_used_by_preview_body">
                <div class="bp_used_by_preview_empty">{{.text true cfg.previewEmptyText}}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    }}

private def renderUsedByEntry {m}
    [Monad m]
    (state : Verso.Genre.Manual.TraverseState)
    (data : BlockData) :
    Verso.Doc.Html.HtmlT Verso.Genre.Manual m Output.Html := do
  match data.kind with
  | .proof => pure .empty
  | .statement _ =>
    let entries := collectUsedByEntries state data.label
    let panelEntries ← entries.mapM fun entry =>
      mkRelatedPanelEntry state entry.source
        (usedByPreviewId data.label entry.source.label)
        (usedByPreviewFallbackBody entry)
        (metaHtml := {{
          <code>s!"{entry.source.label}"</code>
          {{renderUsedByAxisBadges entry}}
        }})
    let cfg : RelatedPanelConfig := {
      chipText := usedByChipText
      chipTitle := fun n =>
        if n == 0 then
          "No reverse dependencies"
        else
          s!"Reverse dependencies for {data.label}"
      singleTitle := fun entry => s!"Reverse dependency: {entry.previewTitle}"
      panelTitle := fun n => s!"Used by {n}"
      panelMeta := "Hover a use site to preview it."
      previewDefaultTitle := "Hover a use site"
      previewEmptyText := "Hover a use site to preview it."
    }
    pure <| renderRelatedPanel cfg panelEntries

private def renderGroupEntry {m}
    [Monad m]
    (state : Verso.Genre.Manual.TraverseState)
    (data : BlockData) :
    Verso.Doc.Html.HtmlT Verso.Genre.Manual m (Option Output.Html) := do
  match data.kind, groupRenderInfo? state data with
  | .proof, _ => pure none
  | .statement _, none => pure none
  | .statement _, some group =>
    let siblings := collectGroupEntries state data group
    if group.declared && siblings.isEmpty then
      return none
    let panelEntries ← siblings.mapM fun source =>
      let fallbackBody :=
        if group.declared then
          groupPreviewFallbackBody group source
        else
          .seq #[groupMissingNotice group, groupPreviewFallbackBody group source]
      mkRelatedPanelEntry state source
        (s!"bp-group-{Informal.HoverRender.previewKey (toString data.label)}-{Informal.HoverRender.previewKey (toString source.label)}")
        fallbackBody
        (metaHtml := {{<code>s!"{source.label}"</code>}})
    let chipClass :=
      if group.declared then
        "bp_used_by_chip"
      else
        "bp_used_by_chip bp_used_by_chip_warn"
    let emptyChipClass :=
      if group.declared then
        "bp_used_by_chip bp_used_by_chip_empty"
      else
        "bp_used_by_chip bp_used_by_chip_empty bp_used_by_chip_warn"
    let panelMeta :=
      if group.declared then
        "Hover another entry in this group to preview it."
      else
        s!"No :::group declaration was found for parent '{group.label}'; showing entries that share this parent label."
    let cfg : RelatedPanelConfig := {
      chipText := fun _ => "group"
      chipTitle := fun n =>
        if n == 0 then
          if group.declared then
            s!"Group: {group.title}. No other entries in this group."
          else
            s!"Parent group '{group.label}' is referenced here, but no :::group declaration was found."
        else if group.declared then
          s!"Other entries in group {group.title}"
        else
          s!"Undeclared group '{group.label}'"
      singleTitle := fun entry =>
        if group.declared then
          s!"Group member: {entry.previewTitle}"
        else
          s!"Undeclared group '{group.label}': {entry.previewTitle}"
      panelTitle := fun n => s!"Group: {group.title} ({n})"
      panelMeta
      panelMetaClass := if group.declared then "bp_used_by_panel_meta" else "bp_used_by_panel_meta bp_used_by_chip_warn"
      previewDefaultTitle := "Hover a group entry"
      previewEmptyText := "Hover a group entry to preview it."
      chipClass
      emptyChipClass
    }
    pure <| some (renderRelatedPanel cfg panelEntries)

private def renderInformalBlock (data : BlockData) (numberText : String) (attrs : Array (String × String))
    (_statusMark : Option BlockStatusMark) (codeEntry : Output.Html) (groupEntry? : Option Output.Html)
    (usedByEntry : Output.Html)
    (content : Array Output.Html) : Output.Html :=
  open Verso.Output.Html in
  let labelText := s!"{data.label}"
  let (kindText, showLabel, kindCss, wrapperCss, headingCss, captionCss, labelCss, contentCss) :=
    match data.kind with
    | .proof =>
      ("Proof", false, "proof", "proof_wrapper bp_kind_proof bp_style_proof",
        "proof_heading", "proof_caption", "proof_label", "proof_content")
    | .statement nodeKind =>
      match nodeKind with
      | .definition =>
        (s!"{nodeKind}", true, "definition",
          "definition_thmwrapper theorem-style-definition bp_kind_definition bp_style_definition",
          "definition_thmheading", "definition_thmcaption", "definition_thmlabel", "definition_thmcontent")
      | .theorem =>
        (s!"{nodeKind}", true, "theorem",
          "theorem_thmwrapper theorem-style-plain bp_kind_theorem bp_style_plain",
          "theorem_thmheading", "theorem_thmcaption", "theorem_thmlabel", "theorem_thmcontent")
      | .lemma =>
        (s!"{nodeKind}", true, "lemma",
          "lemma_thmwrapper theorem-style-plain bp_kind_lemma bp_style_plain",
          "lemma_thmheading", "lemma_thmcaption", "lemma_thmlabel", "lemma_thmcontent")
      | .corollary =>
        (s!"{nodeKind}", true, "corollary",
          "corollary_thmwrapper theorem-style-plain bp_kind_corollary bp_style_plain",
          "corollary_thmheading", "corollary_thmcaption", "corollary_thmlabel", "corollary_thmcontent")
  let wrapperClass := s!"bp_wrapper bp_kind_{kindCss}_wrapper {kindCss}_thmwrapper {wrapperCss}"
  let headingClass := s!"bp_heading bp_kind_{kindCss}_heading {headingCss}"
  let captionClass := s!"bp_caption bp_kind_{kindCss}_caption {captionCss}"
  let labelClass := s!"bp_label bp_kind_{kindCss}_label {labelCss}"
  let contentClass := s!"bp_content bp_kind_{kindCss}_content {contentCss}"
  let titleRowClass :=
    if showLabel then
      "bp_heading_title_row bp_heading_title_row_statement"
    else
      "bp_heading_title_row"
  let titleRow : Output.Html := {{
    <div class={{titleRowClass}}>
      <span class={{captionClass}} title={{labelText}}> {{.text true kindText}} </span>
      {{ if showLabel then {{<span class={{labelClass}}> {{.text true numberText}} </span>}} else .empty }}
    </div>
  }}
  let extras : Output.Html :=
    match data.kind with
    | .proof => .empty
    | .statement _ =>
      let extrasClass :=
        if groupEntry?.isSome then
          "bp_extras bp_extras_with_group thm_header_extras"
        else
          "bp_extras thm_header_extras"
      {{
        <div class={{extrasClass}}>
          {{match groupEntry? with
            | some groupEntry => {{<span class="bp_extra_slot bp_extra_slot_group">{{groupEntry}}</span>}}
            | none => .empty}}
          <span class="bp_extra_slot bp_extra_slot_code">
            {{codeEntry}}
          </span>
          <span class="bp_extra_slot bp_extra_slot_used_by">
            {{usedByEntry}}
          </span>
        </div>
      }}
  let metadataPanel : Output.Html :=
    match data.kind with
    | .proof => .empty
    | .statement _ =>
      let ownerItem : Output.Html :=
        let avatar : Output.Html :=
          match data.ownerImageUrl with
          | some href => {{ <img class="bp_metadata_avatar" src={{href}} alt="" /> }}
          | none => .empty
        match data.ownerDisplayName, data.owner, data.ownerUrl with
        | some displayName, _, some href =>
          {{ <span class="bp_metadata_item bp_metadata_owner"><span class="bp_metadata_key">"Owner"</span>{{avatar}}<a class="bp_metadata_link bp_metadata_value" href={{href}}>{{.text true displayName}}</a></span> }}
        | some displayName, _, none =>
          {{ <span class="bp_metadata_item bp_metadata_owner"><span class="bp_metadata_key">"Owner"</span>{{avatar}}<span class="bp_metadata_value">{{.text true displayName}}</span></span> }}
        | none, some owner, some href =>
          {{ <span class="bp_metadata_item bp_metadata_owner"><span class="bp_metadata_key">"Owner"</span>{{avatar}}<a class="bp_metadata_link bp_metadata_value" href={{href}}><code>s!"{owner}"</code></a></span> }}
        | none, some owner, none =>
          {{ <span class="bp_metadata_item bp_metadata_owner"><span class="bp_metadata_key">"Owner"</span>{{avatar}}<span class="bp_metadata_value"><code>s!"{owner}"</code></span></span> }}
        | _, _, _ => .empty
      let effortNode : Output.Html :=
        match data.effort with
        | some effort =>
          {{ <span class="bp_metadata_item"><span class="bp_metadata_key">"Effort"</span><span class="bp_metadata_value">{{.text true effort}}</span></span> }}
        | none => .empty
      let priorityNode : Output.Html :=
        match data.priority with
        | some priority =>
          {{ <span class="bp_metadata_item"><span class="bp_metadata_key">"Priority"</span><span class="bp_metadata_value">{{.text true priority}}</span></span> }}
        | none => .empty
      let prNode : Output.Html :=
        match data.prUrl with
        | some href =>
          {{ <span class="bp_metadata_item"><span class="bp_metadata_key">"PR"</span><a class="bp_metadata_link bp_metadata_value" href={{href}}>{{.text true "link"}}</a></span> }}
        | none => .empty
      let tagNodes : Output.Html :=
        if data.tags.isEmpty then
          .empty
        else
          {{
            <span class="bp_metadata_item">
              <span class="bp_metadata_key">"Tags"</span>
              <span class="bp_metadata_tags">
                {{data.tags.map (fun tag => {{ <span class="bp_metadata_tag">{{.text true tag}}</span> }})}}
              </span>
            </span>
          }}
      let hasMetadata :=
        data.owner.isSome || data.ownerDisplayName.isSome || !data.tags.isEmpty || data.effort.isSome || data.priority.isSome || data.prUrl.isSome
      if hasMetadata then
        {{
          <div class="bp_metadata_panel">
            {{ownerItem}}
            {{effortNode}}
            {{priorityNode}}
            {{tagNodes}}
            {{prNode}}
          </div>
        }}
      else
        .empty
  {{
    <div class={{wrapperClass}} title={{labelText}} {{attrs}}>
      <div class={{headingClass}}>
        {{titleRow}}
        {{extras}}
      </div>
      {{metadataPanel}}
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
      let partPrefix := numberedPartPrefix? (← read)
      let blockData := { blockData with partPrefix := blockData.partPrefix <|> partPrefix }
      let label := blockData.label
      let previewFacet := PreviewCache.Facet.ofInProgressKind blockData.kind
      let previewKey := PreviewCache.key label previewFacet
      let previewData := toJson (PreviewCache.Entry.ofBlocks label previewFacet _contents)
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
      if !externalDecls.isEmpty then
        for decl in externalDecls do
          let codePreviewKey := LeanCodePreview.lookupKey decl.canonical
          let codePreviewData := toJson (LeanCodePreview.Entry.ofExternalDecl decl.canonical decl)
          let existingCodePreview? := (← get).getDomainObject? LeanCodePreview.domainName codePreviewKey
          if shouldWritePreviewData existingCodePreview? id then
            modify λ s => s.saveDomainObjectData LeanCodePreview.domainName codePreviewKey codePreviewData
          if existingCodePreview?.isNone then
            let path ← (·.path) <$> read
            let _ ← Verso.Genre.Manual.externalTag id path s!"--lean-code-preview-{codePreviewKey}"
            modify λ s => s.saveDomainObject LeanCodePreview.domainName codePreviewKey id
      for decl in externalDecls do
        let key := Resolve.externalRenderedDeclTargetKey label decl.canonical
        if ((← get).getDomainObject? informalExternalDeclDomain key).isNone then
          let declId ← Verso.Genre.Manual.freshId
          let path ← (·.path) <$> read
          let _ ← Verso.Genre.Manual.externalTag declId path
            s!"--informal-external-decl-{label}-{decl.canonical}"
          modify λ s => s.saveDomainObject informalExternalDeclDomain key declId
      match (← get).getDomainObject? informalDomain label.toString with
      | some obj =>
        let mergedData :=
          match fromJson? (α := BlockData) obj.data with
          | .ok existing => mergeStoredBlockData existing blockData
          | .error _ => blockData
        modify λ s => s.saveDomainObjectData informalDomain label.toString (toJson mergedData)
        return none
      | none =>
        let path ← (·.path) <$> read
        let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-{label}"
        modify fun s =>
          let (globalCount, s) := reserveGlobalBlockNumber s
          let blockData := { blockData with globalCount := blockData.globalCount <|> some globalCount }
          s
            |> (·.saveDomainObject informalDomain label.toString id)
            |> (·.saveDomainObjectData informalDomain label.toString (toJson blockData))
        return none
  toTeX := none
  extraCss := Informal.Commands.withInlinePreviewCssAssets [blueprintCss, blueprintStyleSwitcherCss, Verso.Genre.Manual.docstringStyle]
  extraJs := Informal.Commands.withInlinePreviewJsAssets [] [Informal.Commands.usedByPanelJs, blueprintStyleSwitcherJs]
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
        let ctxt ← HtmlT.context
        let data := data.withResolvedNumbering s (numberedPartPrefix? ctxt)
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
          match Resolve.resolveRenderedExternalDeclHref? s data.label decl with
          | some href => some href
          | none => Resolve.resolveInlineLeanDeclHref? s decl
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
        let panelSummary := CodeSummary.renderPanelIndicator data.label cdata getDeclHref
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
              let panelHeader := codePanelHeader data (data.displayNumber s)
              some <| ExternalCode.renderParts
                panelHeader
                panelSummary.summaryTitle
                panelSummary.indicator
                decls
                getDeclHref
                getDeclAnchorAttrs
          | _, _ => none
        let externalPanel := (externalParts?.map (·.externalCodePanel)).getD .empty
        let content := (← blocks.mapM goB)
        let statusMark := headingParts?.bind (·.statusMark)
        let codeEntry := (headingParts?.map (·.codeEntry)).getD .empty
        let groupEntry ← renderGroupEntry s data
        let usedByEntry ← renderUsedByEntry s data
        let informalBlock :=
          renderInformalBlock data (data.displayNumber s) attrs statusMark codeEntry groupEntry usedByEntry content
        return .seq #[informalBlock, externalPanel]

private def expanderImpl (kind : Data.NodeKind) (isProof : Bool := false) : DirectiveExpanderOf Config
  | cfg, contents => do
    let blockRef ← getRef
    let label := cfg.label
    let envKind : Data.InProgressKind :=
      if isProof then .proof else .statement kind
    let resolvedExternalCode ← ExternalCode.resolveExternalCodeList label cfg.labelSyntax kind cfg.externalCode
    let hasExternalRaw := !resolvedExternalCode.isEmpty
    let hasLeanok := cfg.leanok.getD false
    if !cfg.invalidExternalCode.isEmpty then
      logWarningAt cfg.labelSyntax m!"Label {label}: ignoring malformed names in '(lean := ...)' ({String.intercalate ", " cfg.invalidExternalCode.toList})"
    if hasExternalRaw && hasLeanok then
      logErrorAt cfg.labelSyntax m!"Label {label} cannot use '(leanok := true)' together with '(lean := ...)'"
    if isProof && hasExternalRaw then
      logErrorAt cfg.labelSyntax m!"Label {label} cannot use '(lean := ...)' in a proof block"
    let priority : Option String ←
      match cfg.priority with
      | none => pure none
      | some raw =>
        match normalizePriority? raw with
        | some normalized =>
          if isProof then
            logErrorAt cfg.labelSyntax m!"Label {label} cannot use '(priority := ...)' in a proof block"
            pure none
          else
            pure (some normalized)
        | none =>
          logErrorAt cfg.labelSyntax m!"Label {label} has invalid '(priority := \"{raw}\")'; expected one of \"high\", \"medium\", \"low\""
          pure none
    let owner : Option Data.AuthorId ←
      match cfg.owner with
      | none => pure none
      | some owner =>
        if isProof then
          logErrorAt cfg.labelSyntax m!"Label {label} cannot use '(owner := ...)' in a proof block"
          pure none
        else if (← Environment.getAuthor? owner).isNone then
          logErrorAt cfg.labelSyntax m!"Label {label} references unknown owner '{owner}'; declare it first with ':::author'"
          pure none
        else
          pure (some owner)
    let effort : Option String ←
      match cfg.effort with
      | none => pure none
      | some raw =>
        match normalizeEffort? raw with
        | some normalized =>
          if isProof then
            logErrorAt cfg.labelSyntax m!"Label {label} cannot use '(effort := ...)' in a proof block"
            pure none
          else
            pure (some normalized)
        | none =>
          logErrorAt cfg.labelSyntax m!"Label {label} has invalid '(effort := \"{raw}\")'; expected one of \"small\", \"medium\", \"large\""
          pure none
    let tags : Array String :=
      if isProof && !cfg.tags.isEmpty then
        #[]
      else
        cfg.tags
    if isProof && !cfg.tags.isEmpty then
      logErrorAt cfg.labelSyntax m!"Label {label} cannot use '(tags := ...)' in a proof block"
    let prUrl : Option String :=
      if isProof then
        none
      else
        match cfg.prUrl with
        | some url =>
          let url := url.trimAscii.toString
          if url.isEmpty then
            none
          else if url.startsWith "http://" || url.startsWith "https://" then
            some url
          else
            none
        | none => none
    if isProof && cfg.prUrl.isSome then
      logErrorAt cfg.labelSyntax m!"Label {label} cannot use '(pr_url := ...)' in a proof block"
    if !isProof then
      if let some url := cfg.prUrl then
        let url := url.trimAscii.toString
        if !url.isEmpty && !(url.startsWith "http://" || url.startsWith "https://") then
          logErrorAt cfg.labelSyntax m!"Label {label} has invalid '(pr_url := \"{url}\")'; expected an http(s) URL"
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
    let accepted ← Environment.push label envKind codeHint cfg.parent priority owner tags effort prUrl
    let contents ← contents.mapM elabBlock
    if !accepted then
      return ← ``(Block.concat #[$contents,*])
    let previewBlocks ← liftM <| Informal.evalElaboratedBlocks (contents.map (·.raw))
    Environment.setPreviewBlocks previewBlocks
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
    let statementDeps := node?.bind (·.statement.map (·.deps)) |>.getD #[]
    let proofDeps := node?.bind (·.proof.map (·.deps)) |>.getD #[]
    let owner := node?.bind (·.owner)
    let ownerInfo? ←
      match owner with
      | some owner => Environment.getAuthor? owner
      | none => pure none
    -- Make the blueprint widget available when selecting this labeled block.
    activateForLabelDoc label blockRef
    let data : BlockData := {
      kind := blockKind
      codeData
      label
      parent := node?.bind (·.parent)
      count
      numberingMode := numberingMode (← getOptions)
      statementDeps
      proofDeps
      owner
      ownerDisplayName := ownerInfo?.map (·.displayName)
      ownerUrl := ownerInfo?.bind (·.url)
      ownerImageUrl := ownerInfo?.bind (·.imageUrl)
      tags := node?.map (·.tags) |>.getD #[]
      effort := node?.bind (·.effort)
      priority := node?.bind (·.priority)
      prUrl := node?.bind (·.prUrl)
    }
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
