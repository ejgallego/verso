/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

namespace Informal.Commands

def previewHoverUtilsJs : String := r##"(function () {
  if (window.bpPreviewUtils) return;

  function collectPreviewTemplates(root, selector) {
    const map = new Map();
    if (!(root instanceof Element || root instanceof Document)) return map;
    if (typeof selector !== "string" || selector.length === 0) return map;
    root.querySelectorAll(selector).forEach(function (tpl) {
      if (!(tpl instanceof Element)) return;
      const label = tpl.getAttribute("data-bp-preview-label") || "";
      const html = (tpl.innerHTML || "").trim();
      const texPrelude = (tpl.getAttribute("data-bp-preview-tex-prelude") || "").trim();
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
    const renderWrapped = !!katex.render.__versoTexPreludeWrapped;
    const renderAll = function (selector, displayMode) {
      root.querySelectorAll(selector).forEach(function (m) {
        if (!(m instanceof Element)) return;
        if (m.getAttribute("data-bp-math-rendered") === "1") return;
        try {
          const tex = m.textContent || "";
          const renderInput = prelude.length > 0 && !renderWrapped ? prelude + "\n" + tex : tex;
          katex.render(renderInput, m, { throwOnError: false, displayMode: displayMode });
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

end Informal.Commands
