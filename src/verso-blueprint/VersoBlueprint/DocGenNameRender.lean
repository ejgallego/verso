/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Lean
import VersoBlueprint.Vendor.DocGen4.SingleDecl

open Lean Meta

namespace Informal

abbrev DocGenHtml := Vendor.DocGen4.Html

inductive DocGenRenderError where
  | moduleUnavailable (decl : Name)
  | exception (decl : Name) (message : String)
  deriving Repr, Inhabited

deriving instance Lean.ToJson for DocGenRenderError
deriving instance Lean.FromJson for DocGenRenderError

def DocGenRenderError.message : DocGenRenderError → String
  | .moduleUnavailable decl => s!"module unavailable for {decl}"
  | .exception decl message => s!"{decl}: {message}"

private def moduleNameForDecl? (env : Environment) (decl : Name) : Option Name := do
  let moduleIdx ← env.getModuleIdxFor? decl
  env.header.moduleNames[moduleIdx.toNat]?

private def kindDescription (env : Environment) (decl : Name) (cinfo : ConstantInfo) : String :=
  match cinfo with
  | .axiomInfo _ => "axiom"
  | .thmInfo _ => "theorem"
  | .opaqueInfo _ => "opaque"
  | .defnInfo info =>
      if info.hints.isAbbrev then "abbrev" else "def"
  | .inductInfo _ =>
      if isClass env decl then "class"
      else if isStructure env decl then "structure"
      else "inductive"
  | .ctorInfo _ => "constructor"
  | .quotInfo _ => "quot"
  | .recInfo _ => "recursor"

private def ppExprString (expr : Expr) : MetaM String := do
  return toString (← ppExpr expr)

private def fieldNames (env : Environment) (decl : Name) : Array String :=
  match getStructureInfo? env decl with
  | some info => info.fieldNames.map Name.toString
  | none => #[]

private def ctorNames (cinfo : ConstantInfo) : Array String :=
  match cinfo with
  | .inductInfo info => info.ctors.toArray.map Name.toString
  | _ => #[]

private def mkDeclHtmlInput
    (env : Environment) (moduleName : Name) (decl : Name) (cinfo : ConstantInfo) : MetaM Vendor.DocGen4.DeclHtmlInput := do
  let typeText ← ppExprString cinfo.type
  let docString? ← liftM <| findDocString? env decl
  pure {
    moduleName := moduleName
    declName := decl
    kindDescription := kindDescription env decl cinfo
    typeText := typeText
    docString? := docString?
    fields := fieldNames env decl
    constructors := ctorNames cinfo
  }

/--
Render one declaration directly from known declaration facts.
Errors represent rendering failures only; declaration lookup is handled by callers.
-/
def renderDeclHtmlStringDirectFromInfoE
    (moduleName : Name) (decl : Name) (cinfo : ConstantInfo) : MetaM (Except DocGenRenderError String) := do
  try
    let env ← getEnv
    let input ← mkDeclHtmlInput env moduleName decl cinfo
    return .ok (Vendor.DocGen4.Html.toString (Vendor.DocGen4.docInfoToHtml input))
  catch ex =>
    return .error (.exception decl (← ex.toMessageData.toString))

/-- Render one declaration directly from the in-memory `Environment` (no database, no source parsing). -/
def renderDeclHtmlNodeDirect? (decl : Name) : MetaM (Option DocGenHtml) := do
  let decl := decl.eraseMacroScopes
  try
    let env ← getEnv
    let some cinfo := env.find? decl
      | return none
    let some moduleName := moduleNameForDecl? env decl
      | return none
    let input ← mkDeclHtmlInput env moduleName decl cinfo
    return some (Vendor.DocGen4.docInfoToHtml input)
  catch ex =>
    logError m!"DocGen direct rendering failed for {decl}: {← ex.toMessageData.toString}"
    return none

/-- String wrapper over `renderDeclHtmlNodeDirect?`. -/
def renderDeclHtmlStringDirect? (decl : Name) : MetaM (Option String) := do
  match ← renderDeclHtmlNodeDirect? decl with
  | some html => return some (Vendor.DocGen4.Html.toString html)
  | none => return none

/--
Optional fallback path for non-`MetaM` contexts.
With the dependency removed, this currently returns `none`.
-/
def renderDeclHtmlNodeFromDb? (_dbPath : System.FilePath) (_decl : Name) : IO (Option DocGenHtml) := do
  IO.eprintln "[doc-gen db] fallback unavailable: doc-gen4 dependency removed"
  return none

/-- Smoke demo targets: theorem/def (`Nat.add`), structure (`Prod`), and a missing name. -/
def docGenNameRenderSmokeDecls : Array Name := #[`Nat.add, `Prod, `No.Such.Declaration]

/-- Smoke demo helper for quick direct-path checks. -/
def runDocGenNameRenderSmokeDirect : MetaM (Array (Name × Option String)) := do
  docGenNameRenderSmokeDecls.mapM fun decl => do
    let rendered? ← renderDeclHtmlStringDirect? decl
    if let some html := rendered? then
      logInfo m!"[doc-gen direct smoke] {decl}: rendered ({html.length} chars)"
    else
      logInfo m!"[doc-gen direct smoke] {decl}: none"
    pure (decl, rendered?)

end Informal
