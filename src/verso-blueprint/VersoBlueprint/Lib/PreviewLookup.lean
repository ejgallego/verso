/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import VersoManual
import VersoBlueprint.PreviewCache
import VersoBlueprint.Resolve

namespace Informal.PreviewLookup

open Lean

abbrev ManualBlock := Verso.Doc.Block Verso.Genre.Manual

private def decodeFacet
    (s : Verso.Genre.Manual.TraverseState) (label : Name)
    (facet : PreviewCache.Facet) : Option (Array ManualBlock) := do
  let key := PreviewCache.key label facet
  let obj ← s.getDomainObject? Resolve.informalPreviewDomainName key
  let entry ← (fromJson? (α := PreviewCache.Entry) obj.data).toOption
  return entry.blocks

def previewBlocksForFacet?
    (s : Verso.Genre.Manual.TraverseState) (label : Name)
    (facet : PreviewCache.Facet) : Option (Array ManualBlock) :=
  decodeFacet s label facet

def previewBlocks?
    (s : Verso.Genre.Manual.TraverseState) (label : Name) : Option (Array ManualBlock) :=
  match previewBlocksForFacet? s label .statement with
  | some blocks => some blocks
  | none => previewBlocksForFacet? s label .proof

end Informal.PreviewLookup
