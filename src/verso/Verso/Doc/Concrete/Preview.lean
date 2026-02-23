/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Lean.Data.Options
public import Lean.KeyedDeclsAttribute
import Lean.Meta.Eval
import Verso.Doc.Elab.ExpanderAttribute
import Verso.Doc
import Verso.Doc.Html
public meta import Verso.Doc.Html
public meta import Verso.Output.Html

public section

register_option verso.doc.preview.logForTest : Bool := {
  defValue := false
  descr := "Emit #doc/#docs HTML preview as an info log message (for tests)"
}

end

namespace Verso.Doc.Concrete.Preview

open Lean Verso Doc Elab

public abbrev PreviewRenderer := TSyntax `term → TSyntax `term → TermElabM String

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

private def eraseGenreInline {g : Genre} : Inline g → Inline Genre.none :=
  Inline.rewriteOther fun recur _ content => .concat <| content.map recur

private def eraseGenreBlock {g : Genre} : Block g → Block Genre.none :=
  Block.rewriteOther
    (fun recur _ content => .concat <| content.map recur)
    (fun _ recur _ content => .concat <| content.map recur)

private partial def eraseGenrePart {g : Genre} (p : Part g) : Part Genre.none :=
  .mk
    (p.title.map eraseGenreInline)
    p.titleString
    none
    (p.content.map eraseGenreBlock)
    (p.subParts.map eraseGenrePart)

private unsafe def renderHtmlWithRegisteredRenderer? (genre : TSyntax `term) (part : TSyntax `term) : TermElabM (Option String) := do
  let some genreConst ← genreConstName? genre
    | return none
  let renderers ← previewRenderersFor genreConst
  let some renderer := renderers.back?
    | return none
  try
    return some (← renderer genre part)
  catch _ =>
    return none

private unsafe def renderHtmlGenericUnsafe (genre : TSyntax `term) (part : TSyntax `term) : TermElabM String := do
  let erasedPartTy ← Term.elabType (← `(Part Genre.none))
  let erasedPartExpr ← Term.elabTermAndSynthesize
    (← `(eraseGenrePart (g := $genre) ($part : Part $genre)))
    (some erasedPartTy)
  let erasedPart ← Meta.evalExpr (Part Genre.none) erasedPartTy erasedPartExpr
  let opts : Verso.Doc.Html.Options Id := {
    headerLevel := 1
    logError := fun _ => pure ()
  }
  let (html, _) := (Genre.none.toHtml (m := Id) opts () () {} {} {} erasedPart).run {}
  pure html.asString

private unsafe def renderHtmlUnsafe (genre : TSyntax `term) (part : TSyntax `term) : TermElabM String := do
  if let some html ← renderHtmlWithRegisteredRenderer? genre part then
    pure html
  else
    renderHtmlGenericUnsafe genre part

@[implemented_by renderHtmlUnsafe]
private opaque renderHtml (genre : TSyntax `term) (part : TSyntax `term) : TermElabM String

private unsafe def emitHtmlPreviewUnsafe (genre : TSyntax `term) (part : TSyntax `term) : TermElabM Unit := do
  let logForTest : Bool := (← getOptions).get `verso.doc.preview.logForTest false
  if !logForTest then
    pure ()
  else
    try
      logInfo (← renderHtml genre part)
    catch _ =>
      pure ()

@[implemented_by emitHtmlPreviewUnsafe]
public opaque emitHtmlPreview (genre : TSyntax `term) (part : TSyntax `term) : TermElabM Unit

end Verso.Doc.Concrete.Preview
