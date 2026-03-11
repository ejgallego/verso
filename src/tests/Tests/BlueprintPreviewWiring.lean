/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.Blueprint.Support

namespace Verso.Tests.BlueprintPreviewWiring

open Verso
open Verso.Genre.Manual
open Informal
open Verso.Tests.Blueprint.Support

set_option doc.verso true

private def manualImpls : ExtensionImpls := extension_impls%

tex_prelude r#"
\newcommand{\previewmacro}{\mathsf{Preview}}
"#

#docs (Genre.Manual) previewWiringDoc "Blueprint Preview Wiring" :=
:::::::
:::definition "def:preview.base"
Base statement using $`\previewmacro` in summary and graph previews.
:::

:::lemma_ "lem:preview.next"
Depends on {uses "def:preview.base"}[].
:::

{blueprint_graph}

{bp_summary}
:::::::

#docs (Genre.Manual) usedByPreviewDoc "Blueprint Used-By Preview Wiring" :=
:::::::
:::definition "def:used.target"
Target statement with associated Lean code.
:::

```lean "def:used.target"
def usedByPreviewTarget : Nat := 0
```

:::lemma_ "lem:used.statement"
Statement depends on {uses "def:used.target"}[].
:::

:::theorem "thm:used.proof"
Separate theorem with a proof-only dependency.
:::

:::proof "thm:used.proof"
Proof depends on {uses "def:used.target"}[].
:::
:::::::

#docs (Genre.Manual) usedBySinglePreviewDoc "Blueprint Used-By Single Preview Wiring" :=
:::::::
:::definition "def:used.single"
Target statement with exactly one reverse dependency.
:::

:::lemma_ "lem:used.single.next"
Statement depends on {uses "def:used.single"}[].
:::
:::::::

#docs (Genre.Manual) leanStatusChipDoc "Blueprint Lean Status Chip Wiring" :=
:::::::
:::definition "def:status.proved"
Statement with proved Lean code.
:::

```lean "def:status.proved"
def previewStatusProved : Nat := 0
```

:::definition "def:status.sorry"
Statement with Lean code containing sorry.
:::

```lean "def:status.sorry"
theorem previewStatusSorry : True := by
  sorry
```

:::definition "def:status.axiom"
Statement with axiom-like Lean code.
:::

```lean "def:status.axiom"
axiom previewStatusAxiom : True
```

:::definition "def:status.none"
Statement without Lean code.
:::
:::::::

#docs (Genre.Manual) leanCodeLinkPreviewDoc "Blueprint Lean Code Link Preview Wiring" :=
:::::::
:::definition "def:code.preview" (lean := "Nat.add")
Statement with an associated Lean declaration link in the summary.
:::

{bp_summary}
:::::::

#docs (Genre.Manual) groupPreviewDoc "Blueprint Group Preview Wiring" :=
:::::::
:::group "grp:preview"
Preview group title.
:::

:::definition "def:group.target" (parent := "grp:preview")
Target statement in a declared group.
:::

:::lemma_ "lem:group.peer.one" (parent := "grp:preview")
First peer in the same group.
:::

:::lemma_ "lem:group.peer.two" (parent := "grp:preview")
Second peer in the same group.
:::

:::lemma_ "lem:group.user"
Statement depends on {uses "def:group.target"}[].
:::
:::::::

#docs (Genre.Manual) missingGroupPreviewDoc "Blueprint Missing Group Preview Wiring" :=
:::::::
:::definition "def:group.missing.target" (parent := "grp:missing")
Target statement in an undeclared group.
:::

:::lemma_ "lem:group.missing.peer" (parent := "grp:missing")
Peer statement sharing the undeclared parent.
:::
:::::::

#docs (Genre.Manual) singleDeclaredGroupDoc "Blueprint Single Declared Group Wiring" :=
:::::::
:::group "grp:solo"
Solo group title.
:::

:::definition "def:group.solo" (parent := "grp:solo")
Only entry in its declared group.
:::
:::::::

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
        hasSubstr summaryJs "bindSummaryPreview" &&
        hasSubstr previewUtilsJs "window.bpPreviewUtils" &&
        hasSubstr inlineJs "bindInlinePreview"
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

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let (out, st) ← renderManualDocHtmlStringAndState manualImpls previewWiringDoc
    let graphJs? :=
      findExtraJsContaining? st
        "function attachPreviewHandlers(graphBlock, graphContainer, previewMap, previewController, previewKeyByNodeId)"
    pure (
      hasSubstr out "bp_graph_preview" &&
      hasSubstr out "data-bp-preview-mode=\"pinned\"" &&
      hasSubstr out "data-bp-preview-placement=\"docked\"" &&
      !hasSubstr out "class=\"bp_graph_preview_store\"" &&
      !hasSubstr out "class=\"bp_graph_preview_tpl\"" &&
      hasSubstr out "class=\"bp_group_hover_preview\"" &&
      hasSubstr out "aria-label=\"Close group preview\"" &&
      hasSubstr out "class=\"bp-graph-variants\"" &&
      hasSubstr out "data-bp-tex-prelude" &&
      !hasSubstr out "bp_preview_tex_prelude" &&
      match graphJs? with
      | some graphJs =>
        hasSubstr graphJs "attachPreviewHandlers" &&
        hasSubstr graphJs "layoutGraphCanvas" &&
        hasSubstr graphJs "syncLegend"
      | none => false
    )

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

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let out ← renderManualDocHtmlString manualImpls leanStatusChipDoc
    pure (
      hasSubstr out "bp_code_link_status_proved" &&
      hasSubstr out "bp_code_link_status_warning" &&
      hasSubstr out "bp_code_link_status_axiom" &&
      hasSubstr out "bp_code_link_status_absent" &&
      hasSubstr out ">✓</span>" &&
      hasSubstr out ">⚠</span>" &&
      hasSubstr out ">A</span>" &&
      hasSubstr out ">X</span>"
    )

end Verso.Tests.BlueprintPreviewWiring
