/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean.Elab.Command
import Lean.Elab.InfoTree

import SubVerso.Highlighting

import Verso
import VersoBlueprint.Data

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

abbrev DefinedDecl := Data.DefinedDecl

structure ElabCommandResult where
  block : Term
  definedDefs : Array DefinedDecl := #[]
  definedTheorems : Array DefinedDecl := #[]

private structure DeclSorryRefs where
  allRefs : Array Syntax := #[]
  typeRefs : Array Syntax := #[]
  proofRefs : Array Syntax := #[]

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

private def commandLineSpan (fileMap : FileMap) (stx : Syntax) : Nat :=
  match stx.getRange? with
  | none => 1
  | some range =>
    let endPos :=
      if range.start < range.stop then
        String.Pos.Raw.prev fileMap.source range.stop
      else
        range.stop
    let startLine := (fileMap.utf8PosToLspPos range.start).line
    let endLine := (fileMap.utf8PosToLspPos endPos).line
    endLine - startLine + 1

private def getDefinedDecls (fileMap : FileMap) (before after : Environment) (sorryRefsByDecl : Lean.NameMap DeclSorryRefs)
    (declCmdInfo : Lean.NameMap (Nat × Syntax)) :
    Array DefinedDecl × Array DefinedDecl :=
  Id.run <| do
    let mut defs := #[]
    let mut theorems := #[]
    for (name, info) in after.constants do
      if (before.find? name).isSome then
        continue
      if name.isInternalOrNum || name.hasMacroScopes then
        continue
      let hasTypeSorry := info.type.hasSorry
      let hasProofSorry := info.value?.map (·.hasSorry) |>.getD false
      let hasSorry := hasTypeSorry || hasProofSorry
      let refs := (sorryRefsByDecl.find? name).getD {}
      let (commandIndex, commandStx) := (declCmdInfo.find? name).getD (0, .missing)
      let commandLines := commandLineSpan fileMap commandStx
      let (typeSorryRefs, proofSorryRefs) :=
        if hasSorry then
          match info with
          | .thmInfo _ => (refs.typeRefs, refs.proofRefs)
          | _ => (if hasTypeSorry then refs.allRefs else #[], if hasProofSorry then refs.allRefs else #[])
        else
          (#[], #[])
      match info with
      | .thmInfo _ =>
        theorems := theorems.push ({
          name
          commandStx
          commandIndex
          commandLines
          hasSorry
          hasTypeSorry
          hasProofSorry
          typeSorryRefs
          proofSorryRefs
        } : DefinedDecl)
      | _ =>
        defs := defs.push ({
          name
          commandStx
          commandIndex
          commandLines
          hasSorry
          hasTypeSorry
          hasProofSorry
          typeSorryRefs
          proofSorryRefs
        } : DefinedDecl)
    let cmp (a b : DefinedDecl) :=
      a.commandIndex < b.commandIndex ||
      (a.commandIndex == b.commandIndex && a.name.toString < b.name.toString)
    (defs.qsort cmp, theorems.qsort cmp)

private def getNewPublicDecls (before after : Environment) : Array Name :=
  Id.run <| do
    let mut out := #[]
    for (name, _) in after.constants do
      if (before.find? name).isSome then
        continue
      if name.isInternalOrNum || name.hasMacroScopes then
        continue
      out := out.push name
    out

private partial def collectSorryRefs (stx : Syntax) : Array Syntax :=
  let fromChildren := stx.getArgs.foldl (init := #[]) fun acc arg =>
    acc ++ collectSorryRefs arg
  match stx with
  | .atom _ val =>
    if val == "sorry" then
      fromChildren.push stx
    else
      fromChildren
  | _ => fromChildren

private def getSorryRefs (cmds : Array Syntax) : Array Syntax :=
  Id.run <| do
    let mut out : Array Syntax := #[]
    for cmd in cmds do
      for sorryRef in collectSorryRefs cmd do
        out := out.push sorryRef
    out

private def getAssignPos? (cmd : Syntax) : Option String.Pos.Raw :=
  match cmd.find? fun
    | .atom info ":=" =>
      match info with
      | .original .. => true
      | _ => false
    | _ => false
  with
  | some (.atom info ":=") =>
    match info with
    | .original _ pos _ _ => some pos
    | _ => none
  | _ => none

private def splitRefsByAssignPos (cmd : Syntax) (refs : Array Syntax) : Array Syntax × Array Syntax :=
  match getAssignPos? cmd with
  | none => (#[], refs)
  | some pivot =>
    refs.foldl (init := (#[], #[])) fun (ty, pr) ref =>
      match ref.getPos? with
      | some p =>
        if p < pivot then (ty.push ref, pr) else (ty, pr.push ref)
      | none => (ty, pr.push ref)

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
    let mut sorryRefsByDecl : Lean.NameMap DeclSorryRefs := {}
    let mut declCmdInfo : Lean.NameMap (Nat × Syntax) := {}
    let mut cmdIndex := 0

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

      let cmdEnvBefore := cmdState.env
      cmdState ← runCommand (Command.elabCommand cmd) cmd cctx cmdState
      let newDecls := getNewPublicDecls cmdEnvBefore cmdState.env
      for name in newDecls do
        declCmdInfo := declCmdInfo.insert name (cmdIndex, cmd)
      cmdIndex := cmdIndex + 1
      let cmdSorryRefs := getSorryRefs #[cmd]
      if !cmdSorryRefs.isEmpty then
        let (typeRefs, proofRefs) := splitRefsByAssignPos cmd cmdSorryRefs
        for name in newDecls do
          let prior := (sorryRefsByDecl.find? name).getD {}
          let refs : DeclSorryRefs := {
            allRefs := prior.allRefs ++ cmdSorryRefs
            typeRefs := prior.typeRefs ++ typeRefs
            proofRefs := prior.proofRefs ++ proofRefs
          }
          sorryRefsByDecl := sorryRefsByDecl.insert name refs
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
    let (definedDefs, definedTheorems) := getDefinedDecls cctx.fileMap envBefore cmdState.env sorryRefsByDecl declCmdInfo
    pure { block, definedDefs, definedTheorems }
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
