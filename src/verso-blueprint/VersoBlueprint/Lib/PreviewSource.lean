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
import VersoBlueprint.PreviewCache
import VersoBlueprint.PreviewRender
import VersoBlueprint.Resolve

namespace Informal.PreviewSource

open Lean
open Informal Data Environment

abbrev ManualBlock := Verso.Doc.Block Verso.Genre.Manual

structure TraversalPreview where
  blocks : Array ManualBlock := #[]
deriving Inhabited, Repr

private def nonEmptyOrNone {α} (xs : Array α) : Option (Array α) :=
  if xs.isEmpty then none else some xs

private def firstNonEmptyFacet? {α}
    (fetch : PreviewCache.Facet → Option (Array α)) : Option (Array α) :=
  match (fetch .statement).bind nonEmptyOrNone with
  | some xs => some xs
  | none => (fetch .proof).bind nonEmptyOrNone

private def firstNonEmptyEntry?
    (fetch : PreviewCache.Facet → Option PreviewCache.Entry) : Option PreviewCache.Entry :=
  match fetch .statement with
  | some entry =>
    if entry.blocks.isEmpty then
      match fetch .proof with
      | some proofEntry =>
        if proofEntry.blocks.isEmpty then none else some proofEntry
      | none => none
    else
      some entry
  | none =>
    match fetch .proof with
    | some entry =>
      if entry.blocks.isEmpty then none else some entry
    | none => none

def traversalPreview?
    (s : Verso.Genre.Manual.TraverseState) (label : Name) : Option TraversalPreview := do
  let traversalFacetEntry? (facet : PreviewCache.Facet) : Option PreviewCache.Entry := do
    let key := PreviewCache.key label facet
    let obj ← s.getDomainObject? Resolve.informalPreviewDomainName key
    (fromJson? (α := PreviewCache.Entry) obj.data).toOption
  let entry ← firstNonEmptyEntry? traversalFacetEntry?
  return { blocks := entry.blocks }

def traversalBlocks?
    (s : Verso.Genre.Manual.TraverseState) (label : Name) : Option (Array ManualBlock) :=
  (traversalPreview? s label).map (·.blocks)

def renderTraversalPreview? {m} [Monad m]
    (s : Verso.Genre.Manual.TraverseState)
    (renderBlock : ManualBlock → m Verso.Output.Html)
    (label : Name) : m (Option (Array Verso.Output.Html)) := do
  match traversalPreview? s label with
  | none => pure none
  | some preview =>
    pure <| some (← preview.blocks.mapM renderBlock)

def renderTraversalBlocks? {m} [Monad m]
    (s : Verso.Genre.Manual.TraverseState)
    (renderBlock : ManualBlock → m Verso.Output.Html)
    (label : Name) : m (Option (Array Verso.Output.Html)) := do
  match traversalPreview? s label with
  | none => pure none
  | some preview => pure <| some (← preview.blocks.mapM renderBlock)

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
