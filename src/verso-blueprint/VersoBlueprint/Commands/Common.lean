/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

namespace Informal.Commands

def previewHoverUtilsJs : String := r##"(function () {
  if (window.bpPreviewUtils) return;

  function collectPreviewTemplates(root, selector, keyAttr) {
    const map = new Map();
    if (!(root instanceof Element || root instanceof Document)) return map;
    if (typeof selector !== "string" || selector.length === 0) return map;
    const keyName =
      typeof keyAttr === "string" && keyAttr.length > 0
        ? keyAttr
        : "data-bp-preview-label";
    root.querySelectorAll(selector).forEach(function (tpl) {
      if (!(tpl instanceof Element)) return;
      const label = tpl.getAttribute(keyName) || "";
      let html = "";
      let texPrelude = "";
      if (tpl instanceof HTMLTemplateElement) {
        const content = tpl.content.cloneNode(true);
        if (content instanceof DocumentFragment) {
          const preludeNode = content.querySelector("script.bp_preview_tex_prelude[type=\"text/plain\"]");
          if (preludeNode instanceof Element) {
            texPrelude = (preludeNode.textContent || "").trim();
            preludeNode.remove();
          }
          const wrapper = document.createElement("div");
          wrapper.appendChild(content);
          html = (wrapper.innerHTML || "").trim();
        }
      }
      if (!html) {
        html = (tpl.innerHTML || "").trim();
      }
      if (!texPrelude) {
        texPrelude = (tpl.getAttribute("data-bp-preview-tex-prelude") || "").trim();
      }
      if (label && html) {
        map.set(label, { html: html, texPrelude: texPrelude });
      }
    });
    return map;
  }

  function readPreviewTemplate(entry) {
    if (typeof entry === "string") {
      return { html: entry, texPrelude: "" };
    }
    if (!entry || typeof entry !== "object") {
      return { html: "", texPrelude: "" };
    }
    const html = typeof entry.html === "string" ? entry.html : "";
    const texPrelude = typeof entry.texPrelude === "string" ? entry.texPrelude : "";
    return { html: html, texPrelude: texPrelude };
  }

  function renderMath(root, texPrelude) {
    if (!(root instanceof Element)) return;
    if (typeof katex !== "object" || typeof katex.render !== "function") return;
    const prelude = typeof texPrelude === "string" ? texPrelude.trim() : "";
    const hasPrelude = prelude.length > 0;
    const renderWrapped = !!katex.render.__versoTexPreludeWrapped;
    const originalRender =
      renderWrapped && typeof katex.render.__versoTexPreludeOriginal === "function"
        ? katex.render.__versoTexPreludeOriginal
        : null;
    const renderFn = hasPrelude && typeof originalRender === "function" ? originalRender : katex.render;
    const renderAll = function (selector, displayMode) {
      root.querySelectorAll(selector).forEach(function (m) {
        if (!(m instanceof Element)) return;
        if (m.getAttribute("data-bp-math-rendered") === "1") return;
        try {
          const tex = m.textContent || "";
          const renderInput =
            hasPrelude && (typeof originalRender === "function" || !renderWrapped)
              ? prelude + "\n" + tex
              : tex;
          renderFn(renderInput, m, { throwOnError: false, displayMode: displayMode });
          m.setAttribute("data-bp-math-rendered", "1");
        } catch (_err) {}
      });
    };
    renderAll(".math.inline", false);
    renderAll(".math.display", true);
  }

  function bindCloseOnce(button, onClose) {
    if (!(button instanceof Element)) return;
    if (button.getAttribute("data-bp-bound") === "1") return;
    if (typeof onClose !== "function") return;
    button.setAttribute("data-bp-bound", "1");
    button.addEventListener("click", function (ev) {
      ev.preventDefault();
      ev.stopPropagation();
      onClose(ev);
    });
  }

  window.bpPreviewUtils = {
    collectPreviewTemplates: collectPreviewTemplates,
    readPreviewTemplate: readPreviewTemplate,
    renderMath: renderMath,
    bindCloseOnce: bindCloseOnce
  };
})();"##

def inlinePreviewCss : String := r##"
.bp_inline_preview_ref {
  cursor: help;
}

.bp_inline_preview_panel {
  position: fixed;
  z-index: 70;
  min-width: 18rem;
  max-width: min(34rem, 86vw);
  max-height: min(26rem, 80vh);
  overflow: hidden;
  border: 1px solid #cbd5e1;
  border-radius: 0.45rem;
  background: #ffffff;
  box-shadow: 0 10px 24px rgba(15, 23, 42, 0.2);
}

.bp_inline_preview_panel_header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.6rem;
  padding: 0.4rem 0.55rem;
  border-bottom: 1px solid #e2e8f0;
  background: #f8fafc;
}

.bp_inline_preview_panel_title {
  font-size: 0.82rem;
  font-weight: 700;
  color: #0f172a;
}

.bp_inline_preview_panel_close {
  border: 1px solid #cbd5e1;
  border-radius: 0.3rem;
  background: #ffffff;
  color: #334155;
  font-size: 0.72rem;
  line-height: 1;
  padding: 0.2rem 0.35rem;
  cursor: pointer;
}

.bp_inline_preview_panel_body {
  padding: 0.5rem 0.6rem 0.55rem;
  max-height: min(22rem, 70vh);
  overflow: auto;
  font-size: 0.8rem;
}

.bp_bibliography_hover_entry {
  border: 1px solid #e2e8f0;
  border-radius: 0.4rem;
  padding: 0.35rem 0.45rem;
  background: #f8fafc;
}

.bp_bibliography_hover_entry .citation {
  display: block;
  line-height: 1.35;
}

.bp_bibliography_hover_meta {
  margin-top: 0.42rem;
  display: flex;
  align-items: baseline;
  gap: 0.42rem;
  flex-wrap: wrap;
}

.bp_bibliography_hover_meta_label {
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: #64748b;
}

.bp_bibliography_hover_meta_value {
  font-size: 0.76rem;
  font-weight: 600;
  color: #0f172a;
}

.bp_code_hover_section {
  margin-top: 0.28rem;
}

.bp_code_hover_label {
  font-weight: 600;
  color: #334155;
}

.bp_code_hover_list {
  margin: 0.12rem 0 0;
  padding-left: 1.1rem;
}

.bp_code_hover_list code {
  font-size: 0.76rem;
}

.bp_code_hover_none {
  color: #64748b;
  font-style: italic;
}
"##

def openTargetDetailsJs : String := r##"(function () {
  function openFromHash() {
    if (!window.location.hash) return;
    const id = decodeURIComponent(window.location.hash.slice(1));
    if (!id) return;
    const target = document.getElementById(id);
    if (!target) return;
    const details = target.matches(\"details\") ? target : target.closest(\"details\");
    if (details) details.open = true;
  }

  if (document.readyState === \"loading\") {
    document.addEventListener(\"DOMContentLoaded\", openFromHash);
  } else {
    openFromHash();
  }
  window.addEventListener(\"hashchange\", openFromHash);
})();"##

def inlineLinkPreviewJs : String := r##"(function () {
  function ensureInlinePreviewStore() {
    const existing = document.getElementById("bp-inline-preview-store");
    if (existing instanceof Element) return existing;
    const store = document.createElement("div");
    store.id = "bp-inline-preview-store";
    store.className = "bp_inline_preview_store";
    store.hidden = true;
    document.body.appendChild(store);
    return store;
  }

  function buildInlinePreviewStore() {
    const selector = "template.bp_inline_preview_tpl[data-bp-preview-id]";
    const store = ensureInlinePreviewStore();
    const templates = Array.from(document.querySelectorAll(selector));
    const seen = new Set();
    templates.forEach(function (tpl) {
      if (!(tpl instanceof HTMLTemplateElement)) return;
      const key = (tpl.getAttribute("data-bp-preview-id") || "").trim();
      if (!key) return;
      if (seen.has(key)) {
        tpl.remove();
        return;
      }
      seen.add(key);
      if (!store.contains(tpl)) {
        store.appendChild(tpl);
      }
    });
    return store;
  }

  function makePanel() {
    const panel = document.createElement("aside");
    panel.id = "bp-inline-preview-panel";
    panel.className = "bp_inline_preview_panel";
    panel.hidden = true;
    panel.innerHTML =
      '<div class="bp_inline_preview_panel_header">' +
      '<div class="bp_inline_preview_panel_title"></div>' +
      '<button type="button" class="bp_inline_preview_panel_close" aria-label="Close inline preview">Close</button>' +
      "</div>" +
      '<div class="bp_inline_preview_panel_body"></div>';
    document.body.appendChild(panel);
    return panel;
  }

  function getPanel() {
    const existing = document.getElementById("bp-inline-preview-panel");
    if (existing instanceof Element) return existing;
    return makePanel();
  }

  function bindInlinePreview() {
    if (!(document.body instanceof Element)) return;
    if (document.body.getAttribute("data-bp-inline-preview-bound") === "1") return;
    document.body.setAttribute("data-bp-inline-preview-bound", "1");

    const previewUtils = window.bpPreviewUtils;
    if (!previewUtils || typeof previewUtils.collectPreviewTemplates !== "function") return;
    const store = buildInlinePreviewStore();
    const previewMap = previewUtils.collectPreviewTemplates(
      store,
      "template.bp_inline_preview_tpl[data-bp-preview-id]",
      "data-bp-preview-id"
    );
    if (!(previewMap instanceof Map) || previewMap.size === 0) return;

    const panel = getPanel();
    const title = panel.querySelector(".bp_inline_preview_panel_title");
    const body = panel.querySelector(".bp_inline_preview_panel_body");
    const close = panel.querySelector(".bp_inline_preview_panel_close");
    if (!(title instanceof Element) || !(body instanceof Element) || !(close instanceof Element)) return;

    let activeTrigger = null;

    function parsePreviewEntry(entry) {
      if (previewUtils && typeof previewUtils.readPreviewTemplate === "function") {
        return previewUtils.readPreviewTemplate(entry);
      }
      return { html: "", texPrelude: "" };
    }

    function hidePanel() {
      panel.hidden = true;
      title.textContent = "";
      body.innerHTML = "";
      activeTrigger = null;
    }

    function positionPanel(anchor) {
      if (!(anchor instanceof Element)) return;
      const rect = anchor.getBoundingClientRect();
      const margin = 12;
      const panelRect = panel.getBoundingClientRect();
      const panelWidth = panelRect.width || Math.min(520, window.innerWidth - margin * 2);
      const panelHeight = panelRect.height || Math.min(420, window.innerHeight - margin * 2);
      let left = rect.left;
      if (left + panelWidth > window.innerWidth - margin) {
        left = window.innerWidth - panelWidth - margin;
      }
      left = Math.max(margin, left);
      let top = rect.bottom + 10;
      if (top + panelHeight > window.innerHeight - margin) {
        top = rect.top - panelHeight - 10;
      }
      top = Math.max(margin, top);
      panel.style.left = left + "px";
      panel.style.top = top + "px";
    }

    function showFromTrigger(trigger) {
      if (!(trigger instanceof Element)) return;
      const key = trigger.getAttribute("data-bp-preview-id") || "";
      if (!key) {
        hidePanel();
        return;
      }
      const entry = parsePreviewEntry(previewMap.get(key));
      const html = entry.html;
      const texPrelude = entry.texPrelude;
      if (!html) {
        hidePanel();
        return;
      }
      activeTrigger = trigger;
      const heading = trigger.getAttribute("data-bp-preview-title") || key;
      title.textContent = heading;
      body.innerHTML = html;
      if (previewUtils && typeof previewUtils.renderMath === "function") {
        previewUtils.renderMath(body, texPrelude);
      }
      panel.hidden = false;
      positionPanel(trigger);
    }

    if (typeof previewUtils.bindCloseOnce === "function") {
      previewUtils.bindCloseOnce(close, hidePanel);
    } else if (close.getAttribute("data-bp-bound") !== "1") {
      close.setAttribute("data-bp-bound", "1");
      close.addEventListener("click", function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        hidePanel();
      });
    }

    const triggers = document.querySelectorAll(".bp_inline_preview_ref[data-bp-preview-id]");
    triggers.forEach(function (trigger) {
      if (!(trigger instanceof Element)) return;
      if (trigger.getAttribute("data-bp-bound") === "1") return;
      trigger.setAttribute("data-bp-bound", "1");
      trigger.addEventListener("mouseenter", function () {
        showFromTrigger(trigger);
      });
      trigger.addEventListener("focusin", function () {
        showFromTrigger(trigger);
      });
      trigger.addEventListener("mouseleave", function (ev) {
        const next = ev.relatedTarget;
        if (next instanceof Element && (trigger.contains(next) || panel.contains(next))) return;
        hidePanel();
      });
      trigger.addEventListener("focusout", function (ev) {
        const next = ev.relatedTarget;
        if (next instanceof Element && (trigger.contains(next) || panel.contains(next))) return;
        hidePanel();
      });
    });

    panel.addEventListener("mouseleave", function (ev) {
      const next = ev.relatedTarget;
      if (next instanceof Element && activeTrigger && activeTrigger.contains(next)) return;
      if (next instanceof Element && panel.contains(next)) return;
      hidePanel();
    });
    panel.addEventListener("focusout", function (ev) {
      const next = ev.relatedTarget;
      if (next instanceof Element && activeTrigger && activeTrigger.contains(next)) return;
      if (next instanceof Element && panel.contains(next)) return;
      hidePanel();
    });

    document.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape") {
        hidePanel();
      }
    });
    window.addEventListener("resize", function () {
      if (activeTrigger && !panel.hidden) positionPanel(activeTrigger);
    });
    window.addEventListener(
      "scroll",
      function () {
        if (activeTrigger && !panel.hidden) positionPanel(activeTrigger);
      },
      true
    );
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", bindInlinePreview);
  } else {
    bindInlinePreview();
  }
})();"##

end Informal.Commands
