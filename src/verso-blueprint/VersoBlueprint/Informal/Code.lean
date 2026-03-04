/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import VersoManual
import VersoBlueprint.Environment
import VersoBlueprint.Informal.Block
import VersoBlueprint.Informal.CodeCommon
import VersoBlueprint.Informal.CodeSummary
import VersoBlueprint.Lean
import VersoBlueprint.Profiling
import VersoBlueprint.Resolve
import VersoBlueprint.Widget

open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse
open _root_.Lean _root_.Lean.Elab
open _root_.Lean.Doc.Syntax

namespace Informal
open CodeSummary

private def sortDeclsByCommand (decls : Array CodeDeclData) : Array CodeDeclData :=
  decls.qsort (fun a b =>
    a.commandIndex < b.commandIndex ||
    (a.commandIndex == b.commandIndex && a.name.toString < b.name.toString))

private def progressSegmentClass (missing hasSorry : Bool) : String :=
  if missing then
    "bp_code_progress_segment bp_code_progress_segment_missing"
  else if hasSorry then
    "bp_code_progress_segment bp_code_progress_segment_sorry"
  else
    "bp_code_progress_segment bp_code_progress_segment_ok"

private def codeSummaryText (label : Data.Label) (definedDefs definedTheorems : Array CodeDeclData) : String :=
  if definedDefs.isEmpty && definedTheorems.isEmpty then
    s!"{label}"
  else
    let definedDefNames := definedDefs.map (·.name)
    let definedTheoremNames := definedTheorems.map (·.name)
    let defs :=
      if definedDefNames.isEmpty then
        "none"
      else
        String.intercalate ", " (definedDefNames.toList.map toString)
    let thms :=
      if definedTheoremNames.isEmpty then
        "none"
      else
        String.intercalate ", " (definedTheoremNames.toList.map toString)
    let sorryDecls := (definedDefs ++ definedTheorems).filter (provedStatusHasSorry ∘ (·.provedStatus))
    let sorries :=
      if sorryDecls.isEmpty then
        "none"
      else
        String.intercalate ", " <| sorryDecls.toList.map fun d =>
          s!"{d.name} [{provedStatusSummaryText d.provedStatus}]"
    s!"{label}\nLean definitions: {defs}\nLean theorems/lemmas: {thms}\nSorries: {sorries}"

block_extension Block.informalCode (data : InlineCodeData) where
  data := toJson data
  traverse id data _contents := do
    let .ok cdata@{ label, definedDefs := _, definedTheorems := _, foldProofs := _ } := fromJson? (α := InlineCodeData) data
      | logError s!"Malformed data: {data}"
        pure none
    if let .some _d := (← get).getDomainObject? informalCodeDomain label.toString then
      pure none
    else
      let path ← (·.path) <$> read
      let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-code-{label}"
      modify λ s => s.saveDomainObject informalCodeDomain label.toString id
      modify λ s => s.saveDomainObjectData informalCodeDomain label.toString (toJson cdata)
      pure none
  toTeX := none
  extraCss := ([blueprintCss, blueprintStyleSwitcherCss, Verso.Genre.Manual.docstringStyle] : List String)
  extraJs := ([blueprintStyleSwitcherJs] : List String)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB id data blocks => do
      let .ok { label, definedDefs, definedTheorems, foldProofs } := fromJson? (α := InlineCodeData) data
        | HtmlT.logError s!"Malformed data: {data}"
          pure .empty
      let s ← HtmlT.state
      let attrs := s.htmlId id
      let panelHeader :=
        match s.getDomainObject? informalDomain label.toString with
        | some obj =>
          match fromJson? (α := BlockData) obj.data with
          | .ok b => codePanelHeader b
          | .error _ => fallbackCodePanelHeader
        | none => fallbackCodePanelHeader
      let orderedDecls := sortDeclsByCommand (definedDefs ++ definedTheorems)
      let getDeclHref (decl : Name) : Option String :=
        Resolve.resolveInlineLeanDeclHref? s decl
      let progressSummaryTooltip : Output.Html :=
        renderCodeSummaryTooltip label definedDefs definedTheorems getDeclHref
      let progressBar : Output.Html :=
        if orderedDecls.isEmpty then
          .empty
        else
          let segments := orderedDecls.map fun decl =>
            let hasSorry := provedStatusHasSorry decl.provedStatus
            let cls := progressSegmentClass false hasSorry
            let weight := max decl.weight 1
            let title :=
              if hasSorry then
                if provedStatusContainsSorry decl.provedStatus then
                  s!"{decl.name}: contains sorry {provedStatusLocationText decl.provedStatus}"
                else
                  s!"{decl.name}: {provedStatusLocationText decl.provedStatus}"
              else
                s!"{decl.name}: complete"
            {{<span class={{cls}} title={{title}} style={{s!"flex: {weight} 1 0%"}}></span>}}
          let bar := {{<span class="bp_code_progress" aria-label="Lean declaration progress">{{segments}}</span>}}
          {{<span class="bp_code_hover_wrap bp_code_summary_indicator">{{bar}}{{progressSummaryTooltip}}</span>}}
      let summaryTitle := codeSummaryText label definedDefs definedTheorems
      let panelAttrs := attrs.push ("data-bp-proof-fold", if foldProofs then "on" else "off")
      let panelBody := .seq (← blocks.mapM goB)
      pure <| mkCodePanel panelHeader summaryTitle progressBar panelBody panelAttrs

structure CodeConfig where
  label : Data.Label
  labelSyntax : Syntax := Syntax.missing

section
variable [Monad m] [MonadError m]

def CodeConfig.parse : ArgParse m CodeConfig :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) =>
    {
      label := Name.mkSimple labelArg.val
      labelSyntax := labelArg.syntax
    }) <$> .positional `label (.withSyntax .string)

instance : FromArgs CodeConfig m where
  fromArgs := CodeConfig.parse

end

/-- Interpreting Embedded Lean Code blocks -/
private def leanImpl : CodeBlockExpanderOf CodeConfig
  | cfg, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with name := some (cfg.label : Lean.Name) }
    let res ← Lean.elabCommands leanCfg contents
    let codeBlock := res.block
    let definedDefs := res.definedDefs.map CodeDeclData.ofLiterateDef
    let definedTheorems := res.definedTheorems.map CodeDeclData.ofLiterateThm
    let data : InlineCodeData := {
      label := cfg.label
      definedDefs
      definedTheorems
      foldProofs := verso.blueprint.foldProofs.get (← getOptions)
    }
    let codeRef ← getRef
    Environment.registerCode cfg.label codeRef res.definedDefs res.definedTheorems
    activateForLabelDoc cfg.label codeRef
    ``(Block.other (Block.informalCode $(quote data)) #[$codeBlock])

@[code_block]
def lean : CodeBlockExpanderOf CodeConfig
  | cfg, contents => do
    Profile.withDocElab "code_block" "lean" <| leanImpl cfg contents

/-- Internal Lean setup blocks: executed but not rendered and not tracked as blueprint code blocks. -/
private def internalImpl : CodeBlockExpanderOf Unit
  | _, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with «show» := false, name := none }
    let _ ← Lean.elabCommands leanCfg contents
    ``(Block.concat #[])

@[code_block]
def internal : CodeBlockExpanderOf Unit
  | cfg, contents => do
    Profile.withDocElab "code_block" "internal" <| internalImpl cfg contents

private def rocqImpl : CodeBlockExpanderOf Unit
  | _cfg, contents => do
    ``(Block.code $contents)

@[code_block]
def rocq : CodeBlockExpanderOf Unit
  | cfg, contents => do
    Profile.withDocElab "code_block" "rocq" <| rocqImpl cfg contents

end Informal
