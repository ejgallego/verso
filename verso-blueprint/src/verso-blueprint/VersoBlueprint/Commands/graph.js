(function () {
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
    if (!(graphBlock instanceof Element)) return;

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

  function layoutGraphCanvas(graphRoot) {
    if (!(graphRoot instanceof Element)) return;
    const rect = graphRoot.getBoundingClientRect();
    const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 900;
    const bottomGap = 20;
    const availableHeight = Math.max(0, viewportHeight - rect.top - bottomGap);
    const targetHeight = Math.max(360, Math.min(availableHeight, Math.floor(viewportHeight * 0.84)));
    graphRoot.style.height = targetHeight + "px";
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
    return [{ key: "full", label: "Full Graph", dot: dotTxt, selectOnNodeId: [], hoverOnNodeId: [] }];
  }

  function graphNodeLabel(node) {
    if (!(node instanceof Element)) return "";
    const titleNode = node.querySelector("title");
    const titleTxt =
      titleNode && typeof titleNode.textContent === "string" ? titleNode.textContent.trim() : "";
    if (titleTxt) return titleTxt;
    const textNode = node.querySelector("text");
    const textTxt =
      textNode && typeof textNode.textContent === "string" ? textNode.textContent.trim() : "";
    return textTxt || "";
  }

  function graphNodeId(node) {
    if (!(node instanceof Element)) return "";
    const id = node.getAttribute("id");
    return typeof id === "string" ? id.trim() : "";
  }

  function ensureGraphBlockState(graphBlock) {
    if (!(graphBlock instanceof Element)) return {};
    const existing = graphBlock.__bpGraphState;
    if (existing && typeof existing === "object") return existing;
    const state = {
      previewActiveNode: null,
      previewController: null,
      previewRequestToken: 0,
      groupHoverAnchorNode: null,
      groupHoverController: null,
      groupHoverShownKey: "",
      groupHoverShownNodeId: "",
      graphviz: null,
      renderToken: 0,
      renderFinalizedToken: 0,
      windowHandlersBound: false,
      blockResizeBound: false
    };
    graphBlock.__bpGraphState = state;
    return state;
  }

  function parsePreviewEntry(entry) {
    const utils = window.bpPreviewUtils;
    if (utils && typeof utils.readPreviewTemplate === "function") {
      return utils.readPreviewTemplate(entry);
    }
    if (typeof entry === "string") {
      return entry;
    }
    return "";
  }

  function renderMath(root) {
    const utils = window.bpPreviewUtils;
    if (!utils || typeof utils.renderMath !== "function") return;
    utils.renderMath(root);
  }

  function readPanelNodes(panel, titleSelector, bodySelector) {
    if (!(panel instanceof Element)) {
      return { title: null, body: null };
    }
    const title = panel.querySelector(titleSelector);
    const body = panel.querySelector(bodySelector);
    return {
      title: title instanceof Element ? title : null,
      body: body instanceof Element ? body : null
    };
  }

  function createPanelController(panel, behavior, titleSelector, bodySelector, options) {
    if (!(panel instanceof Element)) return null;
    const nodes = readPanelNodes(panel, titleSelector, bodySelector);
    const opts = options && typeof options === "object" ? options : {};
    const clearBody =
      typeof opts.clearBody === "function"
        ? opts.clearBody
        : function (body) { body.innerHTML = ""; };
    const renderBody =
      typeof opts.renderBody === "function" ? opts.renderBody : function () {};
    const positionPanel =
      typeof opts.positionPanel === "function" ? opts.positionPanel : function () {};
    const onHide =
      typeof opts.onHide === "function" ? opts.onHide : function () {};
    const controller = {
      panel: panel,
      title: nodes.title,
      body: nodes.body,
      behavior: behavior || {
        isPinned: true,
        isHover: false,
        isAnchored: false,
        isDocked: true
      },
      hide: function () {
        panel.hidden = true;
        if (controller.title) controller.title.textContent = "";
        if (controller.body) clearBody(controller.body);
        onHide();
      },
      position: function (anchorNode) {
        positionPanel(panel, anchorNode);
      },
      show: function (titleText, payload, anchorNode) {
        if (!controller.title || !controller.body) return false;
        controller.title.textContent = titleText || "";
        renderBody(controller.body, payload);
        panel.hidden = false;
        controller.position(anchorNode);
        return true;
      }
    };
    return controller;
  }

  function makeHtmlPanelPositioner(behavior) {
    return function (panel, anchorNode) {
      const previewUtils = window.bpPreviewUtils;
      if (
        behavior &&
        behavior.isAnchored &&
        previewUtils &&
        typeof previewUtils.positionAnchoredPanel === "function" &&
        anchorNode instanceof Element
      ) {
        previewUtils.positionAnchoredPanel(panel, anchorNode, 12, 10);
      } else if (previewUtils && typeof previewUtils.resetPanelPosition === "function") {
        previewUtils.resetPanelPosition(panel);
      }
    };
  }

  function makeGroupPanelPositioner(graphBlock, behavior) {
    return function (panel, anchorNode) {
      if (!(panel instanceof Element) || !(graphBlock instanceof Element)) return;
      const previewUtils = window.bpPreviewUtils;
      if (!behavior || !behavior.isAnchored) {
        if (previewUtils && typeof previewUtils.resetPanelPosition === "function") {
          previewUtils.resetPanelPosition(panel);
        }
        return;
      }
      if (!(anchorNode instanceof Element)) return;
      const blockRect = graphBlock.getBoundingClientRect();
      const nodeRect = anchorNode.getBoundingClientRect();
      const panelRect = panel.getBoundingClientRect();
      const gap = 10;

      let left = nodeRect.right - blockRect.left + gap;
      if (left + panelRect.width > blockRect.width - gap) {
        left = nodeRect.left - blockRect.left - panelRect.width - gap;
      }
      let top = nodeRect.top - blockRect.top + (nodeRect.height - panelRect.height) / 2;

      left = Math.max(gap, Math.min(left, blockRect.width - panelRect.width - gap));
      top = Math.max(gap, Math.min(top, blockRect.height - panelRect.height - gap));
      panel.style.left = left + "px";
      panel.style.top = top + "px";
    };
  }

  function configurePanelCloseButton(previewUtils, closeButton, hidePanel, behavior) {
    if (!(closeButton instanceof Element)) return;
    if (previewUtils && typeof previewUtils.configureCloseButton === "function") {
      previewUtils.configureCloseButton(closeButton, hidePanel, behavior);
      return;
    }
    if (behavior && behavior.isPinned) {
      if (previewUtils && typeof previewUtils.bindCloseOnce === "function") {
        previewUtils.bindCloseOnce(closeButton, hidePanel);
      } else if (closeButton.getAttribute("data-bp-bound") !== "1") {
        closeButton.setAttribute("data-bp-bound", "1");
        closeButton.addEventListener("click", function (ev) {
          ev.preventDefault();
          ev.stopPropagation();
          hidePanel();
        });
      }
    } else {
      closeButton.hidden = true;
      closeButton.style.display = "none";
      closeButton.setAttribute("aria-hidden", "true");
      closeButton.tabIndex = -1;
    }
  }

  function bindHoverablePanelLifetime(previewUtils, controller, getActiveAnchor, boundAttr) {
    const noop = {
      cancelHide: function () {},
      scheduleHide: function () {
        if (controller) controller.hide();
      }
    };
    if (!controller || !(controller.panel instanceof Element)) return noop;
    if (!controller.behavior || !controller.behavior.isHover) return noop;
    const panel = controller.panel;
    const attr =
      typeof boundAttr === "string" && boundAttr.length > 0
        ? boundAttr
        : "data-bp-preview-hover-bound";
    let hideTimer = null;

    function cancelHide() {
      if (hideTimer !== null) {
        clearTimeout(hideTimer);
        hideTimer = null;
      }
    }

    function scheduleHide() {
      cancelHide();
      hideTimer = window.setTimeout(function () {
        hideTimer = null;
        controller.hide();
      }, 180);
    }

    function maybeScheduleHide(ev) {
      if (
        previewUtils &&
        typeof previewUtils.shouldKeepOpen === "function" &&
        previewUtils.shouldKeepOpen(
          ev.relatedTarget,
          typeof getActiveAnchor === "function" ? getActiveAnchor() : null,
          panel
        )
      ) {
        return;
      }
      scheduleHide();
    }

    if (panel.getAttribute(attr) !== "1") {
      panel.setAttribute(attr, "1");
      panel.addEventListener("mouseenter", cancelHide);
      panel.addEventListener("focusin", cancelHide);
      panel.addEventListener("mouseleave", maybeScheduleHide);
      panel.addEventListener("focusout", maybeScheduleHide);
    }

    return {
      cancelHide: cancelHide,
      scheduleHide: scheduleHide
    };
  }

  function attachPreviewHandlers(graphBlock, graphContainer, previewMap, previewController, previewKeyByNodeId) {
    if (!previewController) return;
    const graphState = ensureGraphBlockState(graphBlock);
    const previewUtils = window.bpPreviewUtils;
    const canResolveSharedPreview =
      previewUtils && typeof previewUtils.loadSharedPreviewEntry === "function";
    const previewKeys =
      previewKeyByNodeId instanceof Map ? previewKeyByNodeId : new Map();
    const hoverLifetime = bindHoverablePanelLifetime(
      previewUtils,
      previewController,
      function () { return graphState.previewActiveNode; },
      "data-bp-preview-hover-bound"
    );
    const svg = graphContainer.select("svg").node();
    if (!svg || !(svg instanceof SVGElement)) {
      previewController.hide();
      return;
    }
    if (!previewController.title || !previewController.body || (previewMap.size === 0 && !canResolveSharedPreview)) {
      previewController.hide();
      return;
    }
    const show = async function (label, anchorNode) {
      const requestToken = ++graphState.previewRequestToken;
      const nodeId = anchorNode instanceof Element ? graphNodeId(anchorNode) : "";
      const previewKey = nodeId ? (previewKeys.get(nodeId) || "") : "";
      let html = parsePreviewEntry(previewMap.get(label));
      if (!html && canResolveSharedPreview && previewKey) {
        const sharedEntry = await previewUtils.loadSharedPreviewEntry(previewKey);
        html = parsePreviewEntry(sharedEntry);
      }
      if (requestToken !== graphState.previewRequestToken) return;
      if (!html) return;
      hoverLifetime.cancelHide();
      graphState.previewActiveNode = anchorNode instanceof Element ? anchorNode : null;
      previewController.show(label, html, graphState.previewActiveNode);
    };
    svg.querySelectorAll("g.node").forEach(function (node) {
      const label = graphNodeLabel(node);
      const nodeId = graphNodeId(node);
      const previewKey = nodeId ? (previewKeys.get(nodeId) || "") : "";
      if (!label || (!previewMap.has(label) && !(canResolveSharedPreview && previewKey))) return;
      node.style.cursor = "pointer";
      node.setAttribute("tabindex", "0");
      const titleNode = node.querySelector("title");
      if (titleNode) titleNode.remove();
      [node].concat(Array.from(node.querySelectorAll("*"))).forEach(function (el) {
        if (!(el instanceof Element)) return;
        if (el.hasAttribute("title")) el.removeAttribute("title");
        if (el.hasAttribute("xlink:title")) el.removeAttribute("xlink:title");
        if (el.removeAttributeNS) {
          el.removeAttributeNS("http://www.w3.org/1999/xlink", "title");
        }
      });
    });
    const showFromTarget = function (target) {
      if (!(target instanceof Element)) return;
      const node = target.closest("g.node");
      if (!node) return;
       if (graphState.previewActiveNode === node && !previewController.panel.hidden) {
        hoverLifetime.cancelHide();
        previewController.position(node);
        return;
      }
      const label = graphNodeLabel(node);
      if (label) show(label, node);
    };
    if (svg.getAttribute("data-bp-preview-bound") === "1") return;
    svg.setAttribute("data-bp-preview-bound", "1");
    svg.addEventListener("mouseover", function (ev) {
      showFromTarget(ev.target);
    });
    svg.addEventListener("focusin", function (ev) {
      showFromTarget(ev.target);
    });
    if (previewController.behavior && previewController.behavior.isHover) {
      const hideIfLeaving = function (ev) {
        if (
          previewUtils &&
          typeof previewUtils.shouldKeepOpen === "function" &&
          previewUtils.shouldKeepOpen(ev.relatedTarget, graphState.previewActiveNode, previewController.panel)
        ) {
          return;
        }
        hoverLifetime.scheduleHide();
      };
      svg.addEventListener("mouseout", hideIfLeaving);
      svg.addEventListener("focusout", hideIfLeaving);
    }
  }

  function attachVariantSelectors(graphContainer, variantsByKey, activeVariant, onSelect, onHover, onHoverLeave) {
    if (!activeVariant) return;
    const mapNodeTargets = function (entries) {
      const out = new Map();
      if (!Array.isArray(entries)) return out;
      entries.forEach(function (entry) {
        if (!Array.isArray(entry) || entry.length !== 2) return;
        const nodeId = String(entry[0] || "").trim();
        const nextKey = String(entry[1] || "").trim();
        if (!nodeId || !nextKey || !variantsByKey.has(nextKey)) return;
        out.set(nodeId, nextKey);
      });
      return out;
    };
    const selectVariantByNodeId = mapNodeTargets(activeVariant.selectOnNodeId);
    const hoverVariantByNodeId = mapNodeTargets(activeVariant.hoverOnNodeId);
    const svg = graphContainer.select("svg").node();
    if (!svg) return;
    const readVariantState = function () {
      const state = svg.__bpVariantState;
      if (state && state.selectVariantByNodeId instanceof Map && state.hoverVariantByNodeId instanceof Map) {
        return state;
      }
      return {
        selectVariantByNodeId: new Map(),
        hoverVariantByNodeId: new Map(),
        lastHoverNodeId: ""
      };
    };
    svg.__bpVariantState = {
      selectVariantByNodeId: selectVariantByNodeId,
      hoverVariantByNodeId: hoverVariantByNodeId,
      lastHoverNodeId: ""
    };

    const nodeSelectKey = function (node) {
      const id = graphNodeId(node);
      if (!id) return "";
      const state = readVariantState();
      return state.selectVariantByNodeId.get(id) || "";
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
      const id = graphNodeId(node);
      if (!id) return;
      const state = readVariantState();
      const nextKey = state.hoverVariantByNodeId.get(id) || "";
      if (!nextKey || id === state.lastHoverNodeId) return;
      state.lastHoverNodeId = id;
      onHover(id, nextKey, node);
    };

    svg.querySelectorAll("g.node").forEach(function (node) {
      const selectKey = nodeSelectKey(node);
      const id = graphNodeId(node);
      const state = readVariantState();
      const hoverKey = id ? (state.hoverVariantByNodeId.get(id) || "") : "";
      if (!selectKey && !hoverKey) return;
      node.style.cursor = "pointer";
      node.setAttribute("tabindex", "0");
    });
    if (svg.getAttribute("data-bp-variant-bound") === "1") return;
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
      state.lastHoverNodeId = "";
      if (typeof onHoverLeave === "function") onHoverLeave();
    });
  }

  function syncLegend(graphBlock, activeKey) {
    const fullLegend = graphBlock.querySelector('.bp_graph_legend[data-bp-legend-kind="full"]');
    const groupLegend = graphBlock.querySelector('.bp_graph_legend[data-bp-legend-kind="group"]');
    const showGroupLegend = activeKey === "group";
    if (fullLegend) fullLegend.hidden = showGroupLegend;
    if (groupLegend) groupLegend.hidden = !showGroupLegend;
  }

  function applyGraphZoomHeuristic(graphContainer, width, height, variantKey) {
    const svg = graphContainer.select("svg").node();
    if (!svg) return;
    const graphRoot = svg.querySelector("g.graph") || svg.querySelector("g");
    if (!graphRoot || typeof graphRoot.getBBox !== "function") return;
    const bounds = graphRoot.getBBox();
    if (!bounds || !(bounds.width > 0) || !(bounds.height > 0)) return;

    const padX = variantKey === "full" ? 40 : 24;
    const padY = variantKey === "full" ? 32 : 24;
    const baseX = bounds.x - padX;
    const baseY = bounds.y - padY;
    const baseW = bounds.width + padX * 2;
    const baseH = bounds.height + padY * 2;
    const fitScale = Math.min(
      width / baseW,
      height / baseH
    );
    if (!isFinite(fitScale) || fitScale <= 0) return;

    const maxScale =
      variantKey === "group" ? 1.85 :
      variantKey === "full" ? 1.35 :
      1.15;
    const targetScale = Math.min(maxScale, fitScale);
    if (!isFinite(targetScale) || targetScale <= 0) return;

    const zoomFactor = Math.min(1, targetScale / fitScale);
    const viewW = baseW * zoomFactor;
    const viewH = baseH * zoomFactor;
    const viewX = baseX + (baseW - viewW) / 2;
    const topBiased = variantKey === "group" || variantKey === "full";
    const viewY = topBiased ? baseY : baseY + (baseH - viewH) / 2;
    svg.setAttribute("viewBox", [viewX, viewY, viewW, viewH].join(" "));
    svg.setAttribute("preserveAspectRatio", topBiased ? "xMidYMin meet" : "xMidYMid meet");
  }

  Promise.resolve()
    .then(function () { return load("https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js"); })
    .then(function () { return load("https://cdn.jsdelivr.net/npm/d3-graphviz@5.6.0/build/d3-graphviz.min.js"); })
    .then(function () {
      const graphBlocks = Array.from(document.querySelectorAll(".bp_graph_fullwidth"));
      if (graphBlocks.length === 0) return;

      function initGraphBlock(graphBlock) {
        if (!(graphBlock instanceof Element)) return;
        layoutGraphBlock(graphBlock);
        const graphRoot = graphBlock.querySelector(".bp_graph_canvas");
        if (!graphRoot) return;
        const graphContainer = d3.select(graphRoot);
        if (graphContainer.empty()) return;
        const graphState = ensureGraphBlockState(graphBlock);
        const selector = graphBlock.querySelector(".bp_graph_view_select");
        const previewMap = collectPreviewTemplates(graphBlock);
        const previewPanelNode = graphBlock.querySelector(".bp_graph_preview");
        const previewClose = previewPanelNode
          ? previewPanelNode.querySelector(".bp_graph_preview_close")
          : null;
        const previewUtils = window.bpPreviewUtils;
        const previewPanelBehavior =
          previewUtils && typeof previewUtils.readPanelBehavior === "function"
            ? previewUtils.readPanelBehavior(previewPanelNode, { mode: "pinned", placement: "docked" })
            : { mode: "pinned", placement: "docked", isPinned: true, isHover: false, isAnchored: false, isDocked: true };
        const previewController = createPanelController(
          previewPanelNode,
          previewPanelBehavior,
          ".bp_graph_preview_title",
          ".bp_graph_preview_body",
          {
            clearBody: function (body) { body.innerHTML = ""; },
            renderBody: function (body, html) {
              body.innerHTML = html;
              if (previewUtils && typeof previewUtils.hydratePreviewSubtree === "function") {
                previewUtils.hydratePreviewSubtree(body);
              }
              renderMath(body);
            },
            positionPanel: makeHtmlPanelPositioner(previewPanelBehavior),
            onHide: function () {
              graphState.previewRequestToken += 1;
              graphState.previewActiveNode = null;
            }
          }
        );
        graphState.previewController = previewController;
        configurePanelCloseButton(previewUtils, previewClose, function () {
          if (previewController) previewController.hide();
        }, previewPanelBehavior);

        const rawVariants = collectGraphVariants(graphContainer);
        if (!Array.isArray(rawVariants) || rawVariants.length === 0) return;
        const variantsByKey = new Map();
        rawVariants.forEach(function (variant) {
        if (!variant || typeof variant !== "object") return;
        const key = String(variant.key || "").trim();
        const label = String(variant.label || key).trim();
        const dot = String(variant.dot || "").trim();
        const selectOnNodeId = Array.isArray(variant.selectOnNodeId) ? variant.selectOnNodeId : [];
        const hoverOnNodeId = Array.isArray(variant.hoverOnNodeId) ? variant.hoverOnNodeId : [];
        const previewKeyByNodeId = Array.isArray(variant.previewKeyByNodeId) ? variant.previewKeyByNodeId : [];
        if (!key || !dot) return;
        variantsByKey.set(key, {
          key: key,
          label: label || key,
          dot: dot,
          selectOnNodeId: selectOnNodeId,
          hoverOnNodeId: hoverOnNodeId,
          previewKeyByNodeId: new Map(previewKeyByNodeId)
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
        syncLegend(graphBlock, activeKey);

        const getActiveVariant = function () {
          const fallback = variantsByKey.get("full") || variants[0];
          return variantsByKey.get(activeKey) || fallback;
        };

        const groupHoverPanel = graphBlock.querySelector(".bp_group_hover_preview");
        const groupHoverClose = groupHoverPanel
          ? groupHoverPanel.querySelector(".bp_group_hover_preview_close")
          : null;
        let groupHoverGraphviz = null;
        const groupHoverBehavior =
          previewUtils && typeof previewUtils.readPanelBehavior === "function"
            ? previewUtils.readPanelBehavior(groupHoverPanel, { mode: "pinned", placement: "docked" })
            : { mode: "pinned", placement: "docked", isPinned: true, isHover: false, isAnchored: false, isDocked: true };
        const groupHoverController = createPanelController(
          groupHoverPanel,
          groupHoverBehavior,
          ".bp_group_hover_preview_title",
          ".bp_group_hover_preview_graph",
          {
            clearBody: function (body) { body.innerHTML = ""; },
            renderBody: function (body, variant) {
              const width = Math.max(320, body.clientWidth || 0);
              const height = Math.max(220, body.clientHeight || 0);
              const container = d3.select(body);
              if (!groupHoverGraphviz) {
                groupHoverGraphviz = container.graphviz().fit(true);
              }
              groupHoverGraphviz
                .width(width)
                .height(height)
                .renderDot(variant.dot);
            },
            positionPanel: makeGroupPanelPositioner(graphBlock, groupHoverBehavior),
            onHide: function () {
              graphState.groupHoverAnchorNode = null;
              graphState.groupHoverShownKey = "";
              graphState.groupHoverShownNodeId = "";
            }
          }
        );
        graphState.groupHoverController = groupHoverController;
        const groupHoverLifetime = bindHoverablePanelLifetime(
          previewUtils,
          groupHoverController,
          function () { return graphState.groupHoverAnchorNode; },
          "data-bp-group-hover-bound"
        );
        configurePanelCloseButton(previewUtils, groupHoverClose, function () {
          if (groupHoverController) groupHoverController.hide();
        }, groupHoverBehavior);

        if (!graphState.windowHandlersBound) {
          graphState.windowHandlersBound = true;
          const repositionPanels = function () {
            if (
              graphState.previewController &&
              graphState.previewController.behavior &&
              graphState.previewController.behavior.isAnchored &&
              graphState.previewActiveNode &&
              !graphState.previewController.panel.hidden
            ) {
              graphState.previewController.position(graphState.previewActiveNode);
            }
            if (
              graphState.groupHoverController &&
              graphState.groupHoverController.behavior &&
              graphState.groupHoverController.behavior.isAnchored &&
              graphState.groupHoverAnchorNode &&
              !graphState.groupHoverController.panel.hidden
            ) {
              graphState.groupHoverController.position(graphState.groupHoverAnchorNode);
            }
          };
          window.addEventListener("keydown", function (ev) {
            if (ev.key !== "Escape") return;
            if (graphState.groupHoverController) graphState.groupHoverController.hide();
            if (graphState.previewController) graphState.previewController.hide();
          });
          window.addEventListener("resize", repositionPanels);
          window.addEventListener("scroll", repositionPanels, true);
        }

        const showGroupHoverPreview = function (nodeId, nextKey, anchorNode) {
          if (!groupHoverController) return;
          groupHoverLifetime.cancelHide();
          if (activeKey !== "group") {
            groupHoverController.hide();
            return;
          }
          const variant = variantsByKey.get(nextKey);
          if (!variant || !variant.dot || !nodeId) {
            groupHoverController.hide();
            return;
          }
          if (
            !groupHoverController.panel.hidden &&
            graphState.groupHoverShownKey === nextKey &&
            graphState.groupHoverShownNodeId === nodeId
          ) {
            groupHoverController.position(anchorNode);
            return;
          }
          graphState.groupHoverAnchorNode = anchorNode instanceof Element ? anchorNode : null;
          graphState.groupHoverShownKey = nextKey;
          graphState.groupHoverShownNodeId = nodeId;
          groupHoverController.show("Preview: " + variant.label, variant, graphState.groupHoverAnchorNode);
        };

        const switchVariant = function (nextKey) {
          if (!variantsByKey.has(nextKey) || nextKey === activeKey) return;
          activeKey = nextKey;
          if (selector) selector.value = nextKey;
          syncLegend(graphBlock, activeKey);
          renderGraph();
        };

        function renderGraph() {
          const activeVariant = getActiveVariant();
          if (!activeVariant || !activeVariant.dot) return;
          graphState.renderToken += 1;
          const renderToken = graphState.renderToken;
          syncLegend(graphBlock, activeVariant.key);
          if (previewController) previewController.hide();
          if (groupHoverController) groupHoverController.hide();
          layoutGraphBlock(graphBlock);
          layoutGraphCanvas(graphRoot);
          const width = graphRoot.clientWidth;
          const height = graphRoot.clientHeight;
          const finalizeRender = function () {
            if (graphState.renderToken !== renderToken) return;
            if (graphState.renderFinalizedToken === renderToken) return;
            graphState.renderFinalizedToken = renderToken;
            applyGraphZoomHeuristic(graphContainer, width, height, activeVariant.key);
            attachPreviewHandlers(
              graphBlock,
              graphContainer,
              previewMap,
              previewController,
              activeVariant.previewKeyByNodeId
            );
            attachVariantSelectors(
              graphContainer,
              variantsByKey,
              activeVariant,
              switchVariant,
              showGroupHoverPreview,
              groupHoverBehavior.isHover && groupHoverController
                ? function () { groupHoverLifetime.scheduleHide(); }
                : null
            );
          };

          const gv = graphState.graphviz || graphContainer.graphviz();
          graphState.graphviz = gv;
          gv
            .zoom(true)
            .width(width)
            .height(height)
            .fit(false)
            .on("end", function () {
              finalizeRender();
            });
          gv.renderDot(activeVariant.dot);
          setTimeout(function () {
            finalizeRender();
          }, 120);
        }

        if (selector) {
          selector.addEventListener("change", function () {
            switchVariant(selector.value);
          });
        }

        renderGraph();
        if (!graphState.blockResizeBound) {
          graphState.blockResizeBound = true;
          window.addEventListener("resize", debounce(renderGraph, 180));
        }
      }

      graphBlocks.forEach(initGraphBlock);
    });
})();
