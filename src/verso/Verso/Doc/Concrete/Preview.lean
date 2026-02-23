/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Lean.Data.Options
public import Lean.KeyedDeclsAttribute
public import Lean.Elab.Term.TermElabM
import Lean.Meta.Eval
import Verso.Doc.Elab.ExpanderAttribute
import Verso.Doc.Concrete.PreviewWidget
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
      Verso.Doc.Concrete.PreviewWidget.saveHtmlPreviewWidget html.asString

end Verso.Doc.Concrete.Preview
