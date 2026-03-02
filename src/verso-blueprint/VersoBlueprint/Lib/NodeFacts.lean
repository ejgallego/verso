/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import VersoBlueprint.Data
import VersoBlueprint.Graph

namespace Informal.NodeFacts

open Lean
open Informal Data

private def canonicalDecl (decl : Name) : Name :=
  decl.eraseMacroScopes

def externalDeclMissing (env : Lean.Environment) (decl : Name) : Bool :=
  (env.find? (canonicalDecl decl)).isNone

def externalDeclProvedStatus (env : Lean.Environment) (decl : Name) : Data.ProvedStatus :=
  match env.find? (canonicalDecl decl) with
  | none => .proved
  | some info => _root_.Informal.Data.ConstantInfo.blueprintProvedStatus info (allowOpaque := true)

def externalDeclIsTheoremLike (env : Lean.Environment) (decl : Name) : Bool :=
  match env.find? (canonicalDecl decl) with
  | some (.thmInfo _) => true
  | _ => false

structure ExternalDeclAdapter where
  isMissing : Name → Bool := fun _ => false
  provedStatus : Name → Data.ProvedStatus := fun _ => .proved
  isTheoremLike : Name → Bool := fun _ => false

def ExternalDeclAdapter.ofEnv (env : Lean.Environment) : ExternalDeclAdapter :=
  {
    isMissing := externalDeclMissing env
    provedStatus := externalDeclProvedStatus env
    isTheoremLike := externalDeclIsTheoremLike env
  }

def ExternalDeclAdapter.graphStatus (adapter : ExternalDeclAdapter) : Informal.Graph.ExternalCodeStatus :=
  {
    isMissing := adapter.isMissing
    provedStatus := adapter.provedStatus
  }

end Informal.NodeFacts
