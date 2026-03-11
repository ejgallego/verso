/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Lean
import VersoManual
import VersoBlueprint.Informal.Block
import VersoBlueprint.PreviewCache
import VersoBlueprint.PreviewRender
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
      let html ← Output.Html.asString <$> Informal.renderManualBlocksHtmlWithState entry.blocks impls state
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

/--
Emit the canonical `bp-previews.json` manifest.

Block preview bodies are expected to be consumed from the manifest rather than
embedded as page-local label preview templates.
-/
def emitSharedPreviewManifest : ExtraStep := fun mode logError cfg state _text => do
  let impls ← read
  let previews ← buildEntries impls logError state
  let outDir := outDirForMode cfg mode
  let dataDir := outDir / "-verso-data"
  IO.FS.createDirAll dataDir
  let json := (toJson ({ previews } : File)).compress
  IO.FS.writeFile (dataDir / "bp-previews.json") json

end Informal.PreviewManifest
