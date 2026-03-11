/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import VersoBlueprint
import VersoManual

namespace Verso.Tests.BlueprintPreviewWiring

open Verso
open Verso.Genre.Manual
open Informal

set_option doc.verso true

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
:::definition "def:code.preview"
Statement with associated Lean code and summary actions.
:::

```lean "def:code.preview"
def previewCodeLinkTarget : Nat := 0
```

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

private partial def collectBlocks (part : Doc.Part Genre.Manual) : Array (Doc.Block Genre.Manual) :=
  let childBlocks := part.subParts.foldl (init := #[]) fun acc child =>
    acc ++ collectBlocks child
  part.content ++ childBlocks

private def initTraverseState (impls : ExtensionImpls) : TraverseState :=
  Id.run do
    let mut st : TraverseState := TraverseState.initialize {}
    for ⟨_, b⟩ in impls.blockDescrs do
      if let some descr := b.get? BlockDescr then
        st := descr.init st
    for ⟨_, i⟩ in impls.inlineDescrs do
      if let some descr := i.get? InlineDescr then
        st := descr.init st
    return st

private def traverseManualBlocks
    (blocks : Array (Doc.Block Genre.Manual))
    (impls : ExtensionImpls) :
    IO (Array (Doc.Block Genre.Manual) × TraverseState) := do
  let ctxt : TraverseContext := { logError := fun _ => pure () }
  let mut st := initTraverseState impls
  let mut cur := blocks
  for _ in [0:4] do
    let (next, st') ← TraverseM.run impls ctxt st <| cur.mapM Verso.Genre.Manual.traverseBlock
    if next == cur && st' == st then
      return (next, st')
    cur := next
    st := st'
  return (cur, st)

private def renderManualBlocksHtmlAndState
    (blocks : Array (Doc.Block Genre.Manual)) : IO (Output.Html × TraverseState) := do
  let impls : ExtensionImpls := extension_impls%
  let opts : Doc.Html.Options (ReaderT Multi.AllRemotes (ReaderT ExtensionImpls IO)) := {
    headerLevel := 1
    logError := fun _ => pure ()
  }
  let (blocks, st) ← traverseManualBlocks blocks impls
  let ctxt : TraverseContext := { logError := fun _ => pure () }
  let definitionIds : Lean.NameMap String := {}
  let linkTargets : Code.LinkTargets TraverseContext := {}
  let codeOptions : Code.HighlightHtmlM.Options := {}
  let remotes : Multi.AllRemotes := {}
  let block := Doc.Block.concat blocks
  let htmlState := Verso.Genre.Manual.toHtml opts ctxt st definitionIds linkTargets codeOptions block
  let (html, _hover) ← ((htmlState.run {}).run remotes).run impls
  pure (html, st)

private def hasSubstr (s needle : String) : Bool :=
  (s.splitOn needle).length > 1

private def countSubstr (s needle : String) : Nat :=
  (s.splitOn needle).length.pred

private def appearsBefore (s lhs rhs : String) : Bool :=
  match s.splitOn lhs with
  | _ :: tail => hasSubstr (String.intercalate lhs tail) rhs
  | [] => false

private def findExtraJs (st : TraverseState) (needle : String) : Option String :=
  st.toHtmlAssets.extraJs.toArray.findSome? fun js =>
    if hasSubstr js.js needle then some js.js else none

private def hasExtraCss (st : TraverseState) (needle : String) : Bool :=
  st.toHtmlAssets.extraCss.toArray.any fun css => hasSubstr css.css needle

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let blocks := collectBlocks previewWiringDoc.toPart
    let (html, st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
    let summaryJs? := findExtraJs st "function bindSummaryPreview(root)"
    let previewUtilsJs? := findExtraJs st "window.bpPreviewUtils = {"
    let inlineJs? := findExtraJs st "function bindInlinePreview()"
    pure (
      !hasSubstr out "class=\"bp_summary_preview_store\"" &&
      !hasSubstr out "class=\"bp_summary_preview_tpl\"" &&
      !hasSubstr out "class=\"bp_label_preview_tpl\"" &&
      hasSubstr out "class=\"bp_summary_preview_panel\"" &&
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
    let blocks := collectBlocks leanCodeLinkPreviewDoc.toPart
    let (html, st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
    let inlineJs? := findExtraJs st "function bindInlinePreview()"
    pure (
      countSubstr out "data-bp-preview-key=\"«def:code.preview»--code\"" >= 1 &&
      !hasSubstr out "data-bp-preview-key=\"«def:code.preview»--code\" data-bp-preview-fallback-label=" &&
      hasSubstr out ">L∃∀N</span>" &&
      hasSubstr out ">code</a>" &&
      hasSubstr out "class=\"bp_code_link_wrap\"" &&
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
    let blocks := collectBlocks previewWiringDoc.toPart
    let (html, st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
    let graphJs? := findExtraJs st "function attachPreviewHandlers(graphBlock, graphContainer, previewMap, previewController, previewKeyByNodeId)"
    pure (
      hasSubstr out "class=\"bp_graph_preview\"" &&
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
        hasSubstr graphJs "return utils.readPreviewTemplate(entry);" &&
        hasSubstr graphJs "function layoutGraphCanvas(graphRoot)" &&
        hasSubstr graphJs "function ensureGraphBlockState(graphBlock)" &&
        hasSubstr graphJs "function createPanelController(panel, behavior, titleSelector, bodySelector, options)" &&
        hasSubstr graphJs "function bindHoverablePanelLifetime(previewUtils, controller, getActiveAnchor, boundAttr)" &&
        hasSubstr graphJs "function configurePanelCloseButton(previewUtils, closeButton, hidePanel, behavior)" &&
        hasSubstr graphJs "const previewKey = nodeId ? (previewKeys.get(nodeId) || \"\") : \"\";" &&
        hasSubstr graphJs "previewUtils.loadSharedPreviewEntry(previewKey)" &&
        hasSubstr graphJs "previewUtils.readPanelBehavior(previewPanelNode, { mode: \"pinned\", placement: \"docked\" })" &&
        hasSubstr graphJs "previewUtils.hydratePreviewSubtree(body)" &&
        hasSubstr graphJs "previewUtils.readPanelBehavior(groupHoverPanel, { mode: \"pinned\", placement: \"docked\" })" &&
        hasSubstr graphJs "attachPreviewHandlers(graphBlock, graphContainer, previewMap, previewController, previewKeyByNodeId)" &&
        hasSubstr graphJs "graphState.previewActiveNode === node && !previewController.panel.hidden" &&
        hasSubstr graphJs "configurePanelCloseButton(previewUtils, previewClose" &&
        hasSubstr graphJs "configurePanelCloseButton(previewUtils, groupHoverClose" &&
        hasSubstr graphJs "previewKeyByNodeId: new Map(previewKeyByNodeId)" &&
        hasSubstr graphJs "graphviz: null," &&
        hasSubstr graphJs "renderToken: 0," &&
        hasSubstr graphJs "const finalizeRender = function () {" &&
        hasSubstr graphJs "if (graphState.renderToken !== renderToken) return;" &&
        hasSubstr graphJs "const gv = graphState.graphviz || graphContainer.graphviz();" &&
        hasSubstr graphJs ".zoom(true)" &&
        hasSubstr graphJs "const padX = variantKey === \"full\" ? 40 : 24;" &&
        hasSubstr graphJs "const zoomFactor = Math.min(1, targetScale / fitScale);" &&
        hasSubstr graphJs "syncLegend(graphBlock, activeKey)"
      | none => false
    )

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let blocks := collectBlocks usedByPreviewDoc.toPart
    let (html, st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
    let usedByJs? := findExtraJs st "function bindUsedByPanel(panel)"
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
    let blocks := collectBlocks usedBySinglePreviewDoc.toPart
    let (html, _st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
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
    let blocks := collectBlocks groupPreviewDoc.toPart
    let (html, st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
    let usedByJs? := findExtraJs st "function bindUsedByPanel(panel)"
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
    let blocks := collectBlocks missingGroupPreviewDoc.toPart
    let (html, _st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
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
    let blocks := collectBlocks singleDeclaredGroupDoc.toPart
    let (html, _st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
    pure (
      !hasSubstr out "class=\"bp_extra_slot bp_extra_slot_group\"" &&
      !hasSubstr out "bp_used_by_chip_warn" &&
      !hasSubstr out "data-bp-used-preview-id=\"bp-group-"
    )

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let blocks := collectBlocks leanStatusChipDoc.toPart
    let (html, _st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
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
