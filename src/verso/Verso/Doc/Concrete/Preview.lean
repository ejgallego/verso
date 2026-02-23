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
import Verso.Doc
public import Verso.Output.Html

public section

register_option verso.doc.preview.logForTest : Bool := {
  defValue := false
  descr := "Emit #doc/#docs HTML preview as an info log message (for tests)"
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

private unsafe def previewRenderersForUnsafe (genreConst : Name) : TermElabM (Array PreviewRenderer) := do
  let renderers := previewRendererAttr.getEntries (← getEnv) genreConst
  pure <| renderers.map (·.value) |>.toArray

@[implemented_by previewRenderersForUnsafe]
private opaque previewRenderersFor (genreConst : Name) : TermElabM (Array PreviewRenderer)

private unsafe def genreConstName? (genre : TSyntax `term) : TermElabM (Option Name) := do
  try
    let genreExpr ← Term.elabTerm genre (some (.const ``Doc.Genre []))
    let genreExpr ← instantiateMVars genreExpr
    match genreExpr.getAppFn with
    | .const name _ => pure (some name)
    | _ => pure none
  catch _ =>
    pure none

private unsafe def getRegisteredRenderer (genre : TSyntax `term) : TermElabM PreviewRenderer := do
  let some genreConst ← genreConstName? genre
    | throwError "Couldn't resolve #doc preview genre to a constant name"
  let renderers ← previewRenderersFor genreConst
  let some renderer := renderers.back?
    | throwError m!"No HTML preview renderer registered for genre '{genreConst}'. Register one with @[doc_preview_renderer {genreConst}]."
  pure renderer

private unsafe def renderHtmlUnsafe (genre : TSyntax `term) (part : TSyntax `term) : TermElabM Output.Html := do
  let renderer ← getRegisteredRenderer genre
  renderer genre part

@[implemented_by renderHtmlUnsafe]
private opaque renderHtml (genre : TSyntax `term) (part : TSyntax `term) : TermElabM Output.Html

private unsafe def emitHtmlPreviewUnsafe (genre : TSyntax `term) (part : TSyntax `term) : TermElabM Unit := do
  let logForTest : Bool := (← getOptions).get `verso.doc.preview.logForTest false
  if !logForTest then
    pure ()
  else
    logInfo (← renderHtml genre part).asString

@[implemented_by emitHtmlPreviewUnsafe]
public opaque emitHtmlPreview (genre : TSyntax `term) (part : TSyntax `term) : TermElabM Unit

end Verso.Doc.Concrete.Preview
