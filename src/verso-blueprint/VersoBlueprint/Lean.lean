/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean.Elab.Command
import Lean.Elab.InfoTree

import SubVerso.Highlighting

import Verso

import VersoManual.Basic
import VersoManual.HighlightedCode
import VersoManual.InlineLean.Block
import VersoManual.InlineLean.LongLines
import VersoManual.InlineLean.Outputs
import VersoManual.InlineLean.Scopes

open Verso Doc Elab Genre.Manual
open Lean Elab
open SubVerso.Highlighting

open Verso.SyntaxUtils (parserInputString)
open _root_.Verso.Genre.Manual (warnLongLines)
open _root_.Verso.Genre.Manual.InlineLean (saveOutputs)
open Verso.Genre.Manual.InlineLean.Scopes (getScopes setScopes)

namespace Informal.Lean

structure LeanBlockConfig where
  «show» : Bool
  name : Option Lean.Name

structure ElabCommandResult where
  block : Term
  definedConsts : Array Name := #[]
  definedProofs : Array Name := #[]

def LeanBlockConfig.outlineMeta (cfg : LeanBlockConfig) : String :=
  if cfg.show then " " else " (hidden)"

private def abbrevFirstLine (width : Nat) (str : String) : String :=
  let str := str.trimAsciiStart
  let short := str.take width |>.replace "\n" "⏎"
  if short.toSlice == str then short else short ++ "…"

private def firstToken? (stx : Syntax) : Option Syntax :=
  stx.find? fun
    | .ident info .. => usable info
    | .atom info .. => usable info
    | _ => false
where
  usable
    | .original .. => true
    | _ => false

private def reportMessages {m} [Monad m] [MonadLog m]
    (messages : MessageLog) : m Unit := do
  for msg in messages.toArray do
    logMessage {msg with
      isSilent := msg.isSilent || msg.severity != .error
    }

def reconstructHighlight (docReconst : DocReconstruction) (key : Export.Key) :=
  match docReconst.highlightDeduplication.toHighlighted key with
  | .error msg => panic! s!"Unable to export key {key}: {msg}"
  | .ok v => v

private def quoteHighlightViaSerialization (hls : Highlighted) : DocElabM Term := do
  match ((← readThe DocElabContext).docReconstructionPlaceholder, (← getThe DocElabM.State).highlightDeduplicationTable) with
  | (.some placeholder, .some exportTable) =>
    let (key, exportTable) := hls.export.run exportTable
    modifyThe DocElabM.State ({ · with highlightDeduplicationTable := exportTable })
    ``(reconstructHighlight $placeholder $(quote key))
  | _ =>
    let repr := hlToExport hls
    ``(hlFromExport! $(quote repr))

private def toHighlightedLeanBlock (shouldShow : Bool) (hls : Highlighted) (str: StrLit) : DocElabM Term := do
  if !shouldShow then
    return ← ``(Block.concat #[])

  let col? := (← getRef).getPos? |>.map (← getFileMap).utf8PosToLspPos |>.map (·.character)
  let hls := match col? with
  | .none => hls
  | .some col => hls.deIndent col

  let range := Syntax.getRange? str
  let range := range.map (← getFileMap).utf8RangeToLspRange
  ``(Block.other
      (Verso.Genre.Manual.InlineLean.Block.lean $(← quoteHighlightViaSerialization hls) (some $(quote (← getFileName))) $(quote range))
      #[Block.code $(quote str.getString)])

private def getDefinedDecls (before after : Environment) : Array Name × Array Name :=
  Id.run <| do
    let mut consts := #[]
    let mut proofs := #[]
    for (name, info) in after.constants do
      if (before.find? name).isSome then
        continue
      if name.isInternalOrNum || name.hasMacroScopes then
        continue
      consts := consts.push name
      match info with
      | .thmInfo _ => proofs := proofs.push name
      | _ => pure ()
    (consts.qsort (fun a b => a.toString < b.toString), proofs.qsort (fun a b => a.toString < b.toString))

def elabCommands (config : LeanBlockConfig) (str : StrLit) : DocElabM ElabCommandResult :=
  withoutAsync <| do
    PointOfInterest.save (← getRef) ((config.name.map (·.toString)).getD (abbrevFirstLine 20 str.getString))
      (kind := Lsp.SymbolKind.file)
      (detail? := some ("Lean code" ++ config.outlineMeta))

    let envBefore ← getEnv
    let col? := (← getRef).getPos? |>.map (← getFileMap).utf8PosToLspPos |>.map (·.character)
    let origScopes := (← getScopes).modifyHead fun sc =>
      { sc with opts := pp.tagAppFns.set (Elab.async.set sc.opts false) true }

    let altStr ← parserInputString str
    let ictx := Parser.mkInputContext altStr (← getFileName)
    let cctx : Command.Context := {
      fileName := ← getFileName
      fileMap := FileMap.ofString altStr
      snap? := none
      cancelTk? := none
    }

    let mut cmdState : Command.State := {
      env := envBefore
      maxRecDepth := ← MonadRecDepth.getMaxRecDepth
      scopes := origScopes
    }
    let mut pstate := {pos := 0, recovering := false}
    let mut cmds := #[]

    repeat
      let scope := cmdState.scopes.head!
      let pmctx := {
        env := cmdState.env
        options := scope.opts
        currNamespace := scope.currNamespace
        openDecls := scope.openDecls
      }
      let (cmd, ps', messages) := Parser.parseCommand ictx pmctx pstate cmdState.messages
      cmds := cmds.push cmd
      pstate := ps'
      cmdState := { cmdState with messages := messages }

      cmdState ← runCommand (Command.elabCommand cmd) cmd cctx cmdState
      if Parser.isTerminalCommand cmd then break

    setEnv cmdState.env
    setScopes cmdState.scopes
    for t in cmdState.infoState.trees do
      pushInfoTree t

    let mut hls := Highlighted.empty
    let nonSilentMsgs := cmdState.messages.toArray.filter (!·.isSilent)
    let mut lastPos : String.Pos.Raw := cmds[0]? >>= (·.getRange?.map (·.start)) |>.getD 0
    for cmd in cmds do
      hls := hls ++ (← highlightIncludingUnparsed cmd nonSilentMsgs cmdState.infoState.trees (startPos? := lastPos))
      lastPos := (cmd.getTrailingTailPos?).getD lastPos

    if let some name := config.name then
      let nonSilentMsgs := cmdState.messages.toList.filter (!·.isSilent)
      let msgs ← nonSilentMsgs.mapM fun (msg : Message) => do
        let head := if msg.caption != "" then msg.caption ++ ":\n" else ""
        let msg ← highlightMessage msg
        pure { msg with contents := .append #[.text head, msg.contents] }
      saveOutputs name msgs

    reportMessages cmdState.messages
    if config.show then
      warnLongLines col? str

    let block ← toHighlightedLeanBlock config.show hls str
    let (definedConsts, definedProofs) := getDefinedDecls envBefore cmdState.env
    pure { block, definedConsts, definedProofs }
where
  runCommand (act : Command.CommandElabM Unit) (stx : Syntax)
      (cctx : Command.Context) (cmdState : Command.State) :
      DocElabM Command.State := do
    let (output, cmdState) ←
      match (← liftM <| IO.FS.withIsolatedStreams <| EIO.toIO' <| (act.run cctx).run cmdState) with
      | (output, .error e) => Lean.logError e.toMessageData; pure (output, cmdState)
      | (output, .ok ((), cmdState)) => pure (output, cmdState)

    if output.trimAscii.isEmpty then return cmdState

    let log : MessageData → Command.CommandElabM Unit :=
      if let some tok := firstToken? stx then logInfoAt tok else logInfo

    match (← liftM <| EIO.toIO' <| ((log output).run cctx).run cmdState) with
    | .error _ => pure cmdState
    | .ok ((), cmdState) => pure cmdState

def lean : CodeBlockExpanderOf LeanBlockConfig
  | config, str => return (← elabCommands config str).block

def defaultConfig : LeanBlockConfig where
  «show» := true
  name := none

end Informal.Lean
