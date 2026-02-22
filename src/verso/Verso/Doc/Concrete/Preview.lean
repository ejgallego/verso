/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/
module
public import Lean.Data.Options
import Lean.Meta.Eval
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

private meta unsafe def renderHtmlUnsafe (genre : TSyntax `term) (part : TSyntax `term) : TermElabM String := do
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

@[implemented_by renderHtmlUnsafe]
private meta opaque renderHtml (genre : TSyntax `term) (part : TSyntax `term) : TermElabM String

private meta def emitHtmlPreviewUnsafe (genre : TSyntax `term) (part : TSyntax `term) : TermElabM Unit := do
  try
    let html ← renderHtml genre part
    let logForTest : Bool := (← getOptions).get `verso.doc.preview.logForTest false
    if logForTest then
      logInfo html
    else
      pure ()
  catch _ =>
    pure ()

@[implemented_by emitHtmlPreviewUnsafe]
public meta opaque emitHtmlPreview (genre : TSyntax `term) (part : TSyntax `term) : TermElabM Unit

end Verso.Doc.Concrete.Preview
