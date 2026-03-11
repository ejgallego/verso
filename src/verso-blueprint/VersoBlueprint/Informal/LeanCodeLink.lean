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
import VersoBlueprint.PreviewCache
import VersoBlueprint.Resolve

namespace Informal.LeanCodeLink

open Lean
open Verso.Output.Html

def previewId (label : Informal.Data.Label) : String :=
  s!"bp-lean-code-{Informal.HoverRender.previewKey (toString label)}"

def previewLookupKey (label : Informal.Data.Label) : String :=
  PreviewCache.key label .code

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
    (label : Informal.Data.Label)
    (node : Verso.Output.Html)
    (className : String := "bp_code_link")
    (href? : Option String := none)
    (linkTitle? : Option String := none)
    (previewTitle : String := "Lean code")
    (previewDetail? : Option String := none) : Verso.Output.Html :=
  let linkNode := renderLinkNode node href? className linkTitle?
  Informal.HoverRender.inlinePreviewNode
    false linkNode .empty
    (previewId label)
    previewTitle
    (previewLookupKey? := some (previewLookupKey label))
    (previewFallbackDetail? := previewDetail?)

def render
    (state : Verso.Genre.Manual.TraverseState)
    (label : Informal.Data.Label)
    (node : Verso.Output.Html)
    (className : String := "bp_code_link")
    (href? : Option String := none)
    (linkTitle? : Option String := none)
    (previewTitle : String := "Lean code")
    (previewDetail? : Option String := none) : Verso.Output.Html :=
  let href? := href? <|> Resolve.resolveInformalCodeHref? state label
  renderResolved label node className href? linkTitle? previewTitle previewDetail?

def renderText
    (state : Verso.Genre.Manual.TraverseState)
    (label : Informal.Data.Label)
    (text : String)
    (className : String := "bp_code_link")
    (href? : Option String := none)
    (linkTitle? : Option String := none)
    (previewTitle : String := "Lean code")
    (previewDetail? : Option String := none) : Verso.Output.Html :=
  render state label (.text true text) className href? linkTitle? previewTitle previewDetail?

def renderResolvedText
    (label : Informal.Data.Label)
    (text : String)
    (className : String := "bp_code_link")
    (href? : Option String := none)
    (linkTitle? : Option String := none)
    (previewTitle : String := "Lean code")
    (previewDetail? : Option String := none) : Verso.Output.Html :=
  renderResolved label (.text true text) className href? linkTitle? previewTitle previewDetail?

end Informal.LeanCodeLink
