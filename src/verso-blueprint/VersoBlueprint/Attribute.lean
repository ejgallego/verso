/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Lean.DocString.Extension
import VersoBlueprint.Environment

namespace Informal

open Lean

syntax (name := blueprint) "blueprint" ppSpace str : attr

private def constantInfoKind : ConstantInfo → String
  | .axiomInfo _ => "axiom"
  | .defnInfo _ => "definition"
  | .thmInfo _ => "theorem"
  | .opaqueInfo _ => "opaque"
  | .quotInfo _ => "quot primitive"
  | .inductInfo _ => "inductive"
  | .ctorInfo _ => "constructor"
  | .recInfo _ => "recursor"

private def classifyDeclKind (decl : Name) (info : ConstantInfo) : CoreM Data.NodeKind :=
  match info with
  | .defnInfo _ => pure .definition
  | .thmInfo _ => pure .theorem
  | _ =>
    throwError "invalid '[blueprint]' target '{decl}': expected a definition or theorem, got {constantInfoKind info}"

private def mkDefinedDecl (decl : Name) (info : ConstantInfo) : Data.DefinedDecl :=
  let hasTypeSorry := info.type.hasSorry
  let hasProofSorry := info.value?.map (·.hasSorry) |>.getD false
  {
    name := decl
    hasSorry := hasTypeSorry || hasProofSorry
    hasTypeSorry
    hasProofSorry
  }

private def mkCodeDecls (definedDecl : Data.DefinedDecl) (declKind : Data.NodeKind) :
    Array Data.DefinedDecl × Array Data.DefinedDecl :=
  match declKind with
  | .definition => (#[definedDecl], #[])
  | .theorem => (#[], #[definedDecl])
  | _ => panic! "impossible: classifyDeclKind only returns definition/theorem"

private def logDocstringIfPresent (decl : Name) : CoreM Unit := do
  let env ← getEnv
  let internalDoc? ← liftM <| findInternalDocString? env decl
  if let some doc := internalDoc? then
    let asText? ← liftM <| findSimpleDocString? env decl
    let isVerso : Bool := match doc with | Sum.inl _ => false | Sum.inr _ => true
    let rendered := asText?.getD "<unable to render docstring text>"
    logInfo m!"[blueprint] docstring for '{decl}' (isVerso := {isVerso}):\n{rendered}"

private def registerLeanOnlyDecl (decl label : Name) (ref : Syntax) : CoreM Unit := do
  let decl := decl.eraseMacroScopes
  let label := label.eraseMacroScopes
  let some info := (← getEnv).find? decl
    | throwError "unknown declaration '{decl}'"
  let declKind ← classifyDeclKind decl info
  logDocstringIfPresent decl

  let definedDecl := mkDefinedDecl decl info
  let (definedDefs, definedTheorems) := mkCodeDecls definedDecl declKind

  Environment.modifyM fun state => do
    let data ← state.data.registerCode label ref definedDefs definedTheorems
    let data :=
      match data.get? label with
      | some node =>
        if node.statement.isNone then
          data.modify label fun node => { node with kind := declKind }
        else
          data
      | none => data
    return { state with data }

private def labelFromAttr (stx : Syntax) : CoreM Name := do
  match stx with
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
      let label ← labelFromAttr stx
      registerLeanOnlyDecl decl label stx
    descr := "Registers a definition/theorem as a Lean-only blueprint node; argument sets the node label (string literal)"
  }

end Informal
