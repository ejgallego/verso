/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Lean.Data.Options
public import Lean.KeyedDeclsAttribute
public import Lean.Elab.Term.TermElabM
import Lean.Widget.UserWidget
import Lean.Meta.Eval
import Verso.Doc.Elab.ExpanderAttribute
import Verso.Doc
public import Verso.Output.Html

public section

register_option verso.doc.preview.logForTest : Bool := {
  defValue := false
  descr := "Emit #doc/#docs HTML preview as an info log message (for tests)"
}

register_option verso.doc.preview.widget : Bool := {
  defValue := false
  descr := "Attach #doc/#docs HTML preview as an infoview panel widget"
}

end

namespace Verso.Doc.Concrete.Preview

open Lean Verso Doc Elab Term

public abbrev PreviewRenderer := TSyntax `term → TSyntax `term → TermElabM Output.Html

initialize previewRendererAttr : KeyedDeclsAttribute PreviewRenderer ←
  Verso.Doc.Elab.mkDocExpanderAttribute
    `doc_preview_renderer
    ``PreviewRenderer
    "Registers a #doc/#docs preview renderer keyed by genre constant"
    `previewRendererAttr

@[widget_module]
def htmlPreviewWidget : Lean.Widget.Module where
  javascript := "
import { createElement } from 'react';

export default function ({ html }) {
  const rendered = createElement('div', {
    style: {
      marginTop: '0.5em',
      padding: '0.75em',
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

  return createElement('div', null, [
    createElement('strong', null, 'Verso HTML preview'),
    rendered,
    raw
  ]);
}
"

private def previewRenderersFor (genreConst : Name) : TermElabM (Array PreviewRenderer) := do
  let renderers := previewRendererAttr.getEntries (← getEnv) genreConst
  pure <| renderers.map (·.value) |>.toArray

private def genreConstName? (genre : TSyntax `term) : TermElabM (Option Name) := do
  try
    let genreExpr ← Term.elabTerm genre (some (.const ``Doc.Genre []))
    let genreExpr ← instantiateMVars genreExpr
    match genreExpr.getAppFn with
    | .const name _ => pure (some name)
    | _ => pure none
  catch _ =>
    pure none

private def getRegisteredRenderer (genre : TSyntax `term) : TermElabM PreviewRenderer := do
  let some genreConst ← genreConstName? genre
    | throwError "Couldn't resolve #doc preview genre to a constant name"
  let renderers ← previewRenderersFor genreConst
  let some renderer := renderers.back?
    | throwError m!"No HTML preview renderer registered for genre '{genreConst}'. Register one with @[doc_preview_renderer {genreConst}]."
  pure renderer

private def renderHtml (genre : TSyntax `term) (part : TSyntax `term) : TermElabM Output.Html := do
  let renderer ← getRegisteredRenderer genre
  renderer genre part

public def emitHtmlPreview (genre : TSyntax `term) (part : TSyntax `term) : TermElabM Unit := do
  let logForTest : Bool := (← getOptions).get `verso.doc.preview.logForTest false
  let showWidget : Bool := (← getOptions).get `verso.doc.preview.widget false
  if !logForTest && !showWidget then
    pure ()
  else
    let html ← renderHtml genre part
    if logForTest then
      logInfo html.asString
    if showWidget then
      Lean.Widget.savePanelWidgetInfo
        htmlPreviewWidget.javascriptHash
        (pure <| .mkObj [("html", .str html.asString)])
        genre

end Verso.Doc.Concrete.Preview
