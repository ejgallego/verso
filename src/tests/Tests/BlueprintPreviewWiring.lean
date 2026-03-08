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

private def appearsBefore (s lhs rhs : String) : Bool :=
  match s.splitOn lhs with
  | _ :: tail => hasSubstr (String.intercalate lhs tail) rhs
  | [] => false

private def findExtraJs (st : TraverseState) (needle : String) : Option String :=
  st.toHtmlAssets.extraJs.toArray.findSome? fun js =>
    if hasSubstr js.js needle then some js.js else none

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let blocks := collectBlocks previewWiringDoc.toPart
    let (html, st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
    let summaryJs? := findExtraJs st "function bindSummaryPreview(root)"
    let previewUtilsJs? := findExtraJs st "window.bpPreviewUtils = {"
    pure (
      hasSubstr out "class=\"bp_summary_preview_tpl\"" &&
      hasSubstr out "class=\"bp_summary_preview_panel\"" &&
      hasSubstr out "data-bp-preview-mode=\"hover\"" &&
      hasSubstr out "data-bp-preview-placement=\"anchored\"" &&
      hasSubstr out "bp_summary_preview_wrap_active" &&
      hasSubstr out "data-bp-tex-prelude" &&
      hasSubstr out "\\newcommand{\\previewmacro}{\\mathsf{Preview}}" &&
      !hasSubstr out "bp_preview_tex_prelude" &&
      !hasSubstr out "verso-tex-prelude" &&
      match summaryJs?, previewUtilsJs? with
      | some summaryJs, some previewUtilsJs =>
        hasSubstr summaryJs "previewUtils.readPanelBehavior(panel, { mode: \"hover\", placement: \"anchored\" })" &&
        hasSubstr summaryJs "previewUtils.positionAnchoredPanel(panel, anchor, 12, 10)" &&
        hasSubstr summaryJs "previewUtils.shouldKeepOpen(ev.relatedTarget, wrap, panel)" &&
        hasSubstr summaryJs "previewUtils.configureCloseButton(close, hidePanel, behavior)" &&
        hasSubstr previewUtilsJs "function positionAnchoredPanel(panel, anchor, margin, offset)" &&
        hasSubstr previewUtilsJs "function shouldKeepOpen(nextTarget, trigger, panel)" &&
        hasSubstr previewUtilsJs "function readPanelBehavior(panel, defaults)" &&
        hasSubstr previewUtilsJs "function configureCloseButton(closeButton, onClose, behavior)"
      | _, _ => false
    )

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let blocks := collectBlocks previewWiringDoc.toPart
    let (html, st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
    let graphJs? := findExtraJs st "function attachPreviewHandlers(graphContainer, panel, previewMap, panelBehavior)"
    pure (
      hasSubstr out "class=\"bp_graph_preview\"" &&
      hasSubstr out "data-bp-preview-mode=\"pinned\"" &&
      hasSubstr out "data-bp-preview-placement=\"docked\"" &&
      hasSubstr out "class=\"bp_graph_preview_tpl\"" &&
      hasSubstr out "class=\"bp_group_hover_preview\"" &&
      hasSubstr out "data-bp-preview-placement=\"anchored\"" &&
      hasSubstr out "class=\"bp-graph-variants\"" &&
      hasSubstr out "data-bp-tex-prelude" &&
      !hasSubstr out "bp_preview_tex_prelude" &&
      match graphJs? with
      | some graphJs =>
        hasSubstr graphJs "return utils.readPreviewTemplate(entry);" &&
        hasSubstr graphJs "previewUtils.readPanelBehavior(previewPanelNode, { mode: \"pinned\", placement: \"docked\" })" &&
        hasSubstr graphJs "previewUtils.configureCloseButton(" &&
        hasSubstr graphJs "previewPanelBehavior" &&
        hasSubstr graphJs "attachPreviewHandlers(graphContainer, previewPanelNode, previewMap, previewPanelBehavior)" &&
        hasSubstr graphJs "previewUtils.configureCloseButton(groupHoverClose, hideGroupHoverPreview, groupHoverBehavior)"
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
      hasSubstr out "class=\"bp_extra_slot bp_extra_slot_used_by\"" &&
      hasSubstr out "class=\"bp_used_by_wrap\"" &&
      hasSubstr out "class=\"bp_used_by_panel\"" &&
      hasSubstr out "class=\"bp_used_by_preview_tpl\"" &&
      hasSubstr out "data-bp-used-preview-id" &&
      hasSubstr out ">statement</span>" &&
      hasSubstr out ">proof</span>" &&
      appearsBefore out "class=\"bp_code_link_wrap\"" "class=\"bp_used_by_wrap\"" &&
      match usedByJs? with
      | some usedByJs =>
        hasSubstr usedByJs "function bindUsedByPanel(panel)" &&
        hasSubstr usedByJs "item.addEventListener(\"mouseenter\"" &&
        hasSubstr usedByJs "item.addEventListener(\"focusin\"" &&
        hasSubstr usedByJs "activate(items[0])"
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
      hasSubstr out "class=\"bp_inline_preview_tpl\"" &&
      hasSubstr out "data-bp-preview-id=\"bp-used-by-"
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
