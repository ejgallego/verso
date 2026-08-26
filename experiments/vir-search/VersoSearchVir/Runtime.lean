/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Vir
import VersoSearch.ExperimentalVIR
import VersoSearchVir.FullLean

namespace VersoSearchVir.Runtime

open Verso.Search.ExperimentalVIR

/-- Starts the Lean-owned quick-jump component without a Verso-specific JavaScript call. -/
@[vir_startup]
def mountFullLeanSearch : Lean.Vir.Browser.DomM Unit :=
  VersoSearchVir.FullLean.mount

/-- Maps a built-in Verso xref domain through the experimental typed Lean implementation. -/
@[vir_export]
def mapDomainJson (domainId domainData : String) : Except String String :=
  Verso.Search.ExperimentalVIR.mapDomainJsonVIR domainId domainData

/-- Normalizes, prioritizes, merges, and stably sorts raw browser search hits. -/
@[vir_export]
def rankCandidates
    (semanticHits : Array SemanticHit) (fullTextHits : Array FullTextHit) :
    Array RankedCandidate :=
  Verso.Search.ExperimentalVIR.rankCandidates semanticHits fullTextHits

end VersoSearchVir.Runtime
