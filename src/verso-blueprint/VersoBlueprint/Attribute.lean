/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import VersoBlueprint.Environment

namespace Informal

open Lean

syntax (name := blueprint) "blueprint" (ppSpace ident)? (ppSpace str)? : attr

private def mkDefinedDecl (decl : Name) (info : ConstantInfo) : Data.DefinedDecl :=
  let hasTypeSorry := info.type.hasSorry
  let hasProofSorry := info.value?.map (·.hasSorry) |>.getD false
  {
    name := decl
    hasSorry := hasTypeSorry || hasProofSorry
    hasTypeSorry
    hasProofSorry
  }

private def registerLeanOnlyDef (decl label : Name) (ref : Syntax) : CoreM Unit := do
  let decl := decl.eraseMacroScopes
  let label := label.eraseMacroScopes
  let some info := (← getEnv).find? decl
    | throwError "unknown declaration '{decl}'"

  let definedDecl := mkDefinedDecl decl info
  let codeInfo : Data.CodeInfo := {
    proved := false
    definedDefs := #[definedDecl]
    definedTheorems := #[]
  }

  Environment.modifyM fun state => do
    let data ← state.data.registerCode label ref (some codeInfo)
    let data :=
      match data.get? label with
      | some node =>
        if node.statement == .missing then
          data.modify label fun node => { node with kind := "Definition" }
        else
          data
      | none => data
    return { state with data }

private def labelFromAttr (decl : Name) (stx : Syntax) : CoreM Name := do
  match stx with
  | `(attr| blueprint) => pure decl
  | `(attr| blueprint $lbl:ident) => pure lbl.getId
  | `(attr| blueprint $lbl:str) => pure (Name.mkSimple lbl.getString)
  | _ => throwError "invalid syntax for '[blueprint]' attribute"

open Lean in
initialize
  registerBuiltinAttribute {
    name := `blueprint
    ref := by exact decl_name%
    add := fun decl stx kind => do
      unless kind == AttributeKind.global do
        throwError "invalid attribute '[blueprint]', must be global"
      unless ((← getEnv).getModuleIdxFor? decl).isNone do
        throwError "invalid attribute '[blueprint]', declaration is in an imported module"
      let label ← labelFromAttr decl stx
      registerLeanOnlyDef decl label stx
    descr := "Registers a declaration as a Lean-only definition node in the blueprint environment; optional argument sets the node label"
  }

end Informal
