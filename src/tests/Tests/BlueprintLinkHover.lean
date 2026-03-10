/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import VersoBlueprint
import VersoManual
import VersoManual.Bibliography

namespace Verso.Tests.BlueprintLinkHover

open Verso
open Verso.Genre.Manual
open Informal

set_option doc.verso true

@[bib "hover.cite"]
def hover.cite : Verso.Genre.Manual.Bibliography.Citable := .arXiv
  { title := inlines!"Hover target citation"
  , authors := #[inlines!"A. Author", inlines!"B. Author"]
  , year := 2026
  , id := "hover.cite"
  }

#docs (Genre.Manual) hoverLinkDoc "Hover Link Doc" :=
:::::::
:::lemma_ "lem:hover.link"
Using {uses "lem:hover.link"}[], see {Informal.citet hover.cite (kind := lemma) (index := 3)}[].
:::

{bp_bibliography}
:::::::

#docs (Genre.Manual) hoverUsesDedupDoc "Hover Uses Dedup Doc" :=
:::::::
:::lemma_ "lem:hover.base"
Base lemma for repeated references.
:::

:::lemma_ "lem:hover.dedup"
Using {uses "lem:hover.base"}[] and again {uses "lem:hover.base"}[].
:::
:::::::

#docs (Genre.Manual) hoverCiteOnlyDoc "Hover Cite Only Doc" :=
:::::::
Cite once {Informal.citet hover.cite (kind := lemma) (index := 3)}[] and cite twice
{Informal.citet hover.cite (kind := lemma) (index := 3)}[].

{bp_bibliography}
:::::::

private partial def collectBlocks (part : Doc.Part Genre.Manual) : Array (Doc.Block Genre.Manual) :=
  let childBlocks := part.subParts.foldl (init := #[]) fun acc child =>
    acc ++ collectBlocks child
  part.content ++ childBlocks

private def initTraverseState (impls : ExtensionImpls) : TraverseState :=
  Id.run do
    let mut st : TraverseState := TraverseState.initialize {}
    for ⟨_, b⟩ in impls.blockDescrs do
      if let some descr := b.get? BlockDescr then
        st := descr.init st
    for ⟨_, i⟩ in impls.inlineDescrs do
      if let some descr := i.get? InlineDescr then
        st := descr.init st
    return st

private def traverseManualBlocks
    (blocks : Array (Doc.Block Genre.Manual))
    (impls : ExtensionImpls) :
    IO (Array (Doc.Block Genre.Manual) × TraverseState) := do
  let ctxt : TraverseContext := { logError := fun _ => pure () }
  let mut st := initTraverseState impls
  let mut cur := blocks
  for _ in [0:4] do
    let (next, st') ← TraverseM.run impls ctxt st <| cur.mapM Verso.Genre.Manual.traverseBlock
    if next == cur && st' == st then
      return (next, st')
    cur := next
    st := st'
  return (cur, st)

private def renderManualBlocksHtmlAndState
    (blocks : Array (Doc.Block Genre.Manual)) : IO (Output.Html × TraverseState) := do
  let impls : ExtensionImpls := extension_impls%
  let opts : Doc.Html.Options (ReaderT Multi.AllRemotes (ReaderT ExtensionImpls IO)) := {
    headerLevel := 1
    logError := fun _ => pure ()
  }
  let (blocks, st) ← traverseManualBlocks blocks impls
  let ctxt : TraverseContext := { logError := fun _ => pure () }
  let definitionIds : Lean.NameMap String := {}
  let linkTargets : Code.LinkTargets TraverseContext := {}
  let codeOptions : Code.HighlightHtmlM.Options := {}
  let remotes : Multi.AllRemotes := {}
  let block := Doc.Block.concat blocks
  let htmlState := Verso.Genre.Manual.toHtml opts ctxt st definitionIds linkTargets codeOptions block
  let (html, _hover) ← ((htmlState.run {}).run remotes).run impls
  pure (html, st)

private def renderManualBlocksHtml (blocks : Array (Doc.Block Genre.Manual)) : IO Output.Html := do
  let (html, _st) ← renderManualBlocksHtmlAndState blocks
  pure html

private def hasSubstr (s needle : String) : Bool :=
  (s.splitOn needle).length > 1

private def countSubstr (s needle : String) : Nat :=
  (s.splitOn needle).length.pred

private def hasExtraJs (st : TraverseState) (needle : String) : Bool :=
  st.toHtmlAssets.extraJs.toArray.any (fun js => hasSubstr js.js needle)

private def hasExtraCss (st : TraverseState) (needle : String) : Bool :=
  st.toHtmlAssets.extraCss.toArray.any (fun css => hasSubstr css.css needle)

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let blocks := collectBlocks hoverLinkDoc.toPart
    let html ← renderManualBlocksHtml blocks
    let out := html.asString
    pure (
      countSubstr out "class=\"bp_inline_preview_ref\"" >= 3 &&
      hasSubstr out "class=\"bp_inline_preview_tpl\"" &&
      hasSubstr out "Bibliography: hover.cite" &&
      hasSubstr out "#bp-bib-hover-cite" &&
      hasSubstr out "class=\"bp_bibliography_use_line\"" &&
      hasSubstr out "data-bp-preview-key=\"«lem:hover.link»--statement\"" &&
      hasSubstr out "data-bp-preview-fallback-label=\"«lem:hover.link»\""
    )

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let blocks := collectBlocks hoverUsesDedupDoc.toPart
    let html ← renderManualBlocksHtml blocks
    let out := html.asString
    pure (
      countSubstr out "class=\"bp_inline_preview_ref\"" >= 2 &&
      countSubstr out
          "data-bp-preview-key=\"«lem:hover.base»--statement\"" >= 2 &&
      countSubstr out
          "data-bp-preview-fallback-label=\"«lem:hover.base»\"" >= 2 &&
      countSubstr out
          "class=\"bp_inline_preview_tpl\" data-bp-preview-id=\"bp-uses--00ABlem-003Ahover-002Ebase-00BB-statement\"" == 1
    )

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let blocks := collectBlocks hoverCiteOnlyDoc.toPart
    let (html, st) ← renderManualBlocksHtmlAndState blocks
    let out := html.asString
    pure (
      countSubstr out "class=\"bp_inline_preview_ref\"" == 2 &&
      countSubstr out "class=\"bp_inline_preview_tpl\"" == 1 &&
      hasExtraJs st "bindInlinePreview" &&
      hasExtraCss st ".bp_inline_preview_panel"
    )

end Verso.Tests.BlueprintLinkHover
