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
import VersoBlueprint.Lib.HoverRender
import VersoBlueprint.Lib.PreviewSource
import VersoBlueprint.PreviewCache
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

.bp_extra_slot_used_by {
  grid-area: used;
  justify-content: flex-start;
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
  color: #ca8a04;
}

.bp_code_link_status_missing .bp_code_status_symbol,
.bp_code_link_status_axiom .bp_code_status_symbol {
  color: #dc2626;
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
  width: 1.08rem;
  height: 1.08rem;
  border-radius: 999px;
  font-size: 0.74rem;
  line-height: 1;
  color: #ffffff;
  border: 1px solid rgba(15, 23, 42, 0.14);
  box-shadow: 0 1px 2px rgba(15, 23, 42, 0.18);
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
  font-size: 0.78rem;
  font-weight: 600;
  color: #334155;
  white-space: nowrap;
  cursor: default;
}

.bp_used_by_chip_empty {
  color: #64748b;
  font-weight: 500;
}

.bp_used_by_panel {
  position: absolute;
  top: 100%;
  right: 0;
  min-width: 26rem;
  width: min(50rem, 92vw);
  z-index: 26;
  border: 1px solid #cbd5e1;
  border-radius: 0.55rem;
  background: #ffffff;
  box-shadow: 0 12px 28px rgba(15, 23, 42, 0.18);
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
  border-bottom: 1px solid #e2e8f0;
  background: linear-gradient(180deg, #f8fafc, #ffffff);
}

.bp_used_by_panel_title {
  font-size: 0.82rem;
  font-weight: 700;
  color: #0f172a;
}

.bp_used_by_panel_meta {
  font-size: 0.72rem;
  color: #64748b;
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
  border: 1px solid #dbe4ee;
  border-radius: 0.45rem;
  background: #f8fafc;
  transition: border-color 120ms ease, box-shadow 120ms ease, background 120ms ease;
}

.bp_used_by_item:hover,
.bp_used_by_item:focus-within,
.bp_used_by_item.bp_used_by_item_active {
  border-color: #93c5fd;
  background: #eff6ff;
  box-shadow: inset 0 0 0 1px rgba(59, 130, 246, 0.12);
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
  color: #0f172a;
}

.bp_used_by_target_meta {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  flex-wrap: wrap;
  margin-top: 0.26rem;
  color: #475569;
  font-size: 0.72rem;
}

.bp_used_by_target_meta code {
  font-size: 0.72rem;
}

.bp_used_by_axis_badge {
  display: inline-flex;
  align-items: center;
  border: 1px solid #cbd5e1;
  border-radius: 999px;
  background: #ffffff;
  color: #334155;
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
  padding: 0.08rem 0.34rem;
}

.bp_used_by_preview_surface {
  min-height: 14rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  background: #f8fafc;
  overflow: hidden;
}

.bp_used_by_preview_header {
  padding: 0.5rem 0.62rem 0.44rem;
  border-bottom: 1px solid #e2e8f0;
  background: linear-gradient(180deg, #f8fafc, #ffffff);
}

.bp_used_by_preview_label {
  font-size: 0.66rem;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: #64748b;
}

.bp_used_by_preview_title {
  margin-top: 0.16rem;
  font-size: 0.8rem;
  font-weight: 700;
  color: #0f172a;
}

.bp_used_by_preview_body {
  max-height: min(20rem, 62vh);
  overflow: auto;
  padding: 0.62rem 0.68rem 0.72rem;
  background: #ffffff;
}

.bp_used_by_preview_empty {
  color: #64748b;
  font-size: 0.76rem;
  font-style: italic;
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
  color: #334155;
  border: 1px solid #d7dee7;
  border-radius: 999px;
  padding: 0.12rem 0.45rem;
  background: linear-gradient(180deg, #ffffff, #f8fafc);
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
  border-top: 1px solid #e2e8f0;
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
  margin: 0.32rem 0 0;
  padding: 0.1rem 0 0.1rem 0.7rem;
  border: 0;
  border-left: 0.18rem solid #94a3b8;
  border-radius: 0;
  background: transparent;
  white-space: pre-wrap;
  font-size: 0.8rem;
  line-height: 1.5;
  color: #0f172a;
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

private def mergeLabelArrays (xs ys : Array Data.Label) : Array Data.Label :=
  ys.foldl (init := xs) fun acc label =>
    if acc.contains label then acc else acc.push label

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
      partPrefix := existing.partPrefix <|> incoming.partPrefix
      globalCount := existing.globalCount <|> incoming.globalCount
      statementDeps := mergeLabelArrays existing.statementDeps incoming.statementDeps
      proofDeps := mergeLabelArrays existing.proofDeps incoming.proofDeps
  }

private def blockSummaryTitle (state : Verso.Genre.Manual.TraverseState) (data : BlockData) : String :=
  data.displayTitle state

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
  match state.domains.get? informalDomain with
  | none => #[]
  | some domain =>
    sortUsedByEntries <| domain.objects.foldl (init := #[]) fun acc _canonical obj =>
      match fromJson? (α := BlockData) obj.data with
      | .error _ => acc
      | .ok source =>
        if source.label == target then
          acc
        else
          let inStatement := source.statementDeps.contains target
          let inProof := source.proofDeps.contains target
          if !inStatement && !inProof then
            acc
          else
            acc.push { source, inStatement, inProof }

private def usedByPreviewId (targetLabel sourceLabel : Data.Label) : String :=
  s!"bp-used-by-{Informal.HoverRender.previewKey (toString targetLabel)}-{Informal.HoverRender.previewKey (toString sourceLabel)}"

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

private def renderUsedByEntry {m}
    [Monad m]
    (state : Verso.Genre.Manual.TraverseState)
    (renderBlock :
      Verso.Doc.Block Verso.Genre.Manual →
        Verso.Doc.Html.HtmlT Verso.Genre.Manual m Output.Html)
    (data : BlockData) :
    Verso.Doc.Html.HtmlT Verso.Genre.Manual m Output.Html := do
  match data.kind with
  | .proof => pure .empty
  | .statement _ =>
    let entries := collectUsedByEntries state data.label
    if entries.isEmpty then
      pure {{
        <span class="bp_used_by_chip bp_used_by_chip_empty" title="No reverse dependencies">
          {{.text true (usedByChipText 0)}}
        </span>
      }}
    else if h : entries.size = 1 then
      let entry := entries[0]'(by simp [h])
      let previewId := usedByPreviewId data.label entry.source.label
      let previewTitle := blockSummaryTitle state entry.source
      let href := Resolve.resolveDomainHref? state Resolve.informalDomainName entry.source.label.toString
      let preview? ←
        Informal.PreviewSource.renderTraversalPreview? state
          (fun block =>
            Informal.HoverRender.withInlinePreviewRenderContext (renderBlock block))
          entry.source.label
      let previewBody :=
        match preview? with
        | some rendered => .seq rendered
        | none => usedByPreviewFallbackBody entry
      let chipNode : Output.Html :=
        if let some href := href then
          {{<a class="bp_used_by_chip bp_code_link" href={{href}} title={{s!"Reverse dependency: {previewTitle}"}}>
              {{.text true (usedByChipText 1)}}
            </a>}}
        else
          {{<span class="bp_used_by_chip" title={{s!"Reverse dependency: {previewTitle}"}}>
              {{.text true (usedByChipText 1)}}
            </span>}}
      pure <| Informal.HoverRender.inlinePreviewNode true chipNode previewBody previewId previewTitle
    else
      let rows ← entries.mapM fun entry => do
        let previewId := usedByPreviewId data.label entry.source.label
        let previewTitle := blockSummaryTitle state entry.source
        let href := Resolve.resolveDomainHref? state Resolve.informalDomainName entry.source.label.toString
        let preview? ←
          Informal.PreviewSource.renderTraversalPreview? state
            (fun block =>
              Informal.HoverRender.withInlinePreviewRenderContext (renderBlock block))
            entry.source.label
        let previewBody :=
          match preview? with
          | some rendered => .seq rendered
          | none => usedByPreviewFallbackBody entry
        let rowNode : Output.Html :=
          let titleNode := {{<span class="bp_used_by_target_title">{{.text true previewTitle}}</span>}}
          let metaNode := {{
            <span class="bp_used_by_target_meta">
              <code>s!"{entry.source.label}"</code>
              {{renderUsedByAxisBadges entry}}
            </span>
          }}
          if let some href := href then
            {{<a class="bp_used_by_target" href={{href}}>{{titleNode}}{{metaNode}}</a>}}
          else
            {{<span class="bp_used_by_target">{{titleNode}}{{metaNode}}</span>}}
        pure {{
          <li class="bp_used_by_item"
              "data-bp-used-preview-id"={{previewId}}
              "data-bp-used-preview-title"={{previewTitle}}>
            {{rowNode}}
            <template class="bp_used_by_preview_tpl" "data-bp-used-preview-id"={{previewId}}>
              {{previewBody}}
            </template>
          </li>
        }}
      pure {{
        <div class="bp_used_by_wrap">
          <span class="bp_used_by_chip" tabindex="0" title={{s!"Reverse dependencies for {data.label}"}}>
            {{.text true (usedByChipText entries.size)}}
          </span>
          <div class="bp_used_by_panel">
            <div class="bp_used_by_panel_header">
              <div class="bp_used_by_panel_title">{{.text true s!"Used by {entries.size}"}}</div>
              <div class="bp_used_by_panel_meta">"Hover a use site to preview it."</div>
            </div>
            <div class="bp_used_by_panel_body">
              <ul class="bp_used_by_list">
                {{rows}}
              </ul>
              <div class="bp_used_by_preview_surface">
                <div class="bp_used_by_preview_header">
                  <div class="bp_used_by_preview_label">"Preview"</div>
                  <div class="bp_used_by_preview_title">"Hover a use site"</div>
                </div>
                <div class="bp_used_by_preview_body">
                  <div class="bp_used_by_preview_empty">"Hover a use site to preview it."</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      }}

private def renderInformalBlock (data : BlockData) (numberText : String) (attrs : Array (String × String))
    (_statusMark : Option BlockStatusMark) (codeEntry usedByEntry : Output.Html)
    (content : Array Output.Html) : Output.Html :=
  open Verso.Output.Html in
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
      {{
        <div class="bp_extras thm_header_extras">
          <span class="bp_extra_slot bp_extra_slot_code">
            {{codeEntry}}
          </span>
          <span class="bp_extra_slot bp_extra_slot_used_by">
            {{usedByEntry}}
          </span>
        </div>
      }}
  {{
    <div class={{wrapperClass}} title={{labelText}} {{attrs}}>
      <div class={{headingClass}}>
        {{titleRow}}
        {{extras}}
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
  extraCss := ([blueprintCss, Informal.Commands.inlinePreviewCss, blueprintStyleSwitcherCss, Verso.Genre.Manual.docstringStyle] : List String)
  extraJs := ([Informal.Commands.previewHoverUtilsJs, Informal.Commands.inlineLinkPreviewJs, Informal.Commands.usedByPanelJs, blueprintStyleSwitcherJs] : List String)
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
              let panelHeader := codePanelHeader data (data.displayNumber s)
              some <| ExternalCode.renderParts panelHeader decls getDeclHref getDeclAnchorAttrs
          | _, _ => none
        let externalPanel := (externalParts?.map (·.externalCodePanel)).getD .empty
        let content := (← blocks.mapM goB)
        let statusMark := headingParts?.bind (·.statusMark)
        let codeEntry := (headingParts?.map (·.codeEntry)).getD .empty
        let usedByEntry ← renderUsedByEntry s goB data
        let informalBlock :=
          renderInformalBlock data (data.displayNumber s) attrs statusMark codeEntry usedByEntry content
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
    let statementDeps := node?.bind (·.statement.map (·.deps)) |>.getD #[]
    let proofDeps := node?.bind (·.proof.map (·.deps)) |>.getD #[]
    -- Make the blueprint widget available when selecting this labeled block.
    activateForLabelDoc label blockRef
    let data : BlockData := {
      kind := blockKind
      codeData
      label
      count
      numberingMode := numberingMode (← getOptions)
      statementDeps
      proofDeps
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
