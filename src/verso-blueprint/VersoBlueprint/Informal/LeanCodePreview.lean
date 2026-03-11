/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Data
import VersoBlueprint.Informal.ExternalCode
import VersoBlueprint.Lib.HoverRender
import VersoBlueprint.PreviewRender

namespace Informal.LeanCodePreview

open Lean

abbrev ManualBlock := Verso.Doc.Block Verso.Genre.Manual

/--
Dedicated traversal domain for manifest-backed Lean declaration previews.

Unlike `PreviewCache`, this domain is only for previews attached to links that
target Lean declarations/definitions.
-/
def domainName : Name := Name.mkSimple "Informal.LeanCodePreview"

private def namespaceRoot : Name :=
  Name.str (Name.str .anonymous "Informal") "LeanCodePreview"

private partial def appendName (rootName : Name) (suffixName : Name) : Name :=
  match suffixName with
  | .anonymous => rootName
  | .str parent component => .str (appendName rootName parent) component
  | .num parent component => .num (appendName rootName parent) component

/--
Canonical internal preview target for one Lean declaration.

The preview namespace mirrors regular Lean names so the manifest keys stay
declaration-centric rather than blueprint-label-centric.
-/
def targetName (decl : Name) : Name :=
  appendName namespaceRoot decl.eraseMacroScopes

def lookupKey (decl : Name) : String :=
  (targetName decl).toString

def previewId (decl : Name) : String :=
  s!"bp-lean-code-{Informal.HoverRender.previewKey (lookupKey decl)}"

inductive Source where
  | inlineBlocks (blocks : Array ManualBlock)
  | externalDecl (decl : Informal.Data.ExternalRef)
deriving Inhabited, Repr, ToJson, FromJson

/--
Canonical declaration-preview payload.

Multiple Lean declaration names may legitimately point to the same inline code
block preview body, but each declaration keeps its own manifest key.
-/
structure Entry where
  target : Name
  source : Source
deriving Inhabited, Repr, ToJson, FromJson

def Entry.ofInlineBlocks (target : Name) (blocks : Array ManualBlock) : Entry :=
  { target := target.eraseMacroScopes, source := .inlineBlocks blocks }

def Entry.ofExternalDecl (target : Name) (decl : Informal.Data.ExternalRef) : Entry :=
  { target := target.eraseMacroScopes, source := .externalDecl decl }

def exists? (s : Verso.Genre.Manual.TraverseState) (decl : Name) : Bool :=
  (s.getDomainObject? domainName (lookupKey decl)).isSome

def title (decl : Name) : String :=
  s!"Lean declaration {decl}"

def renderHtmlWithState
    (entry : Entry)
    (impls : Verso.Genre.Manual.ExtensionImpls)
    (state : Verso.Genre.Manual.TraverseState) : IO Verso.Output.Html := do
  match entry.source with
  | .inlineBlocks blocks =>
    Informal.renderManualBlocksHtmlWithState blocks impls state
  | .externalDecl decl =>
    pure <| Informal.ExternalCode.renderPreviewHtml #[decl]

end Informal.LeanCodePreview
