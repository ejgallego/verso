/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Lean
import VersoManual
import VersoBlueprint.Informal.Block
import VersoBlueprint.Lib.HoverRender
import VersoBlueprint.PreviewCache
import VersoBlueprint.Resolve

namespace Informal.PreviewManifest

open Lean
open Verso Doc
open Verso.Genre Manual

structure Entry where
  key : String
  label : Name
  facet : PreviewCache.Facet
  title : String
  html : String
deriving Inhabited, Repr, ToJson, FromJson

structure File where
  previews : Array Entry := #[]
deriving Inhabited, Repr, ToJson, FromJson

private def outDirForMode (cfg : Verso.Genre.Manual.Config) (mode : Mode) : System.FilePath :=
  cfg.destination / (match mode with | .single => "html-single" | .multi => "html-multi")

private def blockTitle (state : TraverseState) (label : Name) : String :=
  match state.getDomainObject? Resolve.informalDomainName label.toString with
  | none => label.toString
  | some obj =>
    match fromJson? (α := Informal.BlockData) obj.data with
    | .ok blockData => blockData.withResolvedNumbering state |>.displayTitle state
    | .error _ => label.toString

private def renderPreviewHtml
    (impls : ExtensionImpls)
    (state : TraverseState)
    (blocks : Array (Doc.Block Manual)) : IO String := do
  let opts : Doc.Html.Options (ReaderT Multi.AllRemotes (ReaderT ExtensionImpls IO)) := {
    headerLevel := 1
    logError := fun _ => pure ()
  }
  let ctxt : TraverseContext := {
    path := #[]
    headers := #[]
    blockContext := #[]
    draft := false
    logError := fun _ => pure ()
  }
  let definitionIds : Lean.NameMap String := {}
  let linkTargets : Code.LinkTargets TraverseContext := state.localTargets
  let codeOptions : Code.HighlightHtmlM.Options := {}
  let remotes : Multi.AllRemotes := {}
  let block := Verso.Doc.Block.concat blocks
  let htmlContext : Verso.Doc.Html.HtmlT.Context Manual (ReaderT Multi.AllRemotes (ReaderT ExtensionImpls IO)) := {
    options := opts
    traverseContext := ctxt
    traverseState := state
    definitionIds := definitionIds
    linkTargets := linkTargets
    codeOptions := codeOptions
  }
  let htmlState :=
    Informal.HoverRender.withInlinePreviewRenderContext <|
      Verso.Doc.Html.ToHtml.toHtml (genre := Manual) block
  let (html, _hover) ← ((htmlState htmlContext).run {}).run remotes |>.run impls
  pure <| Output.Html.asString html

private def buildEntries
    (impls : ExtensionImpls)
    (logError : String → IO Unit)
    (state : TraverseState) : IO (Array Entry) := do
  let some domain := state.domains.get? Resolve.informalPreviewDomainName
    | return #[]
  let mut entries := #[]
  for (_key, obj) in domain.objects.toArray do
    match fromJson? (α := PreviewCache.Entry) obj.data with
    | .error err =>
      logError s!"Preview manifest: malformed preview entry {obj.canonicalName}: {err}"
    | .ok entry =>
      if entry.blocks.isEmpty then
        continue
      let html ← renderPreviewHtml impls state entry.blocks
      if html.trimAscii.isEmpty then
        continue
      let key := PreviewCache.key entry.label entry.facet
      let manifestEntry : Entry := {
        key
        label := entry.label
        facet := entry.facet
        title := blockTitle state entry.label
        html
      }
      entries := entries.push manifestEntry
  pure <| entries.qsort (fun a b => a.key < b.key)

def emitSharedPreviewManifest : ExtraStep := fun mode logError cfg state _text => do
  let impls ← read
  let previews ← buildEntries impls logError state
  let outDir := outDirForMode cfg mode
  let dataDir := outDir / "-verso-data"
  IO.FS.createDirAll dataDir
  let json := toString <| toJson ({ previews } : File)
  IO.FS.writeFile (dataDir / "bp-previews.json") json

end Informal.PreviewManifest
