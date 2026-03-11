/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintPreviewWiring.Shared

namespace Verso.Tests.BlueprintPreviewWiring.UsedBy

open Verso.Tests.Blueprint.Support
open Verso.Tests.BlueprintPreviewWiring.Shared

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let (out, st) ← renderManualDocHtmlStringAndState manualImpls usedByPreviewDoc
    let usedByJs? := findExtraJsContaining? st "function bindUsedByPanel(panel)"
    pure (
      hasSubstr out "used by 2" &&
      !hasSubstr out "class=\"bp_extra_slot bp_extra_slot_group\"" &&
      hasSubstr out "class=\"bp_extra_slot bp_extra_slot_used_by\"" &&
      hasSubstr out "class=\"bp_used_by_wrap\"" &&
      hasSubstr out "class=\"bp_used_by_panel\"" &&
      hasSubstr out "class=\"bp_used_by_preview_fallback_tpl\"" &&
      hasSubstr out "data-bp-used-preview-id" &&
      hasSubstr out "data-bp-used-preview-key" &&
      hasSubstr out ">statement</span>" &&
      hasSubstr out ">proof</span>" &&
      appearsBefore out "class=\"bp_code_link_wrap\"" "class=\"bp_used_by_wrap\"" &&
      match usedByJs? with
      | some usedByJs =>
        hasSubstr usedByJs "function bindUsedByPanel(panel)" &&
        hasSubstr usedByJs "previewUtils.loadSharedPreviewEntry(previewKey)" &&
        hasSubstr usedByJs "const fallbackTemplates = collectPanelFallbackTemplates(panel);" &&
        hasSubstr usedByJs "item.addEventListener(\"mouseenter\"" &&
        hasSubstr usedByJs "item.addEventListener(\"focusin\"" &&
        !hasSubstr usedByJs "activate(items[0], { openWrap: false })"
      | none => false
    )

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let out ← renderManualDocHtmlString manualImpls usedBySinglePreviewDoc
    pure (
      hasSubstr out "used by 1" &&
      hasSubstr out "used by 0" &&
      hasSubstr out "bp_code_link_status_absent" &&
      hasSubstr out "bp_code_link_empty" &&
      hasSubstr out "No associated Lean declarations" &&
      hasSubstr out ">X</span>" &&
      hasSubstr out ">L∃∀N</span>" &&
      hasSubstr out "class=\"bp_used_by_chip bp_used_by_chip_empty\"" &&
      hasSubstr out "class=\"bp_inline_preview_ref\"" &&
      !hasSubstr out "class=\"bp_inline_preview_tpl\" data-bp-preview-id=\"bp-used-by-" &&
      hasSubstr out "data-bp-preview-id=\"bp-used-by-" &&
      hasSubstr out "data-bp-preview-key="
    )

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let (out, st) ← renderManualDocHtmlStringAndState manualImpls groupPreviewDoc
    let usedByJs? := findExtraJsContaining? st "function bindUsedByPanel(panel)"
    pure (
      hasSubstr out "class=\"bp_extra_slot bp_extra_slot_group\"" &&
      hasSubstr out "class=\"bp_extra_slot bp_extra_slot_used_by\"" &&
      appearsBefore out "class=\"bp_extra_slot bp_extra_slot_group\"" "class=\"bp_extra_slot bp_extra_slot_used_by\"" &&
      hasSubstr out "Hover another entry in this group to preview it." &&
      hasSubstr out "data-bp-used-preview-id=\"bp-group-" &&
      hasSubstr out "Preview group title." &&
      hasSubstr out "used by 1" &&
      match usedByJs? with
      | some usedByJs =>
        hasSubstr usedByJs "function bindUsedByPanel(panel)" &&
        hasSubstr usedByJs "previewUtils.loadSharedPreviewEntry(previewKey)" &&
        !hasSubstr usedByJs "activate(items[0], { openWrap: false })"
      | none => false
    )

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let out ← renderManualDocHtmlString manualImpls missingGroupPreviewDoc
    pure (
      hasSubstr out "bp_used_by_chip_warn" &&
      hasSubstr out "data-bp-preview-id=\"bp-group-" &&
      hasSubstr out "data-bp-preview-key=" &&
      hasSubstr out "grp:missing"
    )

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let out ← renderManualDocHtmlString manualImpls singleDeclaredGroupDoc
    pure (
      !hasSubstr out "class=\"bp_extra_slot bp_extra_slot_group\"" &&
      !hasSubstr out "bp_used_by_chip_warn" &&
      !hasSubstr out "data-bp-used-preview-id=\"bp-group-"
    )

end Verso.Tests.BlueprintPreviewWiring.UsedBy
