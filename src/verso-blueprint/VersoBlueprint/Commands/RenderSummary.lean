/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Commands
import VersoBlueprint.Lib.HoverRender
import VersoBlueprint.Lib.PreviewSource
import VersoBlueprint.Resolve

namespace Informal.Commands

open Lean Elab Command

open Verso Doc Elab Genre Manual in
block_extension Block.summary (summary : Summary) where
  data := toJson summary
  traverse _id _data _contents := do
    return none
  toTeX := none
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB _id data _blocks => do
      let .ok data := fromJson? (α := Summary) data
        | HtmlT.logError "Malformed data in Block.summary.toHtml"
          pure .empty
      let s ← HtmlT.state
      let getEntryHref (label : Name) : Option String :=
        Resolve.resolveDomainHref? s Resolve.informalDomainName label.toString
      let getCodeHref (label : Name) : Option String :=
        Resolve.resolveDomainHref? s Resolve.informalCodeDomainName label.toString
      let getDeclHref (decl : Name) : Option String :=
        Resolve.resolveExampleDeclHref? s decl
      let mkEntryRef (label : Name) := do
        let preview? : Option Output.Html ←
          match Informal.PreviewSource.traversalBlocks? s label with
          | Option.none => pure none
          | some blocks =>
            let rendered ← blocks.mapM goB
            pure <| some (Informal.HoverRender.summaryPreview label rendered)
        let labelNode : Output.Html :=
          match getEntryHref label with
          | Option.some href => {{ <a href={{href}}> <code>s!"{label}"</code> </a> }}
          | Option.none => {{ <code>s!"{label}"</code> }}
        pure (Informal.HoverRender.summaryPreviewWrap labelNode preview?)
      let mkDeclItems (decls : List Name) :=
        decls.toArray.map fun decl =>
          match getDeclHref decl with
          | Option.some href => {{ <li><a href={{href}}> <code>s!"{decl}"</code> </a></li> }}
          | Option.none => {{ <li><code>s!"{decl}"</code></li> }}
      let mkLeanRow (label : Name) (kind : String) (leanObjects : List Name) := do
        let entryRef ← mkEntryRef label
        let codeHref := getCodeHref label
        let associatedDecls := !leanObjects.isEmpty
        pure {{ <li>
                  <span class="bp_summary_item_head">{{entryRef}}</span>
                  <span class="bp_summary_item_meta">s!"({kind})"</span>
                  {{if associatedDecls then
                     {{<details class="bp_summary_decls"><summary>s!"Associated lean decls ({leanObjects.length})"</summary><ul class="bp_summary_decl_list">{{mkDeclItems leanObjects}}</ul></details>}}
                    else
                     {{<span></span>}}}}
                  {{if let some href := codeHref then
                     {{<div class="bp_summary_item_body">"Lean code: " <a class="bp_code_link" href={{href}}>"code"</a></div>}}
                    else
                     {{<span></span>}}}}
                </li> }}
      let pendingProofRows ←
        data.pendingInformalProofEntries.toArray.mapM fun item =>
          mkLeanRow item.label item.kind item.leanObjects
      let sorryRows ←
        data.sorryDetails.toArray.mapM fun item => do
          let entryRef ← mkEntryRef item.label
          let codeHref := getCodeHref item.label
          let declLink :=
            match getDeclHref item.decl with
            | Option.some href => {{ <a href={{href}}> <code>s!"{item.decl}"</code> </a> }}
            | Option.none => {{ <code>s!"{item.decl}"</code> }}
          let hasTypeGap := item.status.hasTypeGap
          let hasProofGap := item.status.hasProofGap
          let typeSorryRefs :=
            match item.status with
            | .containsSorry info =>
              info.foldl (init := 0) fun acc s =>
                if s.location == .statement then acc + s.refs?.getD 0 else acc
            | _ => 0
          let proofSorryRefs :=
            match item.status with
            | .containsSorry info =>
              info.foldl (init := 0) fun acc s =>
                if s.location == .proof then acc + s.refs?.getD 0 else acc
            | _ => 0
          let whereTxt :=
            match item.status with
            | .axiomLike => "axiom-like (no body)"
            | .containsSorry _ =>
              if hasTypeGap && hasProofGap then
                "in statement and proof"
              else if hasTypeGap then
                "in statement"
              else if hasProofGap then
                "in proof"
              else
                "location unknown"
            | .proved => "proved"
          let sorryRefs := typeSorryRefs + proofSorryRefs
          let refsTxt :=
            match item.status with
            | .axiomLike => "n/a"
            | .containsSorry _ =>
              if sorryRefs > 0 then toString sorryRefs else "unknown"
            | .proved => "0"
          let sorryLinks : Array Output.Html :=
            match codeHref with
            | Option.none => #[]
            | some href =>
              let stmtLinks :=
                if typeSorryRefs > 0 then
                  #[{{ <a class="bp_code_link" href={{href}} title="Go to Lean code with statement gap">s!"in statement ({typeSorryRefs})"</a> }}]
                else
                  #[]
              let proofLinks :=
                if proofSorryRefs > 0 then
                  #[{{ <a class="bp_code_link" href={{href}} title="Go to Lean code with proof gap">s!"in proof ({proofSorryRefs})"</a> }}]
                else
                  #[]
              let links := stmtLinks ++ proofLinks
              if links.isEmpty then
                match item.status with
                | .axiomLike =>
                  #[{{ <a class="bp_code_link" href={{href}} title="Go to Lean declaration">"declaration"</a> }}]
                | .containsSorry _ =>
                  if sorryRefs > 0 then
                    #[{{ <a class="bp_code_link" href={{href}}>s!"in code ({sorryRefs})"</a> }}]
                  else
                    #[{{ <a class="bp_code_link" href={{href}}> "in code" </a> }}]
                | .proved => #[]
              else
                links
          let statusLabel :=
            match item.status with
            | .axiomLike => "axiom-like"
            | .containsSorry _ => "contains sorry"
            | .proved => "proved"
          let declPrefix :=
            match item.status with
            | .axiomLike => "Axiom-like declaration: "
            | .containsSorry _ => "Declaration with sorry: "
            | .proved => "Declaration: "
          pure {{ <li>
                    <span class="bp_summary_item_head">{{entryRef}}</span>
                    <span class="bp_summary_item_meta">s!"({item.kind})"</span>
                    <div class="bp_summary_item_body">
                      {{.text true declPrefix}} {{declLink}} " "
                      <span class="bp_summary_badge">
                        s!"[{if item.isTheorem then "theorem/lemma" else "definition"}; {statusLabel}; {whereTxt}; refs: {refsTxt}]"
                      </span>
                    </div>
                    {{if Array.isEmpty sorryLinks then
                       {{<span></span>}}
                      else
                       {{<div class="bp_summary_item_body">"Jump: " {{(sorryLinks.toList.intersperse {{<span>" | "</span>}}).toArray}}</div>}}}}
                  </li> }}
      let missingRows ←
        data.missingLeanDecls.toArray.mapM fun item => do
          let entryRef ← mkEntryRef item.label
          let codeHref := getCodeHref item.label
          let canonicalNode : Output.Html :=
            match getDeclHref item.canonical with
            | Option.some href => {{ <a href={{href}}> <code>s!"{item.canonical}"</code> </a> }}
            | Option.none => {{ <code>s!"{item.canonical}"</code> }}
          let declNode : Output.Html :=
            if item.written == item.canonical then
              canonicalNode
            else
              {{ <span> <code>s!"{item.written}"</code> " (resolved as " {{canonicalNode}} ")" </span> }}
          pure {{ <li>
                    <span class="bp_summary_item_head">{{entryRef}}</span>
                    <span class="bp_summary_item_meta">s!"({item.kind})"</span>
                    <div class="bp_summary_item_body">
                      "Missing external Lean declaration: " {{declNode}} " "
                      <span class="bp_summary_badge">"[missing declaration]"</span>
                    </div>
                    {{if let some href := codeHref then
                       {{<div class="bp_summary_item_body">"Jump: " <a class="bp_code_link" href={{href}}>"code"</a></div>}}
                      else
                       {{<span></span>}}}}
                  </li> }}
      let definitionRows ←
        data.definitionIndex.toArray.mapM fun item =>
          mkLeanRow item.label item.kind item.leanObjects
      let theoremLikeRows ←
        data.theoremLikeIndex.toArray.mapM fun item =>
          mkLeanRow item.label item.kind item.leanObjects
      let theoremLikeByParentRows ←
        data.theoremLikeByParent.toArray.mapM fun group => do
          let rows ← group.entries.toArray.mapM fun item =>
            mkLeanRow item.label item.kind item.leanObjects
          pure {{
            <details class="bp_summary_subsection">
              <summary>s!"{group.header} ({group.entries.length})"</summary>
              <ul class="bp_summary_list">
                {{if rows.isEmpty then {{<li class="bp_summary_empty">"No theorem/lemma/corollary entries in this parent group."</li>}} else rows}}
              </ul>
            </details>
          }}
      return {{
        <div class="bp_summary">
          <details class="bp_summary_section" open>
            <summary>s!"Blueprint DB entries ({data.totalEntries})"</summary>
            <div class="bp_summary_grid">
              <div class="bp_summary_card"><span class="bp_summary_label">"Total entries"</span><span class="bp_summary_value">s!"{data.totalEntries}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Definitions"</span><span class="bp_summary_value">s!"{data.definitions}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Lemmas"</span><span class="bp_summary_value">s!"{data.lemmas}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Theorems"</span><span class="bp_summary_value">s!"{data.theorems}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Corollaries"</span><span class="bp_summary_value">s!"{data.corollaries}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Lean-only entries"</span><span class="bp_summary_value">s!"{data.leanOnlyEntries}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Informal-only entries"</span><span class="bp_summary_value">s!"{data.informalOnlyEntries}"</span></div>
            </div>
            <details class="bp_summary_subsection">
              <summary>s!"Definition Index ({data.definitionIndex.length})"</summary>
              <ul class="bp_summary_list">
                {{if definitionRows.isEmpty then {{<li class="bp_summary_empty">"No definitions registered."</li>}} else definitionRows}}
              </ul>
            </details>
            <details class="bp_summary_subsection">
              <summary>s!"Theorem / Lemma / Corollary Index ({data.theoremLikeIndex.length})"</summary>
              <ul class="bp_summary_list">
                {{if theoremLikeRows.isEmpty then {{<li class="bp_summary_empty">"No theorem/lemma/corollary entries registered."</li>}} else theoremLikeRows}}
              </ul>
            </details>
            <details class="bp_summary_subsection">
              <summary>s!"Theorem / Lemma / Corollary by Parent ({data.theoremLikeByParent.length})"</summary>
              {{if theoremLikeByParentRows.isEmpty then
                 {{<div class="bp_summary_empty">"No parent groups declared for theorem-like entries."</div>}}
                else
                 theoremLikeByParentRows}}
            </details>
          </details>
          <details class="bp_summary_section" open>
            <summary>"Lean progress"</summary>
            <div class="bp_summary_grid">
              <div class="bp_summary_card"><span class="bp_summary_label">"Lean definitions/theorems"</span><span class="bp_summary_value">s!"{data.leanDecls}"</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Entries with informal proof pending"</span><span class="bp_summary_value">s!"{data.pendingInformalProofEntries.length}"</span></div>
              <div class="bp_summary_card bp_summary_placeholder"><span class="bp_summary_label">"Missing external Lean declarations"</span><span class="bp_summary_value">s!"{data.missingLeanDecls.length}"</span></div>
              <div class="bp_summary_card bp_summary_placeholder"><span class="bp_summary_label">"Incomplete Lean declarations"</span><span class="bp_summary_value">s!"{data.sorries}"</span></div>
            </div>
            <details class="bp_summary_subsection">
              <summary>s!"Lean code with informal proof pending ({data.pendingInformalProofEntries.length})"</summary>
              <ul class="bp_summary_list">
                {{if pendingProofRows.isEmpty then {{<li class="bp_summary_empty">"No pending informal proofs."</li>}} else pendingProofRows}}
              </ul>
            </details>
            <details class="bp_summary_subsection bp_summary_placeholder">
              <summary>s!"Missing external Lean declarations ({data.missingLeanDecls.length})"</summary>
              <ul class="bp_summary_list">
                {{if missingRows.isEmpty then {{<li class="bp_summary_empty">"No missing external Lean declarations."</li>}} else missingRows}}
              </ul>
            </details>
            <details class="bp_summary_subsection bp_summary_placeholder">
              <summary>s!"Incomplete details ({data.sorryDetails.length})"</summary>
              <ul class="bp_summary_list">
                {{if sorryRows.isEmpty then {{<li class="bp_summary_empty">"No incomplete declarations detected."</li>}} else sorryRows}}
              </ul>
            </details>
          </details>
        </div>
      }}
  extraCss := singleton ⟨d3DotCss⟩
  extraJs := singleton ⟨openTargetDetailsJs⟩

end Informal.Commands
