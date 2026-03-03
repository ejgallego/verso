/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Commands
import VersoBlueprint.Commands.RenderBibliography

namespace Informal.Commands

open Lean Elab Command

open Verso Doc Elab Syntax in
def mkBibliographyPart (stx : Syntax) (endPos : String.Pos.Raw) : PartElabM FinishedPart := do
  let titlePreview := "Blueprint Bibliography"
  let titleInlines ← `(inline | "Blueprint Bibliography")
  let expandedTitle ← #[titleInlines].mapM (elabInline ·)
  let metadata := none
  let entries := Informal.Cite.allBibEntries (← getEnv)
  logInfo m!"Blueprint bibliography for {entries.length} entries"
  let refs : Array (TSyntax `term) ← entries.toArray.mapM fun (label, decl) =>
    `(BibliographyEntry.mk $(quote label) $(mkIdent decl))
  let block ← ``(Verso.Doc.Block.other
    (Informal.Commands.Block.bibliography
      (BibliographyData.mk (entries := ([$refs,*] : List BibliographyEntry)))) #[])
  let subParts := #[]
  pure $ FinishedPart.mk stx expandedTitle titlePreview metadata #[block] subParts endPos

open Verso Doc Elab Syntax PartElabM in
@[part_command Lean.Doc.Syntax.command]
public meta def bpBibliographyCmd : PartCommand
  | stx@`(block|command{bp_bibliography}) => do
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkBibliographyPart stx endPos)
  | stx@`(block|command{blueprint_bibliography}) => do
    let endPos := stx.getTailPos?.get!
    closePartsUntil 1 endPos
    addPart (← mkBibliographyPart stx endPos)
  | _ => (Lean.Elab.throwUnsupportedSyntax : PartElabM Unit)

end Informal.Commands
