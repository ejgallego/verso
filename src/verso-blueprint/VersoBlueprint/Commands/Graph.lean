/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Commands.Common
import VersoBlueprint.Environment
import VersoBlueprint.Graph
import VersoBlueprint.Lib.HoverRender
import VersoBlueprint.Lib.PreviewSource
import VersoBlueprint.Resolve
import VersoBlueprint.StyleSwitcher

namespace Informal.Commands

open Lean Elab Command
open Informal Data Environment

abbrev GraphNode := Informal.Graph.GraphNode Name
abbrev Graph := Informal.Graph.Graph Name

inductive GraphDirection where
  | LR
  | RL
  | TB
  | BT
deriving Inhabited, Repr, BEq, FromJson, ToJson, Quote

def GraphDirection.rankdir : GraphDirection → String
  | .LR => "LR"
  | .RL => "RL"
  | .TB => "TB"
  | .BT => "BT"

def GraphDirection.parse? (s : String) : Option GraphDirection :=
  match s.toLower with
  | "lr" | "left-right" | "horizontal" => some .LR
  | "rl" | "right-left" => some .RL
  | "tb" | "top-bottom" | "vertical" => some .TB
  | "bt" | "bottom-top" => some .BT
  | _ => none

register_option verso.blueprint.graph.defaultDirection : String := {
  defValue := "TB"
  descr := "Default direction for `blueprint_graph` when `(direction := ...)` is omitted (LR, RL, TB, BT)"
}

structure GraphBlockData where
  graph : Graph
  direction : GraphDirection := .TB
  groupTitles : Array (Name × String) := #[]
deriving Inhabited, FromJson, ToJson, Quote

def graphDotHeader (rankdir : String) : String :=
  "strict digraph \"\" {\n" ++
  s!"    rankdir={rankdir};\n" ++
  "    bgcolor=\"white\";\n" ++
  "    splines=true;\n" ++
  "    nodesep=0.35;\n" ++
  "    ranksep=0.45;\n" ++
  "    node [shape=box, style=\"rounded,filled\", fontname=\"Helvetica\", fontsize=10, margin=\"0.08,0.04\", color=\"#6b7280\", penwidth=1.8];\n" ++
  "    edge [color=\"#6b7280\", arrowhead=vee, arrowsize=0.6, penwidth=1];\n" ++
  "    graph [fontname=\"Helvetica\"];\n" ++
  "  "

def graphToDot (g : Graph) (direction : GraphDirection := .TB)
    (resolveHref : Name → Option String := fun _ => none)
    (resolveGroupTitle : Name → Option String := fun _ => none) : String :=
  Informal.Graph.Graph.toDot g (graphDotHeader direction.rankdir)
    (groupLabel? := some resolveGroupTitle)
    (refAttrs? := some fun ref =>
    (resolveHref ref).map (fun href => s!"URL=\"{href}\", target=\"_self\""))

structure GraphRenderVariant where
  key : String
  label : String
  dot : String
  selectOnNode : Array (String × String) := #[]
  hoverOnNode : Array (String × String) := #[]
deriving Inhabited, ToJson

def graphCss := include_str "graph.css"

def groupVariantKey : String := "group"
def parentVariantKey (parent : Name) : String := s!"parent:{parent}"

def graphParentChildren (graph : Graph) : Lean.NameMap (Array Name) :=
  graph.foldl (init := ({} : Lean.NameMap (Array Name))) fun acc node =>
    match node.parent? with
    | none => acc
    | some parent =>
      let children := acc.getD parent #[]
      acc.insert parent (children.push node.label)

def graphNodeParents (graph : Graph) : Lean.NameMap Name :=
  graph.foldl (init := ({} : Lean.NameMap Name)) fun acc node =>
    match node.parent? with
    | none => acc
    | some parent => acc.insert node.label parent

def graphParentTitle (groupTitles : Lean.NameMap String) (parent : Name) : String :=
  let title := (groupTitles.getD parent parent.toString).trimAscii.toString
  if title.isEmpty then parent.toString else title

def hexNibble? (c : Char) : Option Nat :=
  match c with
  | '0' => some 0
  | '1' => some 1
  | '2' => some 2
  | '3' => some 3
  | '4' => some 4
  | '5' => some 5
  | '6' => some 6
  | '7' => some 7
  | '8' => some 8
  | '9' => some 9
  | 'a' | 'A' => some 10
  | 'b' | 'B' => some 11
  | 'c' | 'C' => some 12
  | 'd' | 'D' => some 13
  | 'e' | 'E' => some 14
  | 'f' | 'F' => some 15
  | _ => none

def parseHexByte? (c1 c2 : Char) : Option Nat := do
  let hi ← hexNibble? c1
  let lo ← hexNibble? c2
  return hi * 16 + lo

def parseHexColor? (s : String) : Option (Nat × Nat × Nat) := do
  let chars :=
    match s.trimAscii.toString.toList with
    | '#' :: rest => rest
    | xs => xs
  match chars with
  | r1 :: r2 :: g1 :: g2 :: b1 :: b2 :: [] =>
    return (← parseHexByte? r1 r2, ← parseHexByte? g1 g2, ← parseHexByte? b1 b2)
  | _ => none

def hexChar (n : Nat) : Char :=
  if n < 10 then
    Char.ofNat ('0'.toNat + n)
  else
    Char.ofNat ('a'.toNat + (n - 10))

def byteToHex (n : Nat) : String :=
  let n := n % 256
  let hi := n / 16
  let lo := n % 16
  String.ofList [hexChar hi, hexChar lo]

def rgbToHex (r g b : Nat) : String :=
  "#" ++ byteToHex r ++ byteToHex g ++ byteToHex b

def primaryColorToken (s : String) : String :=
  match s.splitOn ":" with
  | token :: _ => token.trimAscii.toString
  | [] => s.trimAscii.toString

def averageHexColor (colors : Array (Nat × Nat × Nat)) (fallback : String) : String :=
  if colors.isEmpty then
    fallback
  else
    let (sumR, sumG, sumB) := colors.foldl (init := (0, 0, 0)) fun (r, g, b) (r', g', b') =>
      (r + r', g + g', b + b')
    let n := colors.size
    rgbToHex (sumR / n) (sumG / n) (sumB / n)

def mixedNodeColor (nodes : Array GraphNode) (colorOf : GraphNode → String) (fallback : String) : String :=
  let colors := nodes.foldl (init := (#[] : Array (Nat × Nat × Nat))) fun acc node =>
    match parseHexColor? (primaryColorToken (colorOf node)) with
    | some rgb => acc.push rgb
    | Option.none => acc
  averageHexColor colors fallback

def fontColorForFill (fillColor : String) : String :=
  match parseHexColor? fillColor with
  | some (r, g, b) =>
    -- Relative luminance approximation, keeps labels readable on dark mixes.
    if (299 * r + 587 * g + 114 * b) < 140000 then "#f8fafc" else "#0f172a"
  | Option.none => "#0f172a"

def nodeHasAncestorParent (parentMap : Lean.NameMap Name) (label ancestor : Name) : Bool :=
  Id.run <| do
    let mut current := label
    let mut seen : Lean.NameSet := {}
    let mut fuel := parentMap.toArray.size + 1
    while fuel > 0 do
      fuel := fuel - 1
      match parentMap.get? current with
      | none => return false
      | some parent =>
        if parent == ancestor then
          return true
        if seen.contains parent then
          return false
        seen := seen.insert parent
        current := parent
    return false

def subgraphForParent (graph : Graph) (parent : Name) : Graph :=
  let parentMap := graphNodeParents graph
  graph.filter fun node =>
    node.label == parent || nodeHasAncestorParent parentMap node.label parent

def mkParentOverviewGraph (graph : Graph) (parents : Array Name)
    (groupTitles : Lean.NameMap String) : Graph :=
  let parentChildren := graphParentChildren graph
  let nodeByLabel : Lean.NameMap GraphNode :=
    graph.foldl (init := ({} : Lean.NameMap GraphNode)) fun acc node =>
      acc.insert node.label node
  let parentSet : Lean.NameSet :=
    parents.foldl (init := ({} : Lean.NameSet)) fun acc parent => acc.insert parent
  let parentMap := graphNodeParents graph
  let addParentDep (acc : Lean.NameMap (Array Name)) (target source : Name) : Lean.NameMap (Array Name) :=
    let deps := acc.getD target #[]
    if deps.contains source then
      acc
    else
      acc.insert target (deps.push source)
  let parentDeps :=
    graph.foldl (init := ({} : Lean.NameMap (Array Name))) fun acc node =>
      match node.parent? with
      | none => acc
      | some target =>
        if !parentSet.contains target then
          acc
        else
          (node.deps ++ node.proofDeps).foldl (init := acc) fun acc dep =>
            match parentMap.get? dep with
            | some source =>
              if parentSet.contains source && source != target then
                addParentDep acc target source
              else
                acc
            | none => acc
  parents.map fun parent =>
    let childNodes :=
      (parentChildren.getD parent #[]).foldl (init := (#[] : Array GraphNode)) fun acc child =>
        match nodeByLabel.get? child with
        | some node => acc.push node
        | Option.none => acc
    let mixedFillColor := mixedNodeColor childNodes (·.fillcolor) "#e2e8f0"
    let mixedBorderColor := mixedNodeColor childNodes (·.color) "#475569"
    {
      label := parent
      deps := parentDeps.getD parent #[]
      proofDeps := #[]
      shape := "diamond"
      style := "filled"
      fillcolor := mixedFillColor
      color := mixedBorderColor
      penwidth := "2.3"
      fontcolor := fontColorForFill mixedFillColor
      tooltip? := some s!"Group View: {graphParentTitle groupTitles parent} ({childNodes.size} nodes)"
      ref? := none
    }

def mkGraphVariants (graphData : GraphBlockData) (resolveHref : Name → Option String)
    (groupTitles : Lean.NameMap String) : Array GraphRenderVariant :=
  let resolveGroupTitle : Name → Option String := fun group =>
    groupTitles.get? group
  let parentChildren := graphParentChildren graphData.graph
  let parents :=
    parentChildren.toArray
      |>.filter (fun (_, children) => children.size > 1)
      |>.map (·.1)
      |>.qsort (fun a b => graphParentTitle groupTitles a < graphParentTitle groupTitles b)
  if parents.isEmpty then
    #[{
      key := "full"
      label := "Full Graph"
      dot := graphToDot graphData.graph graphData.direction resolveHref resolveGroupTitle
      selectOnNode := #[]
      hoverOnNode := #[]
    }]
  else
    let parentVariantRefs := parents.map (fun parent => (toString parent, parentVariantKey parent))
    let groupVariant : GraphRenderVariant := {
      key := groupVariantKey
      label := "Group View"
      dot := graphToDot (mkParentOverviewGraph graphData.graph parents groupTitles)
        graphData.direction (fun _ => none) (fun _ => none)
      selectOnNode := parentVariantRefs
      hoverOnNode := parentVariantRefs
    }
    let fullVariant : GraphRenderVariant := {
      key := "full"
      label := "Full Graph"
      dot := graphToDot graphData.graph graphData.direction resolveHref resolveGroupTitle
      selectOnNode := #[]
      hoverOnNode := #[]
    }
    let parentVariants := parents.map fun parent =>
      let title := graphParentTitle groupTitles parent
      {
        key := parentVariantKey parent
        label := title
        dot := graphToDot (subgraphForParent graphData.graph parent)
          graphData.direction resolveHref resolveGroupTitle
        selectOnNode := #[]
        hoverOnNode := #[]
      }
    #[fullVariant, groupVariant] ++ parentVariants

def loadD3Dot :=
  r##"(function () {
    function debounce(fn, waitMs) {
      let timeout = null;
      return function () {
        const args = arguments;
        clearTimeout(timeout);
        timeout = setTimeout(function () {
          fn.apply(null, args);
        }, waitMs);
      };
    }

    function layoutGraphBlock(graphBlock) {
      if (!graphBlock) return;

      graphBlock.style.left = "0px";
      graphBlock.style.width = "auto";
      graphBlock.style.maxWidth = "none";

      const main = document.querySelector(".with-toc > main");
      const blockRect = graphBlock.getBoundingClientRect();
      let left = 0;
      let right = window.innerWidth;

      if (main) {
        const mainRect = main.getBoundingClientRect();
        const mainStyle = window.getComputedStyle(main);
        const padLeft = parseFloat(mainStyle.paddingLeft) || 0;
        const padRight = parseFloat(mainStyle.paddingRight) || 0;
        left = mainRect.left + padLeft;
        right = mainRect.right - padRight;
      }

      const width = Math.max(320, right - left);
      const shift = left - blockRect.left;

      graphBlock.style.left = shift + "px";
      graphBlock.style.width = width + "px";
      graphBlock.style.maxWidth = width + "px";
    }

    function load(src) {
      return new Promise(function (resolve, reject) {
        const s = document.createElement("script");
        s.src = src;
        s.onload = resolve;
        s.onerror = reject;
        document.head.appendChild(s);
      });
    }

    function collectPreviewTemplates(rootNode) {
      const utils = window.bpPreviewUtils;
      if (!utils || typeof utils.collectPreviewTemplates !== "function") {
        return new Map();
      }
      return utils.collectPreviewTemplates(
        rootNode || document,
        "template.bp_graph_preview_tpl[data-bp-preview-label]"
      );
    }

    function collectGraphVariants(graphContainer) {
      const payloadNode = graphContainer.select("script.bp-graph-variants").node();
      if (payloadNode) {
        try {
          const parsed = JSON.parse((payloadNode.textContent || "").trim());
          if (Array.isArray(parsed) && parsed.length > 0) {
            return parsed;
          }
        } catch (_err) {}
      }
      const dotTxt = graphContainer.select("script.dot-source").text().trim();
      if (!dotTxt) return [];
      return [{ key: "full", label: "Full Graph", dot: dotTxt, selectOnNode: [], hoverOnNode: [] }];
    }

    function hidePreviewPanel(panel) {
      if (!panel) return;
      const title = panel.querySelector(".bp_graph_preview_title");
      const body = panel.querySelector(".bp_graph_preview_body");
      panel.hidden = true;
      if (title) title.textContent = "";
      if (body) body.innerHTML = "";
    }

    function graphNodeLabel(node) {
      if (!node) return "";
      const titleNode = node.querySelector("title");
      const titleTxt =
        titleNode && typeof titleNode.textContent === "string" ? titleNode.textContent.trim() : "";
      if (titleTxt) return titleTxt;
      const textNode = node.querySelector("text");
      const textTxt =
        textNode && typeof textNode.textContent === "string" ? textNode.textContent.trim() : "";
      return textTxt || "";
    }

    function parsePreviewEntry(entry) {
      const utils = window.bpPreviewUtils;
      if (utils && typeof utils.readPreviewTemplate === "function") {
        return utils.readPreviewTemplate(entry);
      }
      if (typeof entry === "string") {
        return { html: entry, texPrelude: "" };
      }
      if (!entry || typeof entry !== "object") {
        return { html: "", texPrelude: "" };
      }
      return {
        html: typeof entry.html === "string" ? entry.html : "",
        texPrelude: typeof entry.texPrelude === "string" ? entry.texPrelude : ""
      };
    }

    function renderMath(root, texPrelude) {
      const utils = window.bpPreviewUtils;
      if (!utils || typeof utils.renderMath !== "function") return;
      utils.renderMath(root, texPrelude);
    }

    function attachPreviewHandlers(graphContainer, panel, previewMap) {
      if (!panel) return;
      const title = panel.querySelector(".bp_graph_preview_title");
      const body = panel.querySelector(".bp_graph_preview_body");
      if (!title || !body || previewMap.size === 0) {
        hidePreviewPanel(panel);
        return;
      }
      const svg = graphContainer.select("svg").node();
      if (!svg) {
        hidePreviewPanel(panel);
        return;
      }
      const show = function (label) {
        const entry = parsePreviewEntry(previewMap.get(label));
        const html = entry.html;
        const texPrelude = entry.texPrelude;
        if (!html) return;
        title.textContent = label;
        body.innerHTML = html;
        renderMath(body, texPrelude);
        panel.hidden = false;
      };
      const nodes = svg.querySelectorAll("g.node");
      nodes.forEach(function (node) {
        const label = graphNodeLabel(node);
        if (!previewMap.has(label)) return;
        if (!label) return;
        node.style.cursor = "pointer";
        node.setAttribute("tabindex", "0");
        const titleNode = node.querySelector("title");
        if (titleNode) titleNode.remove();
        const all = [node].concat(Array.from(node.querySelectorAll("*")));
        all.forEach(function (el) {
          if (el.hasAttribute && el.hasAttribute("title")) {
            el.removeAttribute("title");
          }
          if (el.hasAttribute && el.hasAttribute("xlink:title")) {
            el.removeAttribute("xlink:title");
          }
          if (el.removeAttributeNS) {
            el.removeAttributeNS("http://www.w3.org/1999/xlink", "title");
          }
        });
      });
      const showFromTarget = function (target) {
        if (!(target instanceof Element)) return;
        const node = target.closest("g.node");
        if (!node) return;
        const label = graphNodeLabel(node);
        if (label) show(label);
      };
      if (svg.getAttribute("data-bp-preview-bound") === "1") {
        return;
      }
      svg.setAttribute("data-bp-preview-bound", "1");
      svg.addEventListener("mouseover", function (ev) {
        showFromTarget(ev.target);
      });
      svg.addEventListener("focusin", function (ev) {
        showFromTarget(ev.target);
      });
    }

    function attachVariantSelectors(graphContainer, variantsByKey, activeVariant, onSelect, onHover) {
      if (!activeVariant) {
        return;
      }
      const mapNodeTargets = function (entries) {
        const out = new Map();
        if (!Array.isArray(entries)) return out;
        entries.forEach(function (entry) {
          if (!Array.isArray(entry) || entry.length !== 2) return;
          const nodeLabel = String(entry[0] || "").trim();
          const nextKey = String(entry[1] || "").trim();
          if (!nodeLabel || !nextKey || !variantsByKey.has(nextKey)) return;
          out.set(nodeLabel, nextKey);
        });
        return out;
      };
      const selectVariantByLabel = mapNodeTargets(activeVariant.selectOnNode);
      const hoverVariantByLabel = mapNodeTargets(activeVariant.hoverOnNode);
      const svg = graphContainer.select("svg").node();
      if (!svg) return;
      const readVariantState = function () {
        const state = svg.__bpVariantState;
        if (state && state.selectVariantByLabel instanceof Map && state.hoverVariantByLabel instanceof Map) {
          return state;
        }
        return {
          selectVariantByLabel: new Map(),
          hoverVariantByLabel: new Map(),
          lastHoverLabel: ""
        };
      };
      svg.__bpVariantState = {
        selectVariantByLabel: selectVariantByLabel,
        hoverVariantByLabel: hoverVariantByLabel,
        lastHoverLabel: ""
      };

      const nodeLabel = function (node) {
        const label = graphNodeLabel(node);
        if (!label) return "";
        return label;
      };
      const nodeSelectKey = function (node) {
        const label = nodeLabel(node);
        if (!label) return "";
        const state = readVariantState();
        return state.selectVariantByLabel.get(label) || "";
      };
      const activateFromTarget = function (target, ev) {
        if (!(target instanceof Element)) return;
        const node = target.closest("g.node");
        if (!node) return;
        const nextKey = nodeSelectKey(node);
        if (!nextKey) return;
        if (ev) {
          ev.preventDefault();
          ev.stopPropagation();
        }
        onSelect(nextKey);
      };
      const hoverFromTarget = function (target) {
        if (!(target instanceof Element)) return;
        const node = target.closest("g.node");
        if (!node) return;
        const label = nodeLabel(node);
        if (!label) return;
        const state = readVariantState();
        const nextKey = state.hoverVariantByLabel.get(label) || "";
        if (!label || !nextKey) return;
        if (label === state.lastHoverLabel) return;
        state.lastHoverLabel = label;
        onHover(label, nextKey, node);
      };

      svg.querySelectorAll("g.node").forEach(function (node) {
        const selectKey = nodeSelectKey(node);
        const label = nodeLabel(node);
        const state = readVariantState();
        const hoverKey = label ? (state.hoverVariantByLabel.get(label) || "") : "";
        if (!selectKey && !hoverKey) return;
        node.style.cursor = "pointer";
        node.setAttribute("tabindex", "0");
      });
      if (svg.getAttribute("data-bp-variant-bound") === "1") {
        return;
      }
      svg.setAttribute("data-bp-variant-bound", "1");
      svg.addEventListener("click", function (ev) {
        activateFromTarget(ev.target, ev);
      });
      svg.addEventListener("keydown", function (ev) {
        if (ev.key !== "Enter" && ev.key !== " ") return;
        activateFromTarget(ev.target, ev);
      });
      svg.addEventListener("mouseover", function (ev) {
        hoverFromTarget(ev.target);
      });
      svg.addEventListener("mouseleave", function () {
        const state = readVariantState();
        state.lastHoverLabel = "";
      });
    }

    function applyGraphZoomHeuristic(graphContainer, width, height, variantKey) {
      const svg = graphContainer.select("svg").node();
      if (!svg) return;
      const graphRoot = svg.querySelector("g.graph") || svg.querySelector("g");
      if (!graphRoot || typeof graphRoot.getBBox !== "function") return;
      const bounds = graphRoot.getBBox();
      if (!bounds || !(bounds.width > 0) || !(bounds.height > 0)) return;

      const pad = 24;
      const fitScale = Math.min(
        (width - pad * 2) / bounds.width,
        (height - pad * 2) / bounds.height
      );
      if (!isFinite(fitScale) || fitScale <= 0) return;

      // Baseline cap: avoid zooming small graphs too much.
      const baselineScale = 1.0;
      const targetScale = Math.min(baselineScale, fitScale);
      if (!isFinite(targetScale) || targetScale <= 0) return;

      const viewW = width / targetScale;
      const viewH = height / targetScale;
      const centerX = bounds.x + bounds.width / 2;
      const viewX = centerX - viewW / 2;
      const topBiased = variantKey === "group" || variantKey === "full";
      const viewY = topBiased ? bounds.y - pad : bounds.y + bounds.height / 2 - viewH / 2;
      svg.setAttribute("viewBox", [viewX, viewY, viewW, viewH].join(" "));
      svg.setAttribute("preserveAspectRatio", topBiased ? "xMidYMin meet" : "xMidYMid meet");
    }

    Promise.resolve()
      .then(() => load("https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js"))
      .then(() => load("https://cdn.jsdelivr.net/npm/d3-graphviz@5.6.0/build/d3-graphviz.min.js"))
      .then(() => {
  const graphBlocks = Array.from(document.querySelectorAll(".bp_graph_fullwidth"));
  if (graphBlocks.length === 0) return;

  function initGraphBlock(graphBlock) {
    if (!(graphBlock instanceof Element)) return;
    layoutGraphBlock(graphBlock);
    const graphRoot = graphBlock.querySelector(".bp_graph_canvas");
    if (!graphRoot) return;
    const graphContainer = d3.select(graphRoot);
    if (graphContainer.empty()) return;
    const selector = graphBlock.querySelector(".bp_graph_view_select");
    const previewMap = collectPreviewTemplates(graphBlock);
    const previewPanelNode = graphBlock.querySelector(".bp_graph_preview");
    const previewClose = previewPanelNode
      ? previewPanelNode.querySelector(".bp_graph_preview_close")
      : null;
    const previewUtils = window.bpPreviewUtils;
    if (previewUtils && typeof previewUtils.bindCloseOnce === "function") {
      previewUtils.bindCloseOnce(previewClose, function () {
        hidePreviewPanel(previewPanelNode);
      });
    } else if (previewClose && previewClose.getAttribute("data-bp-bound") !== "1") {
      previewClose.setAttribute("data-bp-bound", "1");
      previewClose.addEventListener("click", function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        hidePreviewPanel(previewPanelNode);
      });
    }

    const rawVariants = collectGraphVariants(graphContainer);
    if (!Array.isArray(rawVariants) || rawVariants.length === 0) return;
    const variantsByKey = new Map();
    rawVariants.forEach(function (variant) {
      if (!variant || typeof variant !== "object") return;
      const key = String(variant.key || "").trim();
      const label = String(variant.label || key).trim();
      const dot = String(variant.dot || "").trim();
      const selectOnNode = Array.isArray(variant.selectOnNode) ? variant.selectOnNode : [];
      const hoverOnNode = Array.isArray(variant.hoverOnNode) ? variant.hoverOnNode : [];
      if (!key || !dot) return;
      variantsByKey.set(key, {
        key: key,
        label: label || key,
        dot: dot,
        selectOnNode: selectOnNode,
        hoverOnNode: hoverOnNode
      });
    });
    const variants = Array.from(variantsByKey.values());
    if (variants.length === 0) return;

    if (selector && selector.options.length === 0) {
      variants.forEach(function (variant) {
        const option = document.createElement("option");
        option.value = variant.key;
        option.textContent = variant.label;
        selector.appendChild(option);
      });
    }

    let activeKey = variantsByKey.has("full") ? "full" : variants[0].key;
    if (selector && variantsByKey.has(selector.value)) {
      activeKey = selector.value;
    }
    if (selector) selector.value = activeKey;

    const getActiveVariant = function () {
      const fallback = variantsByKey.get("full") || variants[0];
      return variantsByKey.get(activeKey) || fallback;
    };

    const groupHoverPanel = graphBlock.querySelector(".bp_group_hover_preview");
    const groupHoverTitle = groupHoverPanel
      ? groupHoverPanel.querySelector(".bp_group_hover_preview_title")
      : null;
    const groupHoverClose = groupHoverPanel
      ? groupHoverPanel.querySelector(".bp_group_hover_preview_close")
      : null;
    const groupHoverGraph = groupHoverPanel
      ? groupHoverPanel.querySelector(".bp_group_hover_preview_graph")
      : null;
    let groupHoverGraphviz = null;
    let groupHoverShownKey = "";
    let groupHoverShownLabel = "";

    const hideGroupHoverPreview = function () {
      if (!groupHoverPanel) return;
      groupHoverPanel.hidden = true;
      if (groupHoverTitle) groupHoverTitle.textContent = "";
      groupHoverShownKey = "";
      groupHoverShownLabel = "";
    };
    if (groupHoverClose) {
      groupHoverClose.addEventListener("click", function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        hideGroupHoverPreview();
      });
    }
    window.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape") {
        hideGroupHoverPreview();
        hidePreviewPanel(previewPanelNode);
      }
    });

    const positionGroupHoverPreview = function (anchorNode) {
      if (!groupHoverPanel || !(anchorNode instanceof Element)) return;
      const blockRect = graphBlock.getBoundingClientRect();
      const nodeRect = anchorNode.getBoundingClientRect();
      const panelRect = groupHoverPanel.getBoundingClientRect();
      const gap = 10;

      let left = nodeRect.right - blockRect.left + gap;
      if (left + panelRect.width > blockRect.width - gap) {
        left = nodeRect.left - blockRect.left - panelRect.width - gap;
      }
      let top = nodeRect.top - blockRect.top + (nodeRect.height - panelRect.height) / 2;

      left = Math.max(gap, Math.min(left, blockRect.width - panelRect.width - gap));
      top = Math.max(gap, Math.min(top, blockRect.height - panelRect.height - gap));
      groupHoverPanel.style.left = left + "px";
      groupHoverPanel.style.top = top + "px";
    };

    const showGroupHoverPreview = function (nodeLabel, nextKey, anchorNode) {
      if (!groupHoverPanel || !groupHoverTitle || !groupHoverGraph) return;
      if (activeKey !== "group") {
        hideGroupHoverPreview();
        return;
      }
      const variant = variantsByKey.get(nextKey);
      if (!variant || !variant.dot) {
        hideGroupHoverPreview();
        return;
      }
      if (!nodeLabel) {
        hideGroupHoverPreview();
        return;
      }
      if (!groupHoverPanel.hidden && groupHoverShownKey === nextKey && groupHoverShownLabel === nodeLabel) {
        positionGroupHoverPreview(anchorNode);
        return;
      }
      groupHoverShownKey = nextKey;
      groupHoverShownLabel = nodeLabel;
      groupHoverPanel.hidden = false;
      groupHoverTitle.textContent = "Preview: " + (variant.label || nodeLabel);
      positionGroupHoverPreview(anchorNode);
      const width = Math.max(320, groupHoverGraph.clientWidth || 0);
      const height = Math.max(220, groupHoverGraph.clientHeight || 0);
      const container = d3.select(groupHoverGraph);
      if (!groupHoverGraphviz) {
        groupHoverGraphviz = container.graphviz().fit(true);
      }
      groupHoverGraphviz
        .width(width)
        .height(height)
        .renderDot(variant.dot);
    };

    const switchVariant = function (nextKey) {
      if (!variantsByKey.has(nextKey) || nextKey === activeKey) return;
      activeKey = nextKey;
      if (selector) selector.value = nextKey;
      renderGraph();
    };

    function renderGraph() {
      const activeVariant = getActiveVariant();
      if (!activeVariant || !activeVariant.dot) return;
      hidePreviewPanel(previewPanelNode);
      hideGroupHoverPreview();
      layoutGraphBlock(graphBlock);
      const width = graphRoot.clientWidth;
      const height = graphRoot.clientHeight;

      const gv = graphContainer.graphviz()
        .width(width)
        .height(height)
        .fit(false)
        .on("end", function () {
          applyGraphZoomHeuristic(graphContainer, width, height, activeVariant.key);
          attachPreviewHandlers(graphContainer, previewPanelNode, previewMap);
          attachVariantSelectors(
            graphContainer,
            variantsByKey,
            activeVariant,
            switchVariant,
            showGroupHoverPreview
          );
        });
      gv.renderDot(activeVariant.dot);
      // TODO: remove fallback once graphviz `end` is confirmed stable on our
      // supported browser/runtime matrix.
      // Fallback for runtimes where the graphviz `end` event is unreliable.
      setTimeout(function () {
        applyGraphZoomHeuristic(graphContainer, width, height, activeVariant.key);
        attachPreviewHandlers(graphContainer, previewPanelNode, previewMap);
        attachVariantSelectors(
          graphContainer,
          variantsByKey,
          activeVariant,
          switchVariant,
          showGroupHoverPreview
        );
      }, 120);
    }

    if (selector) {
      selector.addEventListener("change", function () {
        switchVariant(selector.value);
      });
    }

    renderGraph();
    window.addEventListener("resize", debounce(renderGraph, 180));
  }

  graphBlocks.forEach(initGraphBlock);
  });
  })();
  "##

def graphTocToggleJs : String := r##"(function () {
  const className = "bp-graph-toc-hidden";
  const storageKey = "verso-blueprint-graph-toc-visible";
  if (!document.querySelector(".bp_graph_fullwidth")) return;
  if (!document.getElementById("toc")) return;

  function readVisible() {
    try {
      const saved = localStorage.getItem(storageKey);
      if (saved === "1") return true;
      if (saved === "0") return false;
    } catch (_err) {}
    return false; // default: hidden
  }

  let visible = readVisible();
  const root = document.documentElement;
  const button = document.createElement("button");
  button.id = "bp-toc-toggle";
  button.type = "button";

  function apply() {
    if (visible) root.classList.remove(className);
    else root.classList.add(className);
    button.textContent = visible ? "Hide ToC" : "Show ToC";
    window.dispatchEvent(new Event("resize"));
  }

  function persist() {
    try {
      localStorage.setItem(storageKey, visible ? "1" : "0");
    } catch (_err) {}
  }

  button.addEventListener("click", function () {
    visible = !visible;
    persist();
    apply();
  });

  if (document.body) document.body.appendChild(button);
  else document.addEventListener("DOMContentLoaded", function () {
    if (document.body) document.body.appendChild(button);
  }, { once: true });

  apply();
})();"##

def blueprintStyleSwitcherCss : String := Informal.StyleSwitcher.css

def blueprintStyleSwitcherJs : String := Informal.StyleSwitcher.jsBasic

-- block_extension Block.dependency_graph (label : String) where
open Verso Doc Elab Genre Manual in
block_extension Block.graph (graphData : GraphBlockData) where
  -- for TOC
  -- localContentItem _ _ _ := none
  data := toJson graphData
  traverse _id _data _contents := do
      return none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB _id data _blocks => do
      let graphData : GraphBlockData ←
        match fromJson? (α := GraphBlockData) data with
        | .ok gd => pure gd
        | .error _ =>
          match fromJson? (α := Graph) data with
          | .ok graph => pure { graph, direction := .TB }
          | .error _ =>
            HtmlT.logError "Malformed data in Block.graph.toHtml"
            pure { graph := #[], direction := .TB }
      let s ← HtmlT.state
      let resolveHref : Name → Option String := fun ref =>
        Resolve.resolveDomainHref? s Resolve.informalDomainName ref.toString
      let groupTitles : Lean.NameMap String :=
        graphData.groupTitles.foldl (init := ({} : Lean.NameMap String)) fun acc (group, title) =>
          acc.insert group title
      let resolveGroupTitle : Name → Option String := fun group =>
        groupTitles.get? group
      let graphVariants := mkGraphVariants graphData resolveHref groupTitles
      let hasGroupVariant := graphVariants.any (fun variant => variant.key == groupVariantKey)
      let graphVariantJson : String := Lean.Json.compress (toJson graphVariants)
      let graphVariantOptions : Array Output.Html :=
        graphVariants.map fun variant => {{
          <option value={{variant.key}}>{{variant.label}}</option>
        }}
      let includeMathlibLegend := graphData.graph.any (fun node => node.color == Informal.Graph.statementBorderMathlibColor)
      let legendGroups := Informal.Graph.graphLegendGroups includeMathlibLegend
      let legendGroupHtml : Array Output.Html :=
        legendGroups.map fun group =>
          let itemHtml : Array Output.Html :=
            group.items.map fun item =>
              match item.swatch? with
              | some swatch => {{
                  <span class="bp_graph_legend_item">
                    <span class="bp_graph_legend_swatch" "style"={{swatch.inlineStyle}}></span>
                    {{.text false item.label}}
                  </span>
                }}
              | Option.none => {{
                  <span class="bp_graph_legend_item">
                    {{.text false item.label}}
                  </span>
                }}
          {{
            <div class="bp_graph_legend_group">
              <span class="bp_graph_legend_group_title">{{.text false group.title}}</span>
              {{itemHtml}}
            </div>
          }}
      let legendNoteHtml : Output.Html :=
        if hasGroupVariant then
          {{
            <p class="bp_graph_legend_note">
              {{.text false Informal.Graph.graphLegendGroupViewNote}}
            </p>
          }}
        else
          .empty
      let fallbackDot : String :=
        match graphVariants[0]? with
        | some variant => variant.dot
        | Option.none => graphToDot graphData.graph graphData.direction resolveHref resolveGroupTitle
      let previewTemplates ← graphData.graph.foldlM (init := (#[] : Array Output.Html)) fun acc node => do
        let some (renderedBlocks, texPrelude) ← Informal.PreviewSource.renderTraversalPreview? s
          (fun b =>
            withReader
              (fun ctx =>
                let tctx := ctx.traverseContext
                { ctx with
                  traverseContext := {
                    tctx with
                    blockContext := tctx.blockContext.push (.other Informal.HoverRender.inlinePreviewMarkerBlock)
                  }
                })
              (goB b))
          node.label
          | pure acc
        pure <| acc.push (Informal.HoverRender.graphPreviewTemplate node.label renderedBlocks texPrelude)
      let previewUi := Informal.HoverRender.graphPreviewUi previewTemplates
      let groupHoverPanel : Output.Html := {{
        <aside class="bp_group_hover_preview" hidden>
          <div class="bp_group_hover_preview_header">
            <div class="bp_group_hover_preview_title"></div>
            <button type="button" class="bp_group_hover_preview_close" aria-label="Close group preview">"Close"</button>
          </div>
          <div class="bp_group_hover_preview_graph"></div>
        </aside>
      }}
      return {{
        <div class="bp_graph_fullwidth">
          <div class="bp_graph_legend">
            {{legendNoteHtml}}
            {{legendGroupHtml}}
          </div>
          <div class="bp_graph_controls">
            <label class="bp_graph_controls_label">"View"</label>
            <select class="bp_graph_controls_select bp_graph_view_select">
              {{graphVariantOptions}}
            </select>
          </div>
          <div class="bp_graph_canvas">
            <script type="application/json" class="bp-graph-variants">
              {{.text false s!"{graphVariantJson}"}}
            </script>
            <script type="text/plain" class="dot-source">
              {{.text false s!"{fallbackDot}"}}
            </script>
          </div>
          {{previewUi.store}}
          {{previewUi.panel}}
          {{groupHoverPanel}}
        </div>
      }}
  extraCss := ([graphCss, blueprintStyleSwitcherCss] : List String)
  extraJs := ([previewHoverUtilsJs, loadD3Dot, graphTocToggleJs, blueprintStyleSwitcherJs] : List String)

def buildAll : CoreM (Graph × Array (Name × String)) := do
  let env ← getEnv
  let state := informalExt.getState env
  let roots : Array Name := state.data.toArray.map (·.1)
  let graph := Informal.Graph.build state roots (resolveRef? := some)
  return (graph, state.groups.toArray)

open Verso.ArgParse

instance : FromArgVal GraphDirection Verso.Doc.Elab.PartElabM where
  fromArgVal := {
    description := doc!"graph direction (`LR`, `RL`, `TB`, or `BT`)"
    signature := CanMatch.Ident ∪ CanMatch.String
    get := fun
      | .name id =>
        match GraphDirection.parse? id.getId.toString with
        | some d => pure d
        | none => throwErrorAt id "Expected one of `LR`, `RL`, `TB`, `BT`"
      | .str s =>
        match GraphDirection.parse? s.getString with
        | some d => pure d
        | none => throwErrorAt s "Expected one of \"lr\", \"rl\", \"tb\", \"bt\""
      | other =>
        throwError "Expected a direction identifier or string, got {toMessageData other}"
  }

structure BlueprintGraphConfig where
  direction : Option GraphDirection := none

instance : FromArgs BlueprintGraphConfig Verso.Doc.Elab.PartElabM where
  fromArgs := BlueprintGraphConfig.mk <$> .named' `direction true

def parseGraphDirection (cfg : BlueprintGraphConfig) : Verso.Doc.Elab.PartElabM GraphDirection := do
  match cfg.direction with
  | none =>
    let configured :=
      (← getOptions).get
        verso.blueprint.graph.defaultDirection.name
        verso.blueprint.graph.defaultDirection.defValue
    match GraphDirection.parse? configured with
    | some direction => pure direction
    | none =>
      logWarning m!"Invalid value '{configured}' for option 'verso.blueprint.graph.defaultDirection'; expected LR, RL, TB, or BT. Falling back to TB."
      pure .TB
  | some direction => pure direction

open Verso Doc Elab Syntax in
def mkGraphPart (stx : Syntax) (endPos : String.Pos.Raw) (direction : GraphDirection := .TB) :
    PartElabM FinishedPart := do
  let titlePreview := "Dependency Graph"
  let titleInlines ← `(inline | "Dependency Graph")
  let expandedTitle ← #[titleInlines].mapM (elabInline ·)
  let metadata : Option (TSyntax `term) := some (← `(term| { number := false }))
  let (graph, groupTitles) ← buildAll
  logInfo m!"Adding {graph.size} nodes"
  let graphData : GraphBlockData := { graph, direction, groupTitles }
  let block ← ``(Verso.Doc.Block.other (Informal.Commands.Block.graph $(quote graphData)) #[])
  let subParts := #[]
  pure <| FinishedPart.mk stx expandedTitle titlePreview metadata #[block] subParts endPos

open Verso Doc Elab Syntax PartElabM in
@[part_command Lean.Doc.Syntax.command]
public meta def depGraph : PartCommand
  | stx@`(block|command{blueprint_graph $args*}) => do
    let cfg ← Verso.ArgParse.parseThe BlueprintGraphConfig (← parseArgs args)
    let direction ← parseGraphDirection cfg
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkGraphPart stx endPos direction)
  | _ => (Lean.Elab.throwUnsupportedSyntax : PartElabM Unit)

end Informal.Commands
