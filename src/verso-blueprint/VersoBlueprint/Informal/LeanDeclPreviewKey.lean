/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Lean
import VersoBlueprint.Lib.HoverRender

namespace Informal.LeanDeclPreviewKey

open Lean

private def namespaceRoot : Name :=
  Name.str (Name.str .anonymous "Informal") "LeanCodePreview"

private partial def appendName (rootName : Name) (suffixName : Name) : Name :=
  match suffixName with
  | .anonymous => rootName
  | .str parent component => .str (appendName rootName parent) component
  | .num parent component => .num (appendName rootName parent) component

def targetName (decl : Name) : Name :=
  appendName namespaceRoot decl.eraseMacroScopes

def lookupKey (decl : Name) : String :=
  (targetName decl).toString

def previewId (decl : Name) : String :=
  s!"bp-lean-code-{Informal.HoverRender.previewKey (lookupKey decl)}"

end Informal.LeanDeclPreviewKey
