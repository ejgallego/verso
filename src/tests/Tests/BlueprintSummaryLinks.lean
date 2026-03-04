/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import VersoBlueprint
import VersoManual

namespace Verso.Tests.BlueprintSummaryLinks

open Verso
open Verso.Genre.Manual
open Informal

set_option doc.verso true

#docs (Genre.Manual) externalSummaryLinksDoc "External Summary Links" :=
:::::::
:::definition "def:external.summary" (lean := "Nat.succ")
External declaration wiring test.
:::

{bp_summary}
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

private def renderManualBlocksHtml (blocks : Array (Doc.Block Genre.Manual)) : IO Output.Html := do
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
  pure html

private def hasSubstr (s needle : String) : Bool :=
  (s.splitOn needle).length > 1

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let blocks := collectBlocks externalSummaryLinksDoc.toPart
    let html ← renderManualBlocksHtml blocks
    let out := html.asString
    pure (
      hasSubstr out "class=\"bp_summary_decl_list\"" &&
      hasSubstr out "href=\"#--informal-external-decl-" &&
      hasSubstr out "class=\"bp_external_decl_item bp_external_decl_item_rendered\" id=\"--informal-external-decl-"
    )

end Verso.Tests.BlueprintSummaryLinks
