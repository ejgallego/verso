/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import VersoBlueprint
import VersoManual

namespace Verso.Tests.Blueprint.Support

open Verso
open Verso.Genre.Manual

def hasSubstr (s needle : String) : Bool :=
  (s.splitOn needle).length > 1

def countSubstr (s needle : String) : Nat :=
  (s.splitOn needle).length.pred

def appearsBefore (s lhs rhs : String) : Bool :=
  match s.splitOn lhs with
  | _ :: tail => hasSubstr (String.intercalate lhs tail) rhs
  | [] => false

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

/-- Keep extension impls explicit so each test renders with its own imported extension set. -/
def renderManualDocHtmlAndState
    (impls : ExtensionImpls)
    (doc : Doc.VersoDoc Genre.Manual) : IO (Output.Html × TraverseState) := do
  let opts : Doc.Html.Options (ReaderT Multi.AllRemotes (ReaderT ExtensionImpls IO)) := {
    headerLevel := 1
    logError := fun _ => pure ()
  }
  let (blocks, st) ← traverseManualBlocks (collectBlocks doc.toPart) impls
  let ctxt : TraverseContext := { logError := fun _ => pure () }
  let definitionIds : Lean.NameMap String := {}
  let linkTargets : Code.LinkTargets TraverseContext := {}
  let codeOptions : Code.HighlightHtmlM.Options := {}
  let remotes : Multi.AllRemotes := {}
  let block := Doc.Block.concat blocks
  let htmlState := Verso.Genre.Manual.toHtml opts ctxt st definitionIds linkTargets codeOptions block
  let (html, _hover) ← ((htmlState.run {}).run remotes).run impls
  pure (html, st)

def renderManualDocHtml (impls : ExtensionImpls) (doc : Doc.VersoDoc Genre.Manual) : IO Output.Html := do
  let (html, _st) ← renderManualDocHtmlAndState impls doc
  pure html

def renderManualDocHtmlStringAndState
    (impls : ExtensionImpls)
    (doc : Doc.VersoDoc Genre.Manual) : IO (String × TraverseState) := do
  let (html, st) ← renderManualDocHtmlAndState impls doc
  pure (html.asString, st)

def renderManualDocHtmlString (impls : ExtensionImpls) (doc : Doc.VersoDoc Genre.Manual) : IO String := do
  let html ← renderManualDocHtml impls doc
  pure html.asString

def findExtraJsContaining? (st : TraverseState) (needle : String) : Option String :=
  st.toHtmlAssets.extraJs.toArray.findSome? fun js =>
    if hasSubstr js.js needle then some js.js else none

def hasExtraJs (st : TraverseState) (needle : String) : Bool :=
  st.toHtmlAssets.extraJs.toArray.any fun js => hasSubstr js.js needle

def hasExtraCss (st : TraverseState) (needle : String) : Bool :=
  st.toHtmlAssets.extraCss.toArray.any fun css => hasSubstr css.css needle

end Verso.Tests.Blueprint.Support
