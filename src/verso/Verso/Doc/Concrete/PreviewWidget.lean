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

export default function ({ html }) {
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

  return createElement('div', null, [header, rendered, raw]);
}
"

public def saveHtmlPreviewWidget (html : String) : TermElabM Unit := do
  Lean.Widget.savePanelWidgetInfo
    htmlPreviewWidget.javascriptHash
    (pure <| .mkObj [("html", .str html)])
    (← getRef)

end Verso.Doc.Concrete.PreviewWidget
