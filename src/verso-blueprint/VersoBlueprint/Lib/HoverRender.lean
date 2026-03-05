/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual

namespace Informal.HoverRender

open Lean
open Verso.Output.Html

structure GraphPreviewUi where
  store : Verso.Output.Html := .empty
  panel : Verso.Output.Html := .empty

structure SummaryPreviewUi where
  store : Verso.Output.Html := .empty
  panel : Verso.Output.Html := .empty

private def hexDigits : Array Char := "0123456789ABCDEF".toList.toArray

private def toHex (n : Nat) : String := Id.run do
  let mut n := n
  let mut digits := #[]
  repeat
    if h : n < 16 then
      digits := digits.push hexDigits[n]
      break
    else
      digits := digits.push <| hexDigits[n % 16]'(by
        have : n % 16 < 16 := Nat.mod_lt _ (by decide)
        simpa using this)
      n := n >>> 4
  let padding := (4 - digits.size).fold (init := "") (fun _ _ p => p.push '0')
  digits.foldr (init := padding) fun c s => s.push c

def previewKey (s : String) : String :=
  s.foldl (init := "") fun acc c =>
    if c.isAlphanum then
      acc.push c
    else if c == '-' then
      acc |>.push '-' |>.push '-'
    else
      acc ++ s!"-{toHex c.toNat}"

def inlinePreviewStoreDomain : Name := Name.mkSimple "Informal.inlinePreview.store"

def inlinePreviewRenderProperty : Name := Name.mkSimple "Informal.inlinePreview.rendering"

def inlinePreviewMarkerBlock : Verso.Genre.Manual.Block := {
  name := Name.mkSimple "Informal.inlinePreview.marker"
  properties := ({} : Verso.NameMap String).insert inlinePreviewRenderProperty "1"
}

def inInlinePreviewRender [Monad m] :
    Verso.Doc.Html.HtmlT Verso.Genre.Manual m Bool := do
  let ctxt ← Verso.Doc.Html.HtmlT.context
  pure <| match ctxt.propertyValue inlinePreviewRenderProperty with
    | some "1" => true
    | _ => false

def inlinePreviewStoreKey (path : Array String) (previewId : String) : String :=
  s!"{String.intercalate "/" path.toList}::{previewId}"

def registerInlinePreviewOwner (state : Verso.Genre.Manual.TraverseState)
    (path : Array String) (previewId : String) (id : Verso.Genre.Manual.InternalId) :
    Verso.Genre.Manual.TraverseState :=
  let key := inlinePreviewStoreKey path previewId
  if (state.getDomainObject? inlinePreviewStoreDomain key).isSome then
    state
  else
    state.saveDomainObject inlinePreviewStoreDomain key id

def inlinePreviewOwnerId? (state : Verso.Genre.Manual.TraverseState)
    (path : Array String) (previewId : String) : Option Verso.Genre.Manual.InternalId :=
  let key := inlinePreviewStoreKey path previewId
  match state.getDomainObject? inlinePreviewStoreDomain key with
  | some obj => obj.ids.toArray[0]?
  | Option.none => Option.none

def isInlinePreviewOwner (state : Verso.Genre.Manual.TraverseState)
    (path : Array String) (previewId : String) (id : Verso.Genre.Manual.InternalId) : Bool :=
  match inlinePreviewOwnerId? state path previewId with
  | some owner => owner == id
  | Option.none => true

def graphPreviewTemplate (label : Name) (renderedBlocks : Array Verso.Output.Html)
    (texPrelude : String := "") : Verso.Output.Html := {{
  <template class="bp_graph_preview_tpl"
      "data-bp-preview-label"={{s!"{label}"}}>
    <script type="text/plain" class="bp_preview_tex_prelude">{{.text false texPrelude}}</script>
    {{renderedBlocks}}
  </template>
}}

def graphPreviewUi (templates : Array Verso.Output.Html) : GraphPreviewUi :=
  if templates.isEmpty then
    { store := .empty, panel := .empty }
  else
    {
      store := {{
        <div class="bp_graph_preview_store" hidden>
          {{templates}}
        </div>
      }}
      panel := {{
        <aside class="bp_graph_preview" hidden>
          <div class="bp_graph_preview_header">
            <div class="bp_graph_preview_title"></div>
            <button type="button" class="bp_graph_preview_close" aria-label="Close informal preview">"Close"</button>
          </div>
          <div class="bp_graph_preview_body"></div>
        </aside>
      }}
    }

def summaryPreviewTemplate (label : Name) (renderedBlocks : Array Verso.Output.Html)
    (texPrelude : String := "") : Verso.Output.Html := {{
  <template class="bp_summary_preview_tpl"
      "data-bp-preview-label"={{s!"{label}"}}>
    <script type="text/plain" class="bp_preview_tex_prelude">{{.text false texPrelude}}</script>
    {{renderedBlocks}}
  </template>
}}

def summaryPreviewUi (templates : Array Verso.Output.Html) : SummaryPreviewUi :=
  if templates.isEmpty then
    { store := .empty, panel := .empty }
  else
    {
      store := {{
        <div class="bp_summary_preview_store" hidden>
          {{templates}}
        </div>
      }}
      panel := {{
        <aside class="bp_summary_preview_panel" hidden>
          <div class="bp_summary_preview_panel_header">
            <div class="bp_summary_preview_panel_title"></div>
            <button type="button" class="bp_summary_preview_panel_close" aria-label="Close summary preview">"Close"</button>
          </div>
          <div class="bp_summary_preview_panel_body"></div>
        </aside>
      }}
    }

def summaryPreviewWrap (labelNode : Verso.Output.Html) (previewLabel? : Option Name) : Verso.Output.Html :=
  match previewLabel? with
  | some label => {{
      <span class="bp_summary_preview_wrap bp_summary_preview_wrap_active" "data-bp-preview-label"={{s!"{label}"}}>
        {{labelNode}}
      </span>
    }}
  | none => {{
      <span class="bp_summary_preview_wrap">
        {{labelNode}}
      </span>
    }}

def inlinePreviewTemplate (previewId : String) (body : Verso.Output.Html)
    (texPrelude : String := "") : Verso.Output.Html := {{
  <template class="bp_inline_preview_tpl" "data-bp-preview-id"={{previewId}}>
    <script type="text/plain" class="bp_preview_tex_prelude">{{.text false texPrelude}}</script>
    {{body}}
  </template>
}}

def inlinePreviewRef (node : Verso.Output.Html) (previewId previewTitle : String) : Verso.Output.Html := {{
  <span class="bp_inline_preview_ref" "data-bp-preview-id"={{previewId}} "data-bp-preview-title"={{previewTitle}}>
    {{node}}
  </span>
}}

def inlinePreviewEntry (node body : Verso.Output.Html)
    (previewId previewTitle : String) (texPrelude : String := "") : Verso.Output.Html := {{
  {{inlinePreviewRef node previewId previewTitle}}
  {{inlinePreviewTemplate previewId body texPrelude}}
}}

def inlinePreviewNode (emitTemplate : Bool) (node body : Verso.Output.Html)
    (previewId previewTitle : String) (texPrelude : String := "") : Verso.Output.Html :=
  if emitTemplate then
    inlinePreviewEntry node body previewId previewTitle texPrelude
  else
    inlinePreviewRef node previewId previewTitle

end Informal.HoverRender
