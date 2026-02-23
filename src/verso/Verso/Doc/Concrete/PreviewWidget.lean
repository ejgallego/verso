/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Lean.Elab.Term.TermElabM
import Lean.Widget.UserWidget

namespace Verso.Doc.Concrete.PreviewWidget

open Lean Elab Term

@[widget_module]
public def htmlPreviewWidget : Lean.Widget.Module where
  javascript := "
import { createElement } from 'react';

export default function ({ html, docs }) {
  const installHoverDocs = (root) => {
    if (!root || root.dataset.versoPreviewHoverBound === '1') return;
    root.dataset.versoPreviewHoverBound = '1';
    if (!docs || typeof docs !== 'object') return;

    const tip = document.createElement('div');
    tip.style.position = 'fixed';
    tip.style.maxWidth = 'min(36rem, 70vw)';
    tip.style.maxHeight = '40vh';
    tip.style.overflow = 'auto';
    tip.style.padding = '0.5em 0.65em';
    tip.style.border = '1px solid var(--vscode-panel-border)';
    tip.style.borderRadius = '6px';
    tip.style.background = 'var(--vscode-editor-background)';
    tip.style.color = 'var(--vscode-editor-foreground)';
    tip.style.boxShadow = '0 6px 18px rgba(0,0,0,0.22)';
    tip.style.zIndex = '9999';
    tip.style.display = 'none';
    document.body.appendChild(tip);

    const closeTip = () => { tip.style.display = 'none'; };
    root.addEventListener('mouseleave', closeTip);

    root.querySelectorAll('[data-verso-hover]').forEach((elt) => {
      elt.style.cursor = 'help';
      elt.addEventListener('mouseenter', (ev) => {
        const hoverId = elt.dataset.versoHover;
        const data = hoverId ? docs[hoverId] : null;
        if (!data) { closeTip(); return; }
        tip.innerHTML = data;
        tip.style.display = 'block';
        tip.style.left = Math.min(ev.clientX + 14, window.innerWidth - 480) + 'px';
        tip.style.top = Math.min(ev.clientY + 14, window.innerHeight - 260) + 'px';
      });
      elt.addEventListener('mousemove', (ev) => {
        if (tip.style.display === 'none') return;
        tip.style.left = Math.min(ev.clientX + 14, window.innerWidth - 480) + 'px';
        tip.style.top = Math.min(ev.clientY + 14, window.innerHeight - 260) + 'px';
      });
      elt.addEventListener('mouseleave', closeTip);
    });
  };

  const style = createElement(
    'style',
    null,
    '.verso-preview-html h1{font-size:1.15em;margin:0.4em 0 0.35em 0;}' +
    '.verso-preview-html h2{font-size:1.05em;margin:0.35em 0 0.3em 0;}' +
    '.verso-preview-html p{margin:0.3em 0;line-height:1.45;}'
  );

  const header = createElement(
    'div',
    {
      style: {
        fontSize: '11px',
        opacity: 0.7,
        marginBottom: '0.4em',
        textTransform: 'uppercase',
        letterSpacing: '0.04em'
      }
    },
    'Verso HTML preview'
  );

  const rendered = createElement('div', {
    className: 'verso-preview-html',
    ref: installHoverDocs,
    style: {
      marginTop: '0.25em',
      padding: '0.5em',
      border: '1px solid var(--vscode-panel-border)',
      borderRadius: '6px'
    },
    dangerouslySetInnerHTML: { __html: html || '' }
  });

  const raw = createElement(
    'details',
    { style: { marginTop: '0.5em' } },
    [
      createElement('summary', null, 'Raw HTML'),
      createElement('pre', { style: { whiteSpace: 'pre-wrap', marginTop: '0.5em' } }, html || '')
    ]
  );

  return createElement('div', null, [style, header, rendered, raw]);
}
"

public def saveHtmlPreviewWidgetAt (stx : Syntax) (html : String) (docs : Json := .mkObj []) : TermElabM Unit := do
  Lean.Widget.savePanelWidgetInfo
    htmlPreviewWidget.javascriptHash
    (pure <| .mkObj [("html", .str html), ("docs", docs)])
    stx

public def saveHtmlPreviewWidget (html : String) (docs : Json := .mkObj []) : TermElabM Unit := do
  saveHtmlPreviewWidgetAt (← getRef) html docs

end Verso.Doc.Concrete.PreviewWidget
