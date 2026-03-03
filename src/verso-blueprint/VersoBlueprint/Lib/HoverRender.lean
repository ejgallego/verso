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

def graphPreviewTemplate (label : Name) (renderedBlocks : Array Verso.Output.Html) : Verso.Output.Html := {{
  <template class="bp_graph_preview_tpl" "data-bp-preview-label"={{s!"{label}"}}>
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
        <aside id="bp-graph-preview" class="bp_graph_preview" hidden>
          <div class="bp_graph_preview_header">
            <div class="bp_graph_preview_title"></div>
            <button type="button" class="bp_graph_preview_close" aria-label="Close informal preview">"Close"</button>
          </div>
          <div class="bp_graph_preview_body"></div>
        </aside>
      }}
    }

def summaryPreview (label : Name) (rendered : Array Verso.Output.Html) : Verso.Output.Html := {{
  <div class="bp_summary_preview" role="tooltip">
    <div class="bp_summary_preview_title"><code>s!"{label}"</code></div>
    <div class="bp_summary_preview_body">{{rendered}}</div>
  </div>
}}

def summaryPreviewWrap (labelNode : Verso.Output.Html) (preview? : Option Verso.Output.Html) : Verso.Output.Html := {{
  <span class="bp_summary_preview_wrap">
    {{labelNode}}
    {{if let some preview := preview? then preview else .empty}}
  </span>
}}

end Informal.HoverRender
