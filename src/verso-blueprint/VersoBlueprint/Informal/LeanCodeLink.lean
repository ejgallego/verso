/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Data
import VersoBlueprint.Lib.HoverRender

namespace Informal.LeanCodeLink

open Lean
open Verso.Output.Html

/--
`LeanCodeLink` is the narrow HTML helper for links that target Lean
declarations/definitions and should carry a manifest-backed hover preview.

It intentionally does not compute blueprint/code-status summaries; that remains
the responsibility of `Informal.CodeSummary`.
-/
private def namespaceRoot : Name :=
  Name.str (Name.str .anonymous "Informal") "LeanCodePreview"

private partial def appendName (rootName : Name) (suffixName : Name) : Name :=
  match suffixName with
  | .anonymous => rootName
  | .str parent component => .str (appendName rootName parent) component
  | .num parent component => .num (appendName rootName parent) component

def previewLookupKey (decl : Name) : String :=
  (appendName namespaceRoot decl.eraseMacroScopes).toString

def previewId (decl : Name) : String :=
  s!"bp-lean-code-{Informal.HoverRender.previewKey (previewLookupKey decl)}"

private def renderLinkNode
    (node : Verso.Output.Html) (href? : Option String)
    (className : String) (title? : Option String) : Verso.Output.Html :=
  let attrs :=
    if className.isEmpty then
      #[]
    else
      #[("class", className)]
  let attrs :=
    match title? with
    | some title => attrs.push ("title", title)
    | none => attrs
  match href? with
  | some href => .tag "a" (attrs.push ("href", href)) node
  | none => .tag "span" attrs node

def renderResolved
    (decl : Name)
    (node : Verso.Output.Html)
    (className : String := "")
    (href? : Option String := none)
    (linkTitle? : Option String := none)
    (previewTitle : String := s!"Lean declaration {decl}")
    (previewDetail? : Option String := none) : Verso.Output.Html :=
  let linkNode := renderLinkNode node href? className linkTitle?
  Informal.HoverRender.inlinePreviewNode
    false linkNode .empty
    (previewId decl)
    previewTitle
    (previewLookupKey? := some (previewLookupKey decl))
    (previewFallbackDetail? := previewDetail?)

def renderText
    (decl : Name)
    (text : String)
    (className : String := "")
    (href? : Option String := none)
    (linkTitle? : Option String := none)
    (previewTitle : String := s!"Lean declaration {decl}")
    (previewDetail? : Option String := none) : Verso.Output.Html :=
  renderResolved decl (.text true text) className href? linkTitle? previewTitle previewDetail?

def renderResolvedText
    (decl : Name)
    (text : String)
    (className : String := "")
    (href? : Option String := none)
    (linkTitle? : Option String := none)
    (previewTitle : String := s!"Lean declaration {decl}")
    (previewDetail? : Option String := none) : Verso.Output.Html :=
  renderResolved decl (.text true text) className href? linkTitle? previewTitle previewDetail?

end Informal.LeanCodeLink
