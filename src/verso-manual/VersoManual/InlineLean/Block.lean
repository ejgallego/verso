/-
Copyright (c) 2024-2025 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: David Thrane Christiansen
-/

import Lean.Data.Json.Basic
import VersoManual.Basic
import VersoManual.HighlightedCode
import Verso.Code.Highlighted.WebAssets
import Verso.Code.HighlightedToTex

import SubVerso.Highlighting

open Verso Genre Manual
open Verso Code Highlighted WebAssets
open Verso Doc Output Html
open Lean
open SubVerso.Highlighting

namespace Verso.Genre.Manual.InlineLean

public structure ExplanationPlaceholder where
  marker : String
  lineCount : Nat
deriving ToJson, FromJson, Repr, Quote, Inhabited

public structure MultiLeanData where
  code : Highlighted
  placeholders : Array ExplanationPlaceholder
  file : Option System.FilePath := none
  range : Option Lsp.Range := none
deriving ToJson, FromJson, Repr, Quote

public def splitMultileanCode (hls : Highlighted) (placeholders : Array ExplanationPlaceholder) :
    Array (Highlighted ⊕ Nat) := Id.run do
  let lines := hls.lines
  let mut out := #[]
  let mut current := Highlighted.empty
  let mut lineIdx := 0
  while h : lineIdx < lines.size do
    let line := lines[lineIdx]
    let marker? := placeholders.findIdx? fun ph => line.toString.trimAscii == ph.marker
    match marker? with
    | some idx =>
      if !current.isEmpty then
        out := out.push (.inl current)
        current := .empty
      out := out.push (.inr idx)
      lineIdx := lineIdx + placeholders[idx]!.lineCount
    | none =>
      current := current ++ line
      lineIdx := lineIdx + 1
  if !current.isEmpty then
    out := out.push (.inl current)
  out

block_extension Block.lean
    (hls : Highlighted) (file : Option System.FilePath := none) (range : Option Lsp.Range := none)
    via withHighlighting where
  init s := s.addQuickJumpMapper exampleDomain exampleDomainMapper
  data :=
    let defined := definedNames hls
    Json.arr #[ToJson.toJson hls, ToJson.toJson defined, ToJson.toJson file, ToJson.toJson range]

  traverse id data _ := do
    let .arr #[_, defined, _, _] := data
      | logError "Expected two-element JSON for Lean code" *> pure none
    match FromJson.fromJson? defined with
    | .error err =>
      logError <| "Couldn't deserialize Lean code while traversing block example: " ++ err
      pure none
    | .ok (defs : Array (Name × String)) =>
      saveExampleDefs id defs
      pure none
  toTeX :=
    some <| fun _ _ _ data _ => do
      let .arr #[hlJson, _ds, _, _] := data
        | TeX.logError "Expected four-element JSON for Lean code" *> pure .empty
      match FromJson.fromJson? hlJson with
      | .error err =>
        TeX.logError <| "Couldn't deserialize Lean code block while rendering TeX: " ++ err
        pure .empty
      | .ok (hl : Highlighted) =>
        hl.toTeX (g := Manual) (m := ReaderT ExtensionImpls IO)
  toHtml :=
    open Verso.Output.Html in
    some <| fun _ _ _ data _ => do
      let .arr #[hlJson, _ds, _, _] := data
        | HtmlT.logError "Expected four-element JSON for Lean code" *> pure .empty
      match FromJson.fromJson? hlJson with
      | .error err =>
        HtmlT.logError <| "Couldn't deserialize Lean code block while rendering HTML: " ++ err
        pure .empty
      | .ok (hl : Highlighted) =>

        hl.blockHtml (g := Manual) "examples"

block_extension Block.multilean
    (hls : Highlighted) (placeholders : Array ExplanationPlaceholder)
    (file : Option System.FilePath := none) (range : Option Lsp.Range := none)
    via withHighlighting where
  init s := s.addQuickJumpMapper exampleDomain exampleDomainMapper
  data := ToJson.toJson <| MultiLeanData.mk hls placeholders file range

  traverse id data _ := do
    match FromJson.fromJson? data with
    | .error err =>
      logError <| "Couldn't deserialize multilean block while traversing example: " ++ err
      pure none
    | .ok (info : MultiLeanData) =>
      let defs := definedNames info.code
      saveExampleDefs id defs
      pure none
  toTeX :=
    some <| fun _ go _ data content => do
      match FromJson.fromJson? data with
      | .error err =>
        TeX.logError <| "Couldn't deserialize multilean block while rendering TeX: " ++ err
        pure .empty
      | .ok (info : MultiLeanData) =>
        let pieces := splitMultileanCode info.code info.placeholders
        let renderedBlocks ← content.mapM go
        let mut out := TeX.empty
        for piece in pieces do
          match piece with
          | .inl code =>
            let code := code.trimOneLeadingNl.trimOneTrailingNl
            if !code.isEmpty then
              out := out ++ (← code.toTeX (g := Manual) (m := ReaderT ExtensionImpls IO))
          | .inr idx =>
            if h : idx < renderedBlocks.size then
              out := out ++ renderedBlocks[idx]
            else
              TeX.logError s!"Missing multilean explanation block {idx}"
        pure out
  toHtml :=
    open Verso.Output.Html in
    some <| fun _ go _ data content => do
      match FromJson.fromJson? data with
      | .error err =>
        HtmlT.logError <| "Couldn't deserialize multilean block while rendering HTML: " ++ err
        pure .empty
      | .ok (info : MultiLeanData) =>
        let pieces := splitMultileanCode info.code info.placeholders
        let renderedBlocks ← content.mapM go
        let mut out : Array Html := #[]
        for piece in pieces do
          match piece with
          | .inl code =>
            let code := code.trimOneLeadingNl.trimOneTrailingNl
            if !code.isEmpty then
              let rendered ← code.blockHtml (g := Manual) "examples" (trim := false)
              out := out.push {{<div class="multilean-segment multilean-code">{{rendered}}</div>}}
          | .inr idx =>
            if h : idx < renderedBlocks.size then
              out := out.push {{
                <div class="multilean-segment multilean-explanation">
                  <div class="multilean-explanation-inner">{{renderedBlocks[idx]}}</div>
                </div>
              }}
            else
              HtmlT.logError s!"Missing multilean explanation block {idx}"
        pure {{<div class="multilean">{{out}}</div>}}
