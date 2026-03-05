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

#docs (Genre.Manual) previewWiringDoc "Blueprint Preview Wiring" :=
:::::::
:::definition "def:preview.base"
Base statement used by summary and graph previews.
:::

:::lemma_ "lem:preview.next"
Depends on {uses "def:preview.base"}[].
:::

{blueprint_graph}

{bp_summary}
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
    let graphJs? := findExtraJs st "function attachPreviewHandlers(graphContainer, previewMap, panelBehavior)"
    pure (
      hasSubstr out "id=\"bp-graph-preview\"" &&
      hasSubstr out "data-bp-preview-mode=\"pinned\"" &&
      hasSubstr out "data-bp-preview-placement=\"docked\"" &&
      hasSubstr out "class=\"bp_graph_preview_tpl\"" &&
      hasSubstr out "id=\"bp-group-hover-preview\"" &&
      hasSubstr out "data-bp-preview-placement=\"anchored\"" &&
      hasSubstr out "class=\"bp-graph-variants\"" &&
      match graphJs? with
      | some graphJs =>
        hasSubstr graphJs "return utils.readPreviewTemplate(entry);" &&
        hasSubstr graphJs "previewUtils.readPanelBehavior(previewPanelNode, { mode: \"pinned\", placement: \"docked\" })" &&
        hasSubstr graphJs "previewUtils.configureCloseButton(previewClose, hidePreviewPanel, previewPanelBehavior)" &&
        hasSubstr graphJs "previewUtils.configureCloseButton(groupHoverClose, hideGroupHoverPreview, groupHoverBehavior)"
      | none => false
    )

end Verso.Tests.BlueprintPreviewWiring
