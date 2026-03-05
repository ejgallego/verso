/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import VersoManual
import VersoBlueprint.Commands.Common
import VersoBlueprint.Environment
import VersoBlueprint.Informal.Block
import VersoBlueprint.Lib.HoverRender
import VersoBlueprint.Lib.PreviewSource
import VersoBlueprint.PreviewCache
import VersoBlueprint.Profiling
import VersoBlueprint.Widget

open Verso Doc Elab
open Verso.Genre Manual
open Lean Lean.Elab
open Lean.Doc.Syntax

namespace Informal

structure InlineData where
  label : Data.Label
  block : Option BlockData
deriving FromJson, ToJson, Quote

private def blockHoverTitle (block : BlockData) : String :=
  match block.kind with
  | .proof => s!"Proof {block.count}"
  | .statement kind => s!"{kind} {block.count}"

private def usePreviewId (label : Data.Label) (block : BlockData) : String :=
  let facet := PreviewCache.Facet.ofInProgressKind block.kind
  s!"bp-uses-{Informal.HoverRender.previewKey (toString label)}-{facet.suffix}"

private def useLinkPreviewFallbackBody (label : Data.Label) : Verso.Output.Html :=
  open Verso.Output.Html in
  {{
    <div class="bp_code_hover_section">
      <span class="bp_code_hover_label">"Blueprint label"</span>
      <ul class="bp_code_hover_list">
        <li><code>s!"{label}"</code></li>
      </ul>
    </div>
  }}

private def wrapUseLinkPreview (node previewBody : Verso.Output.Html)
    (label : Data.Label) (block : BlockData) (emitTemplate : Bool) (texPrelude : String := "") :
    Verso.Output.Html :=
  let pid := usePreviewId label block
  let ptitle := blockHoverTitle block
  Informal.HoverRender.inlinePreviewNode emitTemplate node previewBody pid ptitle texPrelude

inline_extension Inline.informal (data : InlineData) where
  data := toJson data
  traverse id data _contents := do
    let .ok { label, block } := fromJson? (α := InlineData) data
      | logError s!"Malformed data in Inline.informal traversal: {data}"
        pure none
    let path := (← read).path
    if let some block := block then
      modify fun st =>
        Informal.HoverRender.registerInlinePreviewOwner st path (usePreviewId label block) id
      pure none
    else
      let some obj := (← get).getDomainObject? informalDomain label.toString
        | pure none
      let .ok bdata := fromJson? (α := BlockData) obj.data
        | logError s!"Malformed informal domain data for {label}: {obj.data}"
          pure none
      modify fun st =>
        Informal.HoverRender.registerInlinePreviewOwner st path (usePreviewId label bdata) id
      pure none
  extraCss := ([Informal.Commands.inlinePreviewCss] : List String)
  extraJs := ([Informal.Commands.previewHoverUtilsJs, Informal.Commands.inlineLinkPreviewJs] : List String)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun goI id data inlines => do
      let .ok { label, block } := fromJson? (α := InlineData) data
        | HtmlT.logError "Malformed data in Inline.informal traversal"
          pure .empty
      let st ← HtmlT.state
      let ctxt ← HtmlT.context
      let inPreviewRender ← Informal.HoverRender.inInlinePreviewRender
      let resolvedBlock : Option BlockData :=
        match block with
        | some b => some b
        | none =>
          match st.getDomainObject? informalDomain label.toString with
          | none => none
          | some obj =>
            match fromJson? (α := BlockData) obj.data with
            | .ok b => some b
            | .error _ => none
      let href : Option String :=
        match st.resolveDomainObject informalDomain label.toString with
        | .ok dest => some dest.relativeLink
        | .error _ => none
      let preview? ←
        if inPreviewRender then
          pure Option.none
        else
          Informal.PreviewSource.renderTraversalPreview? st
            (fun b =>
              Informal.HoverRender.withInlinePreviewRenderContext
                (Verso.Doc.Html.ToHtml.toHtml (genre := Verso.Genre.Manual) b))
            label
      let renderedInlines ← inlines.mapM goI
      match resolvedBlock with
      | none =>
        if inlines.isEmpty then
          return {{ <span> "[??]" </span> }}
        else
          return {{ <span> {{renderedInlines}} </span> }}
      | some block =>
        let labelText := s!"{label}"
        let plainContent : Verso.Output.Html :=
          if inlines.isEmpty then
            let titleText := blockHoverTitle block
            if let some href := href then
              {{<a href={{href}} title={{labelText}}>{{titleText}}</a>}}
            else
              {{<span title={{labelText}}>{{titleText}}</span>}}
          else if let some href := href then
            {{<a href={{href}} title={{labelText}}>{{renderedInlines}}</a>}}
          else
            renderedInlines
        if inPreviewRender then
          return {{<span>{{plainContent}}</span>}}
        let previewId := usePreviewId label block
        let emitTemplate := Informal.HoverRender.isInlinePreviewOwner st ctxt.path previewId id
        let (previewBody, texPrelude) :=
          match preview? with
          | some (rendered, texPrelude) => (Verso.Output.Html.seq rendered, texPrelude)
          | Option.none => (useLinkPreviewFallbackBody label, "")
        let hovered := wrapUseLinkPreview plainContent previewBody label block emitTemplate texPrelude
        return {{<span>{{hovered}}</span>}}
  toTeX := none

private def Data.Node.toBlockInfo (node : Data.Node) (label : Data.Label) : BlockData :=
  { kind := .statement node.kind, label, count := node.count }

private def usesImpl : RoleExpanderOf Config
  | cfg, contents => do
    let contents ← contents.mapM elabInline
    let label := cfg.label
    let node ← Environment.getNode? label
    let useRef ← getRef
    Environment.addDep useRef label
    -- Activate the widget if we can resolve the reference
    if node.isSome then
      activateForLabelDoc label useRef
    let data : InlineData := { label, block := node.map (fun n => n.toBlockInfo label) }
    ``(Inline.other (Inline.informal $(quote data)) #[$contents,*])

@[role]
def uses : RoleExpanderOf Config
  | cfg, contents => do
    Profile.withDocElab "role" "uses" <| usesImpl cfg contents

end Informal
