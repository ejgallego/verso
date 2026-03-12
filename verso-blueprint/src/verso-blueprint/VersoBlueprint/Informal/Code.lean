/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import VersoManual
import VersoBlueprint.Environment
import VersoBlueprint.Informal.Block
import VersoBlueprint.Informal.CodeCommon
import VersoBlueprint.Informal.LeanCodePreview
import VersoBlueprint.Informal.CodeSummary
import VersoBlueprint.LabelNameParsing
import VersoBlueprint.Lean
import VersoBlueprint.Profiling
import VersoBlueprint.Resolve
import VersoBlueprint.Widget

open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse
open Lean Lean.Elab
open Lean.Doc.Syntax

namespace Informal
open CodeSummary

private partial def previewCodeBlocks
    (blocks : Array (Verso.Doc.Block Verso.Genre.Manual)) :
    Array (Verso.Doc.Block Verso.Genre.Manual) :=
  blocks.foldl (init := #[]) fun acc block =>
    acc ++
      match block with
      | .concat contents =>
        previewCodeBlocks contents
      | .other _ contents =>
        if contents.isEmpty then
          #[block]
        else
          previewCodeBlocks contents
      | _ =>
        #[block]

block_extension Block.informalCode (data : InlineCodeData) where
  data := toJson data
  traverse id data _contents := do
    let .ok cdata@{ label, definedDefs := _, definedTheorems := _, foldProofs := _ } := fromJson? (α := InlineCodeData) data
      | logError s!"Malformed data: {data}"
        pure none
    if let .some _d := (← get).getDomainObject? informalCodeDomain label.toString then
      pure none
    else
      let previewBlocks := previewCodeBlocks _contents
      let previewTargets :=
        (cdata.definedDefs.map (·.name)) ++ (cdata.definedTheorems.map (·.name))
      for target in previewTargets do
        let previewKey := LeanCodePreview.lookupKey target
        let previewData := toJson (LeanCodePreview.Entry.ofInlineBlocks target previewBlocks)
        let existingPreview? := (← get).getDomainObject? LeanCodePreview.domainName previewKey
        modify fun s => s.saveDomainObjectData LeanCodePreview.domainName previewKey previewData
        if existingPreview?.isNone then
          let path ← (·.path) <$> read
          let _ ← Verso.Genre.Manual.externalTag id path s!"--lean-code-preview-{previewKey}"
          modify fun s => s.saveDomainObject LeanCodePreview.domainName previewKey id
      let path ← (·.path) <$> read
      let _ ← Verso.Genre.Manual.externalTag id path s!"--informal-code-{label}"
      modify λ s => s.saveDomainObject informalCodeDomain label.toString id
      modify λ s => s.saveDomainObjectData informalCodeDomain label.toString (toJson cdata)
      pure none
  toTeX := none
  extraCss := Informal.Commands.withBlueprintCssAssets [blueprintCss, Verso.Genre.Manual.docstringStyle]
  extraJs := ([] : List String)
  toHtml :=
    open Verso.Doc.Html in
    open Verso.Output.Html in
    some <| fun _goI goB id data blocks => do
      let .ok { label, definedDefs, definedTheorems, foldProofs } := fromJson? (α := InlineCodeData) data
        | HtmlT.logError s!"Malformed data: {data}"
          pure .empty
      let s ← HtmlT.state
      let ctxt ← HtmlT.context
      let attrs := s.htmlId id
      let panelHeader :=
        match s.getDomainObject? informalDomain label.toString with
        | some obj =>
          match fromJson? (α := BlockData) obj.data with
          | .ok b =>
            let b := b.withResolvedNumbering s (numberedPartPrefix? ctxt)
            codePanelHeader b (b.displayNumber s)
          | .error _ => fallbackCodePanelHeader
        | none => fallbackCodePanelHeader
      let getDeclHref (decl : Name) : Option String :=
        Resolve.resolveInlineLeanDeclHref? s decl
      let panelSummary :=
        renderPanelIndicator label
          {
            source := some (.inline { label, definedDefs, definedTheorems, foldProofs })
          }
          getDeclHref
      let panelAttrs := attrs.push ("data-bp-proof-fold", if foldProofs then "on" else "off")
      let panelBody := .seq (← blocks.mapM goB)
      pure <| mkCodePanel panelHeader panelSummary.summaryTitle panelSummary.indicator panelBody panelAttrs

structure CodeConfig where
  label : Data.Label
  leanLabel : Name
  labelSyntax : Syntax := Syntax.missing

section
variable [Monad m] [MonadError m] [MonadOptions m]

def CodeConfig.parse : ArgParse m CodeConfig :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) opts =>
    let label := LabelNameParsing.parse labelArg.val
    let leanLabel := LabelNameParsing.parse labelArg.val (some opts)
    {
      label
      leanLabel
      labelSyntax := labelArg.syntax
    }) <$> .positional `label (.withSyntax .string)
      <*> .lift "current elaboration options" getOptions

instance : FromArgs CodeConfig m where
  fromArgs := CodeConfig.parse

end

/-- Interpreting Embedded Lean Code blocks -/
private def leanImpl : CodeBlockExpanderOf CodeConfig
  | cfg, contents => do
    let leanCfg : Lean.LeanBlockConfig := { Lean.defaultConfig with name := some cfg.leanLabel }
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
