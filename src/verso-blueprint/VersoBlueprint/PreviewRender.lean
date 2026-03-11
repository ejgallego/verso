/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import VersoManual
import VersoBlueprint.Lib.HoverRender

namespace Informal

private def initTraverseState (impls : Verso.Genre.Manual.ExtensionImpls) : Verso.Genre.Manual.TraverseState :=
  Id.run do
    let mut st : Verso.Genre.Manual.TraverseState := Verso.Genre.Manual.TraverseState.initialize {}
    for ⟨_, b⟩ in impls.blockDescrs do
      if let some descr := b.get? Verso.Genre.Manual.BlockDescr then
        st := descr.init st
    for ⟨_, i⟩ in impls.inlineDescrs do
      if let some descr := i.get? Verso.Genre.Manual.InlineDescr then
        st := descr.init st
    return st

private def traverseManualBlocks
    (blocks : Array (Verso.Doc.Block Verso.Genre.Manual))
    (impls : Verso.Genre.Manual.ExtensionImpls) :
    IO (Array (Verso.Doc.Block Verso.Genre.Manual) × Verso.Genre.Manual.TraverseState) := do
  let ctxt : Verso.Genre.Manual.TraverseContext := {
    logError := fun _ => pure ()
  }
  let mut st := initTraverseState impls
  let mut cur := blocks
  for _ in [0:4] do
    let (next, st') ← Verso.Genre.Manual.TraverseM.run impls ctxt st <| cur.mapM Verso.Genre.Manual.traverseBlock
    if next == cur && st' == st then
      return (next, st')
    cur := next
    st := st'
  return (cur, st)

def renderManualBlocksHtmlWithState
    (blocks : Array (Verso.Doc.Block Verso.Genre.Manual))
    (impls : Verso.Genre.Manual.ExtensionImpls)
    (st : Verso.Genre.Manual.TraverseState)
    (linkTargets : Verso.Code.LinkTargets Verso.Genre.Manual.TraverseContext := st.localTargets) :
    IO Verso.Output.Html := do
  let opts : Verso.Doc.Html.Options (ReaderT Verso.Multi.AllRemotes (ReaderT Verso.Genre.Manual.ExtensionImpls IO)) := {
    headerLevel := 1
    logError := fun _ => pure ()
  }
  let ctxt : Verso.Genre.Manual.TraverseContext := {
    logError := fun _ => pure ()
  }
  let definitionIds : Lean.NameMap String := {}
  let codeOptions : Verso.Code.HighlightHtmlM.Options := {}
  let remotes : Verso.Multi.AllRemotes := {}
  let block := Verso.Doc.Block.concat blocks
  let htmlContext : Verso.Doc.Html.HtmlT.Context Verso.Genre.Manual (ReaderT Verso.Multi.AllRemotes (ReaderT Verso.Genre.Manual.ExtensionImpls IO)) := {
    options := opts
    traverseContext := ctxt
    traverseState := st
    definitionIds := definitionIds
    linkTargets := linkTargets
    codeOptions := codeOptions
  }
  let htmlState :=
    Informal.HoverRender.withInlinePreviewRenderContext <|
      Verso.Doc.Html.ToHtml.toHtml (genre := Verso.Genre.Manual) block
  let (html, _hover) ← ((htmlState htmlContext).run {}).run remotes |>.run impls
  pure html

private def renderManualBlocksHtml
    (blocks : Array (Verso.Doc.Block Verso.Genre.Manual))
    (impls : Verso.Genre.Manual.ExtensionImpls) : IO Verso.Output.Html := do
  let (blocks, st) ← traverseManualBlocks blocks impls
  renderManualBlocksHtmlWithState blocks impls st

private unsafe def evalElaboratedBlocksUnsafe (stxs : Array Lean.Syntax) :
    Lean.Elab.Term.TermElabM (Array (Verso.Doc.Block Verso.Genre.Manual)) := do
  if stxs.isEmpty then
    pure #[]
  else
    let tyExpr ← Lean.Elab.Term.elabType (← `(Verso.Doc.Block Verso.Genre.Manual))
    stxs.mapM fun stx => do
      let expr ← Lean.Elab.Term.elabTermAndSynthesize stx (some tyExpr)
      Lean.Meta.evalExpr (Verso.Doc.Block Verso.Genre.Manual) tyExpr expr

/-- Evaluate elaborated Manual block terms back into Manual blocks. -/
@[implemented_by evalElaboratedBlocksUnsafe]
opaque evalElaboratedBlocks
    (stxs : Array Lean.Syntax) :
    Lean.Elab.Term.TermElabM (Array (Verso.Doc.Block Verso.Genre.Manual))

private unsafe def getExtensionImpls : Lean.Elab.Term.TermElabM Verso.Genre.Manual.ExtensionImpls := do
  let tyExpr ← Lean.Elab.Term.elabType (← `(Verso.Genre.Manual.ExtensionImpls))
  let implExpr ← Lean.Elab.Term.elabTermAndSynthesize (← `(extension_impls%)) (some tyExpr)
  Lean.Meta.evalExpr Verso.Genre.Manual.ExtensionImpls tyExpr implExpr

private unsafe def renderPreviewBlocksHtmlUnsafe
    (blocks : Array (Verso.Doc.Block Verso.Genre.Manual)) : Lean.Elab.Term.TermElabM Verso.Output.Html := do
  let impls ← getExtensionImpls
  monadLift <| renderManualBlocksHtml blocks impls

/-- Render manual preview blocks to HTML using the manual renderer. -/
@[implemented_by renderPreviewBlocksHtmlUnsafe]
opaque renderPreviewBlocksHtml
    (blocks : Array (Verso.Doc.Block Verso.Genre.Manual)) : Lean.Elab.Term.TermElabM Verso.Output.Html

/-- Render cached elaborated statement blocks to HTML using the manual renderer. -/
private unsafe def renderStatementElabHtmlUnsafe (stxs : Array Lean.Syntax) : Lean.Elab.Term.TermElabM Verso.Output.Html := do
  let blocks ← evalElaboratedBlocks stxs
  renderPreviewBlocksHtml blocks

/-- Render cached elaborated statement blocks to HTML using the manual renderer. -/
@[implemented_by renderStatementElabHtmlUnsafe]
opaque renderStatementElabHtml (stxs : Array Lean.Syntax) : Lean.Elab.Term.TermElabM Verso.Output.Html

end Informal
