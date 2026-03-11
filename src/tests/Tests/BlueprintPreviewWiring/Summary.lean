/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintPreviewWiring.Shared

namespace Verso.Tests.BlueprintPreviewWiring.Summary

open Informal
open Verso.Tests.Blueprint.Support
open Verso.Tests.BlueprintPreviewWiring.Shared

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let (out, st) ← renderManualDocHtmlStringAndState manualImpls previewWiringDoc
    let summaryJs? := findExtraJsContaining? st "function bindSummaryPreview(root)"
    let previewUtilsJs? := findExtraJsContaining? st "window.bpPreviewUtils = {"
    let inlineJs? := findExtraJsContaining? st "function bindInlinePreview()"
    pure (
      !hasSubstr out "class=\"bp_summary_preview_store\"" &&
      !hasSubstr out "class=\"bp_summary_preview_tpl\"" &&
      !hasSubstr out "class=\"bp_label_preview_tpl\"" &&
      hasSubstr out "bp_summary_preview_panel" &&
      hasSubstr out "data-bp-preview-mode=\"hover\"" &&
      hasSubstr out "data-bp-preview-placement=\"anchored\"" &&
      hasSubstr out "bp_summary_preview_wrap_active" &&
      hasSubstr out "data-bp-preview-key=\"«def:preview.base»--statement\"" &&
      hasSubstr out "data-bp-tex-prelude" &&
      hasSubstr out "\\newcommand{\\previewmacro}{\\mathsf{Preview}}" &&
      !hasSubstr out "bp_preview_tex_prelude" &&
      !hasSubstr out "verso-tex-prelude" &&
      match summaryJs?, previewUtilsJs?, inlineJs? with
      | some summaryJs, some previewUtilsJs, some inlineJs =>
        hasSubstr summaryJs "previewUtils.bindTemplatePreview({" &&
        hasSubstr summaryJs "allowSharedManifest: true" &&
        hasSubstr summaryJs "templateSelector: \"template.bp_summary_preview_tpl[data-bp-preview-label]\"" &&
        hasSubstr summaryJs "triggerSelector: \".bp_summary_preview_wrap_active[data-bp-preview-label]\"" &&
        hasSubstr summaryJs "readTitle: function (_wrap, label) { return label; }" &&
        hasSubstr previewUtilsJs "function positionAnchoredPanel(panel, anchor, margin, offset)" &&
        hasSubstr previewUtilsJs "function shouldKeepOpen(nextTarget, trigger, panel)" &&
        hasSubstr previewUtilsJs "function readPanelBehavior(panel, defaults)" &&
        hasSubstr previewUtilsJs "function configureCloseButton(closeButton, onClose, behavior)" &&
        !hasSubstr previewUtilsJs "function readSharedPreviewEntryByLabel(label)" &&
        hasSubstr previewUtilsJs "function statementPreviewKey(label)" &&
        hasSubstr previewUtilsJs "function loadSharedPreviewEntry(previewKey)" &&
        hasSubstr previewUtilsJs "function hydratePreviewSubtree(root)" &&
        hasSubstr previewUtilsJs "window.setTimeout(function () {" &&
        hasSubstr inlineJs "bp-inline-preview-child-panel" &&
        hasSubstr inlineJs "function cancelChildHide()" &&
        hasSubstr inlineJs "function showChildFromTrigger(trigger)" &&
        hasSubstr inlineJs "triggerInsidePanel = panel.contains(trigger) || childPanel.contains(trigger)" &&
        hasSubstr inlineJs "behavior: makeBehavior(\"hover\", \"anchored\")" &&
        !appearsBefore inlineJs "previewUtils.loadSharedPreviewManifest();" "const store = ensureInlinePreviewStore();"
      | _, _, _ => false
    )

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let (out, st) ← renderManualDocHtmlStringAndState manualImpls leanCodeLinkPreviewDoc
    let inlineJs? := findExtraJsContaining? st "function bindInlinePreview()"
    let previewKey := Informal.LeanCodePreview.lookupKey `Nat.add
    pure (
      countSubstr out s!"data-bp-preview-key=\"{previewKey}\"" >= 1 &&
      !hasSubstr out s!"data-bp-preview-key=\"{previewKey}\" data-bp-preview-fallback-label=" &&
      hasSubstr out "class=\"bp_summary_decl_list\"" &&
      hasSubstr out "class=\"bp_inline_preview_ref\"" &&
      hasSubstr out "Nat.add</code>" &&
      !hasSubstr out "Lean code:" &&
      hasExtraCss st ".bp_inline_preview_panel" &&
      match inlineJs? with
      | some inlineJs =>
        hasSubstr inlineJs "const triggerSelector = \".bp_inline_preview_ref[data-bp-preview-id]\"" &&
        hasSubstr inlineJs "function fallbackInlinePreviewHtml(trigger, key)"
      | none => false
    )

end Verso.Tests.BlueprintPreviewWiring.Summary
