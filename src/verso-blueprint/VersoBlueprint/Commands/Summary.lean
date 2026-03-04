/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Lean.Elab.Command
import Verso
import VersoManual
import VersoBlueprint.Commands.Common
import VersoBlueprint.Data
import VersoBlueprint.Environment
import VersoBlueprint.Informal.CodeCommon
import VersoBlueprint.Lib.HoverRender
import VersoBlueprint.Lib.PreviewSource
import VersoBlueprint.Resolve

namespace Informal.Commands

open Lean Elab Command
open Informal Data Environment

structure SorryItem where
  label : Name
  kind : String
  decl : Name
  isTheorem : Bool := false
  status : Data.ProvedStatus := .proved
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote SorryItem where
  quote s := mkCApp ``SorryItem.mk #[quote s.label, quote s.kind, quote s.decl, quote s.isTheorem, quote s.status]

structure MissingLeanDeclItem where
  label : Name
  kind : String
  written : Name
  canonical : Name
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote MissingLeanDeclItem where
  quote s := mkCApp ``MissingLeanDeclItem.mk #[quote s.label, quote s.kind, quote s.written, quote s.canonical]

structure IndexItem where
  label : Name
  kind : String
  leanObjects : List Name := []
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote IndexItem where
  quote s := mkCApp ``IndexItem.mk #[quote s.label, quote s.kind, quote s.leanObjects]

abbrev PendingInformalItem := IndexItem

structure ParentTheoremGroup where
  parent : Name
  header : String := ""
  entries : List IndexItem := []
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote ParentTheoremGroup where
  quote s := mkCApp ``ParentTheoremGroup.mk #[quote s.parent, quote s.header, quote s.entries]

structure Summary where
  totalEntries : Nat := 0
  definitions : Nat := 0
  lemmas : Nat := 0
  theorems : Nat := 0
  corollaries : Nat := 0
  leanOnlyEntries : Nat := 0
  informalOnlyEntries : Nat := 0
  pendingInformalEntries : List PendingInformalItem := []
  leanDecls : Nat := 0
  sorries : Nat := 0
  sorryDetails : List SorryItem := []
  missingLeanDecls : List MissingLeanDeclItem := []
  definitionIndex : List IndexItem := []
  theoremLikeIndex : List IndexItem := []
  theoremLikeByParent : List ParentTheoremGroup := []
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote Summary where
  quote s := mkCApp ``Summary.mk
    #[
      quote s.totalEntries,
      quote s.definitions,
      quote s.lemmas,
      quote s.theorems,
      quote s.corollaries,
      quote s.leanOnlyEntries,
      quote s.informalOnlyEntries,
      quote s.pendingInformalEntries,
      quote s.leanDecls,
      quote s.sorries,
      quote s.sorryDetails,
      quote s.missingLeanDecls,
      quote s.definitionIndex,
      quote s.theoremLikeIndex,
      quote s.theoremLikeByParent
    ]

private def countSorries (decls : Array α) (statusOf : α → Data.ProvedStatus) : Nat :=
  decls.foldl (init := 0) fun acc decl =>
    let status := statusOf decl
    acc + (if status.isIncomplete then 1 else 0)

private def collectSorries (label : Name) (kind : String) (decls : Array α)
    (nameOf : α → Name) (statusOf : α → Data.ProvedStatus) (isTheorem : α → Bool) :
    List SorryItem :=
  decls.foldl (init := []) fun acc decl =>
    let status := statusOf decl
    if status.isIncomplete then
      {
        label
        kind
        decl := nameOf decl
        isTheorem := isTheorem decl
        status
      } :: acc
    else
      acc

private def mkIndexItem (label : Name) (kind : Data.NodeKind) (leanObjects : List Name := []) : IndexItem :=
  { label, kind := toString kind, leanObjects }

private def nodeLeanObjects (node : Data.Node) : List Name :=
  match node.code with
  | some (.external decls) => (decls.map (·.canonical)).toList
  | some (.literate code) => (code.definedDefs.map (·.name) ++ code.definedTheorems.map (·.name)).toList
  | _ => []

private def addParentTheoremLikeItem (groups : NameMap (List IndexItem)) (parent : Name) (item : IndexItem) :
    NameMap (List IndexItem) :=
  groups.insert parent (item :: groups.getD parent [])

private def sorryRefsByLocation (status : Data.ProvedStatus) : Nat × Nat :=
  match status with
  | .containsSorry info =>
    info.foldl (init := (0, 0)) fun (typeRefs, proofRefs) s =>
      match s.location with
      | .statement => (typeRefs + s.refs?.getD 0, proofRefs)
      | .proof => (typeRefs, proofRefs + s.refs?.getD 0)
  | _ => (0, 0)

def buildSummary : CoreM Summary := do
  let env ← getEnv
  let state := informalExt.getState env
  let entries := state.data.toArray
  let parentChildren := state.data.parentChildren
  let groupHeaders := state.groups
  let summary := entries.foldl (init := ({} : Summary)) fun acc (label, node) =>
      let hasStatement := node.statement.isSome
      let hasProof := node.proof.isSome
      let hasCode := node.code.isSome
      let (leanDecls, sorries, leanObjects, sorryDetails, missingLeanDecls) :=
        match node.code with
        | none => (0, 0, ([] : List Name), ([] : List SorryItem), ([] : List MissingLeanDeclItem))
        | some .userOk =>
          (0, 0, ([] : List Name), ([] : List SorryItem), ([] : List MissingLeanDeclItem))
        | some (.external decls) =>
          let leanObjects := nodeLeanObjects node
          let missingDecls :=
            decls.foldl (init := []) fun acc decl =>
              if !decl.present then
                {
                  label
                  kind := toString node.kind
                  written := decl.written
                  canonical := decl.canonical
                } :: acc
              else
                acc
          let incompleteDecls :=
            decls.foldl (init := #[]) fun acc decl =>
              if !decl.present then
                acc
              else
                let status := decl.provedStatus
                if status.isIncomplete then
                  acc.push (decl.canonical, status)
                else
                  acc
          let sorryDetails :=
            incompleteDecls.toList.map fun (decl, status) =>
              {
                label
                kind := toString node.kind
                decl
                isTheorem := (decls.find? (fun d => d.canonical == decl)).map (·.isTheoremLike) |>.getD false
                status
              }
          (decls.size, incompleteDecls.size, leanObjects, sorryDetails, missingDecls)
        | some (.literate code) =>
          let kind := toString node.kind
          let leanObjects := nodeLeanObjects node
          let leanDecls := code.definedDefs.size + code.definedTheorems.size
          let sorries :=
            countSorries code.definedDefs (fun (d : Data.LiterateDef) => d.provedStatus) +
            countSorries code.definedTheorems (fun (d : Data.LiterateThm) => d.provedStatus)
          let sorryDetails :=
            collectSorries label kind code.definedDefs
              (fun (d : Data.LiterateDef) => d.name)
              (fun (d : Data.LiterateDef) => d.provedStatus)
              (fun _ => false) ++
            collectSorries label kind code.definedTheorems
              (fun (d : Data.LiterateThm) => d.name)
              (fun (d : Data.LiterateThm) => d.provedStatus)
              (fun _ => true)
          (leanDecls, sorries, leanObjects, sorryDetails, ([] : List MissingLeanDeclItem))
      let pendingInformalEntries : List PendingInformalItem :=
        if hasCode && ((node.kind.isTheoremLike && !hasProof) || !hasStatement) then
          mkIndexItem label node.kind leanObjects :: acc.pendingInformalEntries
        else
          acc.pendingInformalEntries
      let definitionIndex : List IndexItem :=
        if node.kind == Data.NodeKind.definition then
          mkIndexItem label node.kind leanObjects :: acc.definitionIndex
        else
          acc.definitionIndex
      let theoremLikeIndex : List IndexItem :=
        if node.kind.isTheoremLike then
          mkIndexItem label node.kind leanObjects :: acc.theoremLikeIndex
        else
          acc.theoremLikeIndex
      let acc := { acc with
        totalEntries := acc.totalEntries + 1
        leanOnlyEntries := acc.leanOnlyEntries + (if hasCode && !hasStatement then 1 else 0)
        informalOnlyEntries := acc.informalOnlyEntries + (if hasStatement && !hasCode then 1 else 0)
        pendingInformalEntries
        leanDecls := acc.leanDecls + leanDecls
        sorries := acc.sorries + sorries
        sorryDetails := sorryDetails ++ acc.sorryDetails
        missingLeanDecls := missingLeanDecls ++ acc.missingLeanDecls
        definitionIndex
        theoremLikeIndex
      }
      match node.kind with
      | Data.NodeKind.definition => { acc with definitions := acc.definitions + 1 }
      | Data.NodeKind.lemma => { acc with lemmas := acc.lemmas + 1 }
      | Data.NodeKind.theorem => { acc with theorems := acc.theorems + 1 }
      | Data.NodeKind.corollary => { acc with corollaries := acc.corollaries + 1 }
  let theoremLikeByParent : List ParentTheoremGroup :=
    let grouped := entries.foldl (init := ({} : NameMap (List IndexItem))) fun acc (label, node) =>
      if node.kind.isTheoremLike then
        let leanObjects := nodeLeanObjects node
        match node.parent with
        | some parent =>
          let item : IndexItem := mkIndexItem label node.kind leanObjects
          addParentTheoremLikeItem acc parent item
        | none => acc
      else
        acc
    grouped.toArray.toList.foldr (init := []) fun (parent, items) acc =>
      if (parentChildren.getD parent #[]).size <= 1 then
        acc
      else
        let header := groupHeaders.getD parent parent.toString
        { parent, header, entries := items.reverse } :: acc
  return { summary with theoremLikeByParent }

def summaryCss := include_str "summary.css"

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
      let getDeclHref (label : Name) (decl : Name) : Option String :=
        match Resolve.resolveRenderedExternalDeclHref? s label decl with
        | Option.some href => Option.some href
        | Option.none => Resolve.resolveInlineLeanDeclHref? s decl
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
      let mkDeclItems (label : Name) (decls : List Name) :=
        decls.toArray.map fun decl =>
          match getDeclHref label decl with
          | Option.some href => {{ <li><a href={{href}}> <code>s!"{decl}"</code> </a></li> }}
          | Option.none => {{ <li><code>s!"{decl}"</code></li> }}
      let mkLeanRow (label : Name) (kind : String) (leanObjects : List Name) := do
        let entryRef ← mkEntryRef label
        let codeHref := getCodeHref label
        let associatedDecls := !leanObjects.isEmpty
        pure {{ <li class="bp_summary_item">
                  <div class="bp_summary_item_top">
                    <span class="bp_summary_item_head">{{entryRef}}</span>
                    <span class="bp_summary_item_meta">s!"({kind})"</span>
                  </div>
                  {{if associatedDecls then
                     {{<details class="bp_summary_decls"><summary>s!"Associated lean decls ({leanObjects.length})"</summary><ul class="bp_summary_decl_list">{{mkDeclItems label leanObjects}}</ul></details>}}
                    else
                     .empty}}
                  {{if let some href := codeHref then
                     {{<div class="bp_summary_item_actions">"Lean code: " <a class="bp_code_link" href={{href}}>"code"</a></div>}}
                    else
                     .empty}}
                </li> }}
      let pendingInformalRows ←
        data.pendingInformalEntries.toArray.mapM fun item =>
          mkLeanRow item.label item.kind item.leanObjects
      let sorryRows ←
        data.sorryDetails.toArray.mapM fun item => do
          let entryRef ← mkEntryRef item.label
          let codeHref := getCodeHref item.label
          let declLink :=
            match getDeclHref item.label item.decl with
            | Option.some href => {{ <a href={{href}}> <code>s!"{item.decl}"</code> </a> }}
            | Option.none => {{ <code>s!"{item.decl}"</code> }}
          let statusInfo ←
            match item.status with
            | .missing =>
              pure ("missing", "Missing declaration: ", "bp_summary_badge bp_summary_badge_error",
                provedStatusLocationText item.status, "n/a", 0, 0, 0)
            | .axiomLike =>
              pure ("axiom-like", "Axiom-like declaration: ", "bp_summary_badge bp_summary_badge_warn",
                provedStatusLocationText item.status, "n/a", 0, 0, 0)
            | .containsSorry _ =>
              let hasTypeGap := item.status.hasTypeGap
              let hasProofGap := item.status.hasProofGap
              let (typeSorryRefs, proofSorryRefs) := sorryRefsByLocation item.status
              let sorryRefs := typeSorryRefs + proofSorryRefs
              let refsTxt := if sorryRefs > 0 then toString sorryRefs else "unknown"
              let whereTxt :=
                if hasTypeGap && hasProofGap then
                  "in statement and proof"
                else
                  provedStatusLocationText item.status
              pure ("contains sorry", "Declaration with sorry: ", "bp_summary_badge bp_summary_badge_warn",
                whereTxt, refsTxt, typeSorryRefs, proofSorryRefs, sorryRefs)
            | .proved =>
              HtmlT.logError s!"Unexpected proved status in summary sorry details for {item.decl}"
              pure ("proved", "Declaration: ", "bp_summary_badge", "proved", "0", 0, 0, 0)
          let (statusLabel, declPrefix, badgeClass, whereTxt, refsTxt, typeSorryRefs, proofSorryRefs, sorryRefs) := statusInfo
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
                | .missing =>
                  #[{{ <a class="bp_code_link" href={{href}} title="Go to Lean code">"in code"</a> }}]
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
          pure {{ <li class="bp_summary_item">
                    <div class="bp_summary_item_top">
                      <span class="bp_summary_item_head">{{entryRef}}</span>
                      <span class="bp_summary_item_meta">s!"({item.kind})"</span>
                    </div>
                    <div class="bp_summary_item_body">
                      {{.text true declPrefix}} {{declLink}} " "
                      <span class={{badgeClass}}>
                        s!"[{if item.isTheorem then "theorem/lemma" else "definition"}; {statusLabel}; {whereTxt}; refs: {refsTxt}]"
                      </span>
                    </div>
                    {{if Array.isEmpty sorryLinks then
                       .empty
                      else
                       {{<div class="bp_summary_item_actions">"Jump: " {{(sorryLinks.toList.intersperse {{<span class="bp_summary_sep">" | "</span>}}).toArray}}</div>}}}}
                  </li> }}
      let missingRows ←
        data.missingLeanDecls.toArray.mapM fun item => do
          let entryRef ← mkEntryRef item.label
          let codeHref := getCodeHref item.label
          let canonicalNode : Output.Html :=
            match getDeclHref item.label item.canonical with
            | Option.some href => {{ <a href={{href}}> <code>s!"{item.canonical}"</code> </a> }}
            | Option.none => {{ <code>s!"{item.canonical}"</code> }}
          let declNode : Output.Html :=
            if item.written == item.canonical then
              canonicalNode
            else
              {{ <span> <code>s!"{item.written}"</code> " (resolved as " {{canonicalNode}} ")" </span> }}
          pure {{ <li class="bp_summary_item">
                    <div class="bp_summary_item_top">
                      <span class="bp_summary_item_head">{{entryRef}}</span>
                      <span class="bp_summary_item_meta">s!"({item.kind})"</span>
                    </div>
                    <div class="bp_summary_item_body">
                      "Missing external Lean declaration: " {{declNode}} " "
                      <span class="bp_summary_badge bp_summary_badge_error">"[missing declaration]"</span>
                    </div>
                    {{if let some href := codeHref then
                       {{<div class="bp_summary_item_actions">"Jump: " <a class="bp_code_link" href={{href}}>"code"</a></div>}}
                      else
                       .empty}}
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
        <style>{{.text false summaryCss}}</style>
        <script>{{.text false openTargetDetailsJs}}</script>
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
              <div class="bp_summary_card"><span class="bp_summary_label">"Entries with missing informal statement/proof"</span><span class="bp_summary_value">s!"{data.pendingInformalEntries.length}"</span></div>
              <div class="bp_summary_card bp_summary_card_warn"><span class="bp_summary_label">"Missing external Lean declarations"</span><span class="bp_summary_value">s!"{data.missingLeanDecls.length}"</span></div>
              <div class="bp_summary_card bp_summary_card_warn"><span class="bp_summary_label">"Incomplete Lean declarations"</span><span class="bp_summary_value">s!"{data.sorries}"</span></div>
            </div>
            <details class="bp_summary_subsection">
              <summary>s!"Lean code with missing informal statement/proof ({data.pendingInformalEntries.length})"</summary>
              <ul class="bp_summary_list">
                {{if pendingInformalRows.isEmpty then {{<li class="bp_summary_empty">"No entries missing informal statement/proof."</li>}} else pendingInformalRows}}
              </ul>
            </details>
            <details class="bp_summary_subsection bp_summary_subsection_warn">
              <summary>s!"Missing external Lean declarations ({data.missingLeanDecls.length})"</summary>
              <ul class="bp_summary_list">
                {{if missingRows.isEmpty then {{<li class="bp_summary_empty">"No missing external Lean declarations."</li>}} else missingRows}}
              </ul>
            </details>
            <details class="bp_summary_subsection bp_summary_subsection_warn">
              <summary>s!"Incomplete details ({data.sorryDetails.length})"</summary>
              <ul class="bp_summary_list">
                {{if sorryRows.isEmpty then {{<li class="bp_summary_empty">"No incomplete declarations detected."</li>}} else sorryRows}}
              </ul>
            </details>
          </details>
        </div>
      }}
  extraCss := ([] : List String)
  extraJs := ([] : List String)

open Verso Doc Elab Syntax in
def mkSummaryPart (stx : Syntax) (endPos : String.Pos.Raw) : PartElabM FinishedPart := do
  let titlePreview := "Blueprint Summary"
  let titleInlines ← `(inline | "Blueprint Summary")
  let expandedTitle ← #[titleInlines].mapM (elabInline ·)
  let metadata := none
  let summary ← buildSummary
  logInfo m!"Blueprint summary for {summary.totalEntries} entries"
  let block ← ``(Verso.Doc.Block.other (Informal.Commands.Block.summary $(quote summary)) #[])
  let subParts := #[]
  pure <| FinishedPart.mk stx expandedTitle titlePreview metadata #[block] subParts endPos

open Verso Doc Elab Syntax PartElabM in
@[part_command Lean.Doc.Syntax.command]
public meta def bpSummaryCmd : PartCommand
  | stx@`(block|command{bp_summary}) => do
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkSummaryPart stx endPos)
  | stx@`(block|command{blueprint_summary}) => do
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkSummaryPart stx endPos)
  | _ => (Lean.Elab.throwUnsupportedSyntax : PartElabM Unit)

end Informal.Commands
