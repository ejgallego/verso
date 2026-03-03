/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Verso
import VersoManual
import VersoBlueprint.Data
import VersoBlueprint.Environment
import VersoBlueprint.Lib.PreviewLookup
import VersoBlueprint.PreviewCache
import VersoBlueprint.PreviewRender

namespace Informal.PreviewSource

open Lean
open Informal Data Environment

abbrev ManualBlock := Informal.PreviewLookup.ManualBlock

private def nonEmptyOrNone {α} (xs : Array α) : Option (Array α) :=
  if xs.isEmpty then none else some xs

private def firstNonEmptyFacet? {α}
    (fetch : PreviewCache.Facet → Option (Array α)) : Option (Array α) :=
  match (fetch .statement).bind nonEmptyOrNone with
  | some xs => some xs
  | none => (fetch .proof).bind nonEmptyOrNone

def traversalBlocks?
    (s : Verso.Genre.Manual.TraverseState) (label : Name) : Option (Array ManualBlock) :=
  firstNonEmptyFacet? fun facet => Informal.PreviewLookup.previewBlocksForFacet? s label facet

private def envFacetStxs? (node : Data.Node) (facet : PreviewCache.Facet) : Option (Array Syntax) :=
  match facet with
  | .statement => node.statement.bind (nonEmptyOrNone ·.elabStx)
  | .proof => node.proof.bind (nonEmptyOrNone ·.elabStx)

def fromEnvironment? (env : Environment) (label : Name) : Option (Array Syntax) := do
  let state := informalExt.getState env
  let node ← state.data.get? label
  firstNonEmptyFacet? (envFacetStxs? node)

def renderWidgetHtml (stxs? : Option (Array Syntax)) : Lean.Elab.Term.TermElabM Verso.Output.Html := do
  match stxs? with
  | none => pure .empty
  | some stxs => Informal.renderStatementElabHtml stxs

end Informal.PreviewSource
