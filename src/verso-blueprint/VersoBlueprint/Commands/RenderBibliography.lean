/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Cite
import VersoBlueprint.Commands
import VersoBlueprint.Resolve

namespace Informal.Commands

open Lean Elab Command

open Verso Doc Elab Genre Manual in
block_extension Block.bibliography (biblio : BibliographyData) where
  data := toJson biblio
  traverse id data _contents := do
    let .ok biblio := fromJson? (α := BibliographyData) data
      | logError "Malformed data in Block.bibliography.traverse"
        return none
    let path ← (·.path) <$> read
    let _ ← Verso.Genre.Manual.externalTag id path s!"--bp-bibliography"
    for entry in biblio.entries do
      modify fun st =>
        st.saveDomainObject Resolve.bibliographyDomainName entry.label id
    return none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun goI _goB _id data _blocks => do
      let .ok data := fromJson? (α := BibliographyData) data
        | HtmlT.logError "Malformed data in Block.bibliography.toHtml"
          pure .empty
      let st ← HtmlT.state
      let entries := data.entries.toArray.qsort (fun a b => a.citation.sortKey < b.citation.sortKey)
      let rows ← entries.mapM fun entry => do
        let rendered ← entry.citation.bibHtml goI
        let itemId := s!"bp-bib-{Informal.Cite.citationAnchorId entry.label}"
        let usageHrefs := Resolve.resolveDomainHrefs st Resolve.citationUsageDomainName entry.label
        let usageData : Informal.Cite.CitationUsageData :=
          match st.getDomainObject? Resolve.citationUsageDomainName entry.label with
          | some obj =>
            match fromJson? (α := Informal.Cite.CitationUsageData) obj.data with
            | .ok data => data
            | .error _ => {}
          | Option.none => {}
        let usageDetails := usageData.uses.toArray.qsort (fun a b => a.href < b.href)
        let usageRows : Array Output.Html :=
          if usageDetails.isEmpty then
            usageHrefs.foldl (init := #[]) fun out href =>
              out.push {{<li><a href={{href}}>s!"Citation use {out.size + 1}"</a></li>}}
          else
            usageDetails.map fun use =>
              {{<li><a href={{use.href}}>{{.text true use.summary}}</a></li>}}
        let usageCount := if usageDetails.isEmpty then usageHrefs.size else usageDetails.size
        pure {{
          <li id={{itemId}}>
            {{rendered}}
            <details class="bp_summary_decls">
              <summary>s!"Cited from ({usageCount})"</summary>
              <ul class="bp_summary_decl_list">
                {{if usageRows.isEmpty then {{<li class="bp_summary_empty">"No citation uses recorded."</li>}} else usageRows}}
              </ul>
            </details>
          </li>
        }}
      pure {{
        <div class="bp_summary">
          <details class="bp_summary_section" open>
            <summary>s!"Bibliography ({entries.size})"</summary>
            <ul class="bp_summary_list">
              {{if rows.isEmpty then {{<li class="bp_summary_empty">"No bibliography entries registered."</li>}} else rows}}
            </ul>
          </details>
        </div>
      }}
  extraCss := singleton ⟨d3DotCss⟩
  extraJs := singleton ⟨openTargetDetailsJs⟩

end Informal.Commands
