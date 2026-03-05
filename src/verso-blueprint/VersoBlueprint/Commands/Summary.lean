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
import VersoBlueprint.Graph
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

structure EntryStatusCounts where
  completed : Nat := 0
  completedDepsNo : Nat := 0
  withSorries : Nat := 0
  noProof : Nat := 0
deriving Inhabited, FromJson, ToJson

open Syntax in
instance : Quote EntryStatusCounts where
  quote s := mkCApp ``EntryStatusCounts.mk
    #[
      quote s.completed,
      quote s.completedDepsNo,
      quote s.withSorries,
      quote s.noProof
    ]

structure Summary where
  totalEntries : Nat := 0
  definitions : Nat := 0
  lemmas : Nat := 0
  theorems : Nat := 0
  corollaries : Nat := 0
  axioms : Nat := 0
  leanOnlyEntries : Nat := 0
  informalOnlyEntries : Nat := 0
  totalStatus : EntryStatusCounts := {}
  definitionStatus : EntryStatusCounts := {}
  lemmaStatus : EntryStatusCounts := {}
  theoremStatus : EntryStatusCounts := {}
  corollaryStatus : EntryStatusCounts := {}
  axiomStatus : EntryStatusCounts := {}
  pendingInformalEntries : List PendingInformalItem := []
  leanDecls : Nat := 0
  sorries : Nat := 0
  sorryDetails : List SorryItem := []
  missingLeanDecls : List MissingLeanDeclItem := []
  definitionIndex : List IndexItem := []
  theoremLikeIndex : List IndexItem := []
  axiomIndex : List IndexItem := []
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
      quote s.axioms,
      quote s.leanOnlyEntries,
      quote s.informalOnlyEntries,
      quote s.totalStatus,
      quote s.definitionStatus,
      quote s.lemmaStatus,
      quote s.theoremStatus,
      quote s.corollaryStatus,
      quote s.axiomStatus,
      quote s.pendingInformalEntries,
      quote s.leanDecls,
      quote s.sorries,
      quote s.sorryDetails,
      quote s.missingLeanDecls,
      quote s.definitionIndex,
      quote s.theoremLikeIndex,
      quote s.axiomIndex,
      quote s.theoremLikeByParent
    ]

structure EntryStatusFlags where
  completed : Bool := false
  completedDepsNo : Bool := false
  withSorries : Bool := false
  noProof : Bool := false
  hasAxiomLike : Bool := false
deriving Inhabited

private def bumpEntryStatus (acc : EntryStatusCounts) (flags : EntryStatusFlags) : EntryStatusCounts :=
  {
    completed := acc.completed + (if flags.completed then 1 else 0)
    completedDepsNo := acc.completedDepsNo + (if flags.completedDepsNo then 1 else 0)
    withSorries := acc.withSorries + (if flags.withSorries then 1 else 0)
    noProof := acc.noProof + (if flags.noProof then 1 else 0)
  }

private def codeRefHasAxiomLikeDecl : Data.CodeRef → Bool
  | .userOk => false
  | .external decls =>
    decls.any (fun decl => decl.provedStatus.isAxiomLike)
  | .literate code =>
    code.definedDefs.any (fun decl => decl.provedStatus.isAxiomLike) ||
    code.definedTheorems.any (fun decl => decl.provedStatus.isAxiomLike)

private def entryStatusFlags (state : Environment.State)
    (external : Informal.Graph.ExternalCodeStatus) (node : Data.Node) : EntryStatusFlags :=
  let hasCode := Informal.Graph.nodeHasAssociatedCode node
  let localFormalized := Informal.Graph.nodeLocalFormalized external node
  let ancestorsFormalized := Informal.Graph.nodeAncestorsFormalized external state node
  let withSorries := hasCode && Informal.Graph.nodeHasSorries external node
  let noProof := node.kind.isTheoremLike && !hasCode
  let hasAxiomLike :=
    match node.code with
    | some codeRef => codeRefHasAxiomLikeDecl codeRef
    | none => false
  {
    completed := localFormalized && ancestorsFormalized
    completedDepsNo := localFormalized && !ancestorsFormalized
    withSorries
    noProof
    hasAxiomLike
  }

private def statusCountsText (counts : EntryStatusCounts) : String :=
  s!"completed: {counts.completed}; deps incomplete: {counts.completedDepsNo}; sorries: {counts.withSorries}; no proof: {counts.noProof}"

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

def buildSummary : CoreM Summary := do
  let env ← getEnv
  let state := informalExt.getState env
  let entries := state.data.toArray
  let parentChildren := state.data.parentChildren
  let groupHeaders := state.groups
  let external : Informal.Graph.ExternalCodeStatus := {}
  let summary := entries.foldl (init := ({} : Summary)) fun acc (label, node) =>
      let hasStatement := node.statement.isSome
      let hasProof := node.proof.isSome
      let hasCode := node.code.isSome
      let statusFlags := entryStatusFlags state external node
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
                isTheorem :=
                  (decls.find? (fun d => d.canonical == decl)).map (·.kind.isTheoremLike) |>.getD false
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
      let axiomIndex : List IndexItem :=
        if statusFlags.hasAxiomLike then
          mkIndexItem label node.kind leanObjects :: acc.axiomIndex
        else
          acc.axiomIndex
      let acc := { acc with
        totalEntries := acc.totalEntries + 1
        leanOnlyEntries := acc.leanOnlyEntries + (if hasCode && !hasStatement then 1 else 0)
        informalOnlyEntries := acc.informalOnlyEntries + (if hasStatement && !hasCode then 1 else 0)
        totalStatus := bumpEntryStatus acc.totalStatus statusFlags
        pendingInformalEntries
        leanDecls := acc.leanDecls + leanDecls
        sorries := acc.sorries + sorries
        sorryDetails := sorryDetails ++ acc.sorryDetails
        missingLeanDecls := missingLeanDecls ++ acc.missingLeanDecls
        definitionIndex
        theoremLikeIndex
        axiomIndex
      }
      let acc :=
        match node.kind with
        | Data.NodeKind.definition =>
          { acc with
            definitions := acc.definitions + 1
            definitionStatus := bumpEntryStatus acc.definitionStatus statusFlags
          }
        | Data.NodeKind.lemma =>
          { acc with
            lemmas := acc.lemmas + 1
            lemmaStatus := bumpEntryStatus acc.lemmaStatus statusFlags
          }
        | Data.NodeKind.theorem =>
          { acc with
            theorems := acc.theorems + 1
            theoremStatus := bumpEntryStatus acc.theoremStatus statusFlags
          }
        | Data.NodeKind.corollary =>
          { acc with
            corollaries := acc.corollaries + 1
            corollaryStatus := bumpEntryStatus acc.corollaryStatus statusFlags
          }
      if statusFlags.hasAxiomLike then
        { acc with
          axioms := acc.axioms + 1
          axiomStatus := bumpEntryStatus acc.axiomStatus statusFlags
        }
      else
        acc
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

private def Summary.previewLabels (data : Summary) : Array Name :=
  let allLabels : List Name :=
    data.pendingInformalEntries.map (·.label) ++
    data.sorryDetails.map (·.label) ++
    data.missingLeanDecls.map (·.label) ++
    data.definitionIndex.map (·.label) ++
    data.theoremLikeIndex.map (·.label) ++
    data.theoremLikeByParent.foldr (init := []) fun group acc =>
      group.entries.map (·.label) ++ acc
  let (_, labels) := allLabels.foldl (init := (({} : NameSet), (#[] : Array Name))) fun (seen, labels) label =>
    if seen.contains label then
      (seen, labels)
    else
      (seen.insert label, labels.push label)
  labels

def summaryCss := include_str "summary.css"

def summaryPreviewJs : String := r##"(function () {
  function bindSummaryPreview(root) {
    if (!(root instanceof Element)) return;
    if (root.getAttribute("data-bp-summary-preview-bound") === "1") return;
    root.setAttribute("data-bp-summary-preview-bound", "1");

    const previewUtils = window.bpPreviewUtils;
    const previewMap =
      previewUtils && typeof previewUtils.collectPreviewTemplates === "function"
        ? previewUtils.collectPreviewTemplates(
            root,
            "template.bp_summary_preview_tpl[data-bp-preview-label]"
          )
        : new Map();
    const panel = root.querySelector(".bp_summary_preview_panel");
    const title = panel ? panel.querySelector(".bp_summary_preview_panel_title") : null;
    const body = panel ? panel.querySelector(".bp_summary_preview_panel_body") : null;
    const close = panel ? panel.querySelector(".bp_summary_preview_panel_close") : null;
    if (!panel || !title || !body || previewMap.size === 0) {
      if (panel) panel.hidden = true;
      return;
    }

    let activeWrap = null;

    function parsePreviewEntry(entry) {
      if (previewUtils && typeof previewUtils.readPreviewTemplate === "function") {
        return previewUtils.readPreviewTemplate(entry);
      }
      if (typeof entry === "string") {
        return { html: entry, texPrelude: "" };
      }
      if (!entry || typeof entry !== "object") {
        return { html: "", texPrelude: "" };
      }
      return {
        html: typeof entry.html === "string" ? entry.html : "",
        texPrelude: typeof entry.texPrelude === "string" ? entry.texPrelude : ""
      };
    }

    function hidePanel() {
      panel.hidden = true;
      title.textContent = "";
      body.innerHTML = "";
      activeWrap = null;
    }

    function positionPanel(anchor) {
      if (!(anchor instanceof Element)) return;
      const rect = anchor.getBoundingClientRect();
      const margin = 12;
      const panelRect = panel.getBoundingClientRect();
      const panelWidth = panelRect.width || Math.min(520, window.innerWidth - margin * 2);
      const panelHeight = panelRect.height || Math.min(420, window.innerHeight - margin * 2);
      let left = rect.left;
      if (left + panelWidth > window.innerWidth - margin) {
        left = window.innerWidth - panelWidth - margin;
      }
      left = Math.max(margin, left);
      let top = rect.bottom + 10;
      if (top + panelHeight > window.innerHeight - margin) {
        top = rect.top - panelHeight - 10;
      }
      top = Math.max(margin, top);
      panel.style.left = left + "px";
      panel.style.top = top + "px";
    }

    function showFromWrap(wrap) {
      if (!(wrap instanceof Element)) return;
      const label = wrap.getAttribute("data-bp-preview-label") || "";
      const entry = parsePreviewEntry(previewMap.get(label));
      const html = entry.html;
      const texPrelude = entry.texPrelude;
      if (!label || !html) {
        hidePanel();
        return;
      }
      activeWrap = wrap;
      title.textContent = label;
      body.innerHTML = html;
      if (previewUtils && typeof previewUtils.renderMath === "function") {
        previewUtils.renderMath(body, texPrelude);
      }
      panel.hidden = false;
      positionPanel(wrap);
    }

    if (previewUtils && typeof previewUtils.bindCloseOnce === "function") {
      previewUtils.bindCloseOnce(close, hidePanel);
    } else if (close && close.getAttribute("data-bp-bound") !== "1") {
      close.setAttribute("data-bp-bound", "1");
      close.addEventListener("click", function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        hidePanel();
      });
    }

    const wraps = root.querySelectorAll(".bp_summary_preview_wrap_active[data-bp-preview-label]");
    wraps.forEach(function (wrap) {
      if (!(wrap instanceof Element)) return;
      if (wrap.getAttribute("data-bp-bound") === "1") return;
      wrap.setAttribute("data-bp-bound", "1");
      wrap.addEventListener("mouseenter", function () {
        showFromWrap(wrap);
      });
      wrap.addEventListener("focusin", function () {
        showFromWrap(wrap);
      });
      wrap.addEventListener("mouseleave", function (ev) {
        const next = ev.relatedTarget;
        if (next instanceof Element && (wrap.contains(next) || panel.contains(next))) return;
        hidePanel();
      });
      wrap.addEventListener("focusout", function (ev) {
        const next = ev.relatedTarget;
        if (next instanceof Element && (wrap.contains(next) || panel.contains(next))) return;
        hidePanel();
      });
    });

    panel.addEventListener("mouseleave", function (ev) {
      const next = ev.relatedTarget;
      if (next instanceof Element && activeWrap && activeWrap.contains(next)) return;
      if (next instanceof Element && panel.contains(next)) return;
      hidePanel();
    });
    panel.addEventListener("focusout", function (ev) {
      const next = ev.relatedTarget;
      if (next instanceof Element && activeWrap && activeWrap.contains(next)) return;
      if (next instanceof Element && panel.contains(next)) return;
      hidePanel();
    });

    document.addEventListener("keydown", function (ev) {
      if (ev.key === "Escape") {
        hidePanel();
      }
    });
    window.addEventListener("resize", function () {
      if (activeWrap && !panel.hidden) positionPanel(activeWrap);
    });
    window.addEventListener("scroll", function () {
      if (activeWrap && !panel.hidden) positionPanel(activeWrap);
    }, true);
  }

  function init() {
    document.querySelectorAll(".bp_summary").forEach(bindSummaryPreview);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();"##

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
      let (previewLabels, previewTemplates) ← (data.previewLabels).foldlM
          (init := (({} : NameSet), (#[] : Array Output.Html))) fun (labels, templates) label => do
        let preview? ← Informal.PreviewSource.renderTraversalPreview? s goB label
        match preview? with
        | Option.none => pure (labels, templates)
        | some (rendered, texPrelude) =>
          pure (labels.insert label, templates.push (Informal.HoverRender.summaryPreviewTemplate label rendered texPrelude))
      let previewUi := Informal.HoverRender.summaryPreviewUi previewTemplates
      let mkEntryRef (label : Name) := do
        let previewLabel? : Option Name :=
          if previewLabels.contains label then some label else none
        let labelNode : Output.Html :=
          match getEntryHref label with
          | Option.some href => {{ <a href={{href}}> <code>s!"{label}"</code> </a> }}
          | Option.none => {{ <code>s!"{label}"</code> }}
        pure (Informal.HoverRender.summaryPreviewWrap labelNode previewLabel?)
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
                item.status.sorryLocationText, "n/a", 0, 0, 0)
            | .axiomLike =>
              pure ("axiom-like", "Axiom-like declaration: ", "bp_summary_badge bp_summary_badge_warn",
                item.status.sorryLocationText, "n/a", 0, 0, 0)
            | .containsSorry _ =>
              let (typeSorryRefs, proofSorryRefs) := item.status.sorryRefCounts
              let sorryRefs := typeSorryRefs + proofSorryRefs
              let refsTxt := if sorryRefs > 0 then toString sorryRefs else "unknown"
              pure ("contains sorry", "Declaration with sorry: ", "bp_summary_badge bp_summary_badge_warn",
                item.status.sorryLocationText, refsTxt, typeSorryRefs, proofSorryRefs, sorryRefs)
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
      let axiomRows ←
        data.axiomIndex.toArray.mapM fun item =>
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
          {{previewUi.store}}
          {{previewUi.panel}}
          <details class="bp_summary_section" open>
            <summary>s!"Blueprint DB entries ({data.totalEntries})"</summary>
            <div class="bp_summary_grid">
              <div class="bp_summary_card"><span class="bp_summary_label">"Total entries"</span><span class="bp_summary_value">s!"{data.totalEntries}"</span><span class="bp_summary_status">{{.text true (statusCountsText data.totalStatus)}}</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Definitions"</span><span class="bp_summary_value">s!"{data.definitions}"</span><span class="bp_summary_status">{{.text true (statusCountsText data.definitionStatus)}}</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Lemmas"</span><span class="bp_summary_value">s!"{data.lemmas}"</span><span class="bp_summary_status">{{.text true (statusCountsText data.lemmaStatus)}}</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Theorems"</span><span class="bp_summary_value">s!"{data.theorems}"</span><span class="bp_summary_status">{{.text true (statusCountsText data.theoremStatus)}}</span></div>
              <div class="bp_summary_card"><span class="bp_summary_label">"Corollaries"</span><span class="bp_summary_value">s!"{data.corollaries}"</span><span class="bp_summary_status">{{.text true (statusCountsText data.corollaryStatus)}}</span></div>
              <div class={{if data.axioms > 0 then "bp_summary_card bp_summary_card_warn" else "bp_summary_card"}}><span class="bp_summary_label">"Axiom-like entries"</span><span class="bp_summary_value">s!"{data.axioms}"</span><span class="bp_summary_status">{{.text true (statusCountsText data.axiomStatus)}}</span></div>
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
            <details class={{if data.axiomIndex.isEmpty then "bp_summary_subsection" else "bp_summary_subsection bp_summary_subsection_warn"}}>
              <summary>s!"Axiom-like Index ({data.axiomIndex.length})"</summary>
              <ul class="bp_summary_list">
                {{if axiomRows.isEmpty then {{<li class="bp_summary_empty">"No axiom-like entries registered."</li>}} else axiomRows}}
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
  extraCss := singleton ⟨summaryCss⟩
  extraJs := ([openTargetDetailsJs, previewHoverUtilsJs, summaryPreviewJs] : List String)

open Verso Doc Elab Syntax in
def mkSummaryPart (stx : Syntax) (endPos : String.Pos.Raw) : PartElabM FinishedPart := do
  let titlePreview := "Blueprint Summary"
  let titleInlines ← `(inline | "Blueprint Summary")
  let expandedTitle ← #[titleInlines].mapM (elabInline ·)
  let metadata : Option (TSyntax `term) := some (← `(term| { number := false }))
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
