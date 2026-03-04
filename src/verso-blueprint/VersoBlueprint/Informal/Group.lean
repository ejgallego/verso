/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import VersoManual

import VersoBlueprint.Data
import VersoBlueprint.Environment
import VersoBlueprint.Profiling

open Verso Doc Elab
open Verso.Genre Manual
open Verso.ArgParse
open Lean.Doc.Syntax
open Lean Elab

namespace Informal

structure GroupConfig where
  label : Data.Label
  labelSyntax : Syntax := Syntax.missing

section
variable [Monad m] [MonadError m]

def GroupConfig.parse : ArgParse m GroupConfig :=
  (fun (labelArg : Verso.ArgParse.WithSyntax String) =>
    {
      label := Name.mkSimple labelArg.val
      labelSyntax := labelArg.syntax
    }) <$> .positional `label (.withSyntax .string)

instance : FromArgs GroupConfig m where
  fromArgs := GroupConfig.parse

end

private def collapseWhitespace (s : String) : String :=
  let s := s.replace "\n" " "
  let s := s.replace "\r" " "
  let s := s.replace "\t" " "
  String.intercalate " " <| (s.splitOn " ").filter (fun chunk => !chunk.isEmpty)

private def blockChunkText (env : Environment) (block : TSyntax `block) : String :=
  match block with
  | `(block|para[$inlines*]) =>
    Verso.Doc.Elab.inlinesToString env inlines
  | `(block|header($_){$inlines*}) =>
    Verso.Doc.Elab.inlinesToString env inlines
  | _ =>
    (Syntax.reprint block.raw).getD ""

private def groupHeaderFromContents (contents : Array (TSyntax `block)) : DocElabM String := do
  let env ← getEnv
  let raw := contents.foldl (init := "") fun acc block =>
    let chunk := (blockChunkText env block).trimAscii.toString
    if chunk.isEmpty then
      acc
    else if acc.isEmpty then
      chunk
    else
      acc ++ "\n" ++ chunk
  pure (collapseWhitespace raw)

private def groupExpanderImpl : DirectiveExpanderOf GroupConfig
  | cfg, contents => do
    let header ← groupHeaderFromContents contents
    if header.isEmpty then
      logWarningAt cfg.labelSyntax m!"Group {cfg.label} has an empty body; using the group label as header text"
    Environment.registerGroup cfg.label (if header.isEmpty then cfg.label.toString else header)
    ``(Block.concat #[])

@[directive] def «group» : DirectiveExpanderOf GroupConfig
  | cfg, contents => do
    Profile.withDocElab "directive" "group" <|
      groupExpanderImpl cfg contents

end Informal
