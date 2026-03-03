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

abbrev ManualBlock := Verso.Doc.Block Verso.Genre.Manual

inductive Payload where
  | manualBlocks (blocks : Array ManualBlock)
  | elaborated (stxs : Array Syntax)
deriving Inhabited

def Payload.manualBlocks? : Payload → Option (Array ManualBlock)
  | .manualBlocks blocks => some blocks
  | .elaborated _ => none

def Payload.elaborated? : Payload → Option (Array Syntax)
  | .manualBlocks _ => none
  | .elaborated stxs => some stxs

private def nonEmptyOrNone {α} (xs : Array α) : Option (Array α) :=
  if xs.isEmpty then none else some xs

def fromTraversalForFacet?
    (s : Verso.Genre.Manual.TraverseState) (label : Name)
    (facet : PreviewCache.Facet) : Option Payload := do
  let blocks ← Informal.PreviewLookup.previewBlocksForFacet? s label facet
  return .manualBlocks (← nonEmptyOrNone blocks)

def fromTraversal?
    (s : Verso.Genre.Manual.TraverseState) (label : Name) : Option Payload :=
  match fromTraversalForFacet? s label .statement with
  | some payload => some payload
  | none => fromTraversalForFacet? s label .proof

def traversalBlocks?
    (s : Verso.Genre.Manual.TraverseState) (label : Name) : Option (Array ManualBlock) :=
  (fromTraversal? s label).bind Payload.manualBlocks?

private def envFacetStxs? (node : Data.Node) (facet : PreviewCache.Facet) : Option (Array Syntax) :=
  match facet with
  | .statement => node.statement.bind (nonEmptyOrNone ·.elabStx)
  | .proof => node.proof.bind (nonEmptyOrNone ·.elabStx)

def fromEnvironmentForFacet?
    (env : Environment) (label : Name) (facet : PreviewCache.Facet) : Option Payload := do
  let state := informalExt.getState env
  let node ← state.data.get? label
  let stxs ← envFacetStxs? node facet
  return .elaborated stxs

def fromEnvironment? (env : Environment) (label : Name) : Option Payload :=
  match fromEnvironmentForFacet? env label .statement with
  | some payload => some payload
  | none => fromEnvironmentForFacet? env label .proof

def fromEnvironmentM? [Monad m] [MonadEnv m] (label : Name) : m (Option Payload) := do
  pure <| fromEnvironment? (← getEnv) label

def renderWidgetHtml (payload? : Option Payload) : Lean.Elab.Term.TermElabM Verso.Output.Html := do
  match payload? with
  | none => pure .empty
  | some (.manualBlocks blocks) => Informal.renderPreviewBlocksHtml blocks
  | some (.elaborated stxs) => Informal.renderStatementElabHtml stxs

end Informal.PreviewSource
