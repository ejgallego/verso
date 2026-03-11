/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintPreviewWiring.Shared

namespace Verso.Tests.BlueprintPreviewWiring.Graph

open Verso.Tests.Blueprint.Support
open Verso.Tests.BlueprintPreviewWiring.Shared

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

end Verso.Tests.BlueprintPreviewWiring.Graph
