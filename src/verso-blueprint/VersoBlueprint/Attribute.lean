/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean
import Lean.DocString.Extension
import VersoManual
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

mutual

private partial def inlineToManualStx (inl : Lean.Doc.Inline Lean.ElabInline) : CoreM (TSyntax `term) := do
  match inl with
  | .text s => `(Verso.Doc.Inline.text $(quote s))
  | .emph content =>
    let content ← content.mapM inlineToManualStx
    `(Verso.Doc.Inline.emph #[$content,*])
  | .bold content =>
    let content ← content.mapM inlineToManualStx
    `(Verso.Doc.Inline.bold #[$content,*])
  | .code s => `(Verso.Doc.Inline.code $(quote s))
  | .math .inline s => `(Verso.Doc.Inline.math Verso.Doc.MathMode.inline $(quote s))
  | .math .display s => `(Verso.Doc.Inline.math Verso.Doc.MathMode.display $(quote s))
  | .linebreak s => `(Verso.Doc.Inline.linebreak $(quote s))
  | .link content url =>
    let content ← content.mapM inlineToManualStx
    `(Verso.Doc.Inline.link #[$content,*] $(quote url))
  | .footnote name content =>
    let content ← content.mapM inlineToManualStx
    `(Verso.Doc.Inline.footnote $(quote name) #[$content,*])
  | .image alt url => `(Verso.Doc.Inline.image $(quote alt) $(quote url))
  | .concat content =>
    let content ← content.mapM inlineToManualStx
    `(Verso.Doc.Inline.concat #[$content,*])
  -- Fallback for docstring extensions not available in the Manual genre.
  | .other _ content =>
    let content ← content.mapM inlineToManualStx
    `(Verso.Doc.Inline.concat #[$content,*])

private partial def listItemToManualStx
    (item : Lean.Doc.ListItem (Lean.Doc.Block Lean.ElabInline Lean.ElabBlock)) : CoreM (TSyntax `term) := do
  let contents ← item.contents.mapM blockToManualStx
  `(Verso.Doc.ListItem.mk #[$contents,*])

private partial def descItemToManualStx
    (item : Lean.Doc.DescItem (Lean.Doc.Inline Lean.ElabInline) (Lean.Doc.Block Lean.ElabInline Lean.ElabBlock)) :
    CoreM (TSyntax `term) := do
  let term ← item.term.mapM inlineToManualStx
  let desc ← item.desc.mapM blockToManualStx
  `(Verso.Doc.DescItem.mk #[$term,*] #[$desc,*])

private partial def blockToManualStx (b : Lean.Doc.Block Lean.ElabInline Lean.ElabBlock) : CoreM (TSyntax `term) := do
  match b with
  | .para contents =>
    let contents ← contents.mapM inlineToManualStx
    `(Verso.Doc.Block.para #[$contents,*])
  | .code content => `(Verso.Doc.Block.code $(quote content))
  | .ul items =>
    let items ← items.mapM listItemToManualStx
    `(Verso.Doc.Block.ul #[$items,*])
  | .ol start items =>
    let items ← items.mapM listItemToManualStx
    `(Verso.Doc.Block.ol $(quote start) #[$items,*])
  | .dl items =>
    let items ← items.mapM descItemToManualStx
    `(Verso.Doc.Block.dl #[$items,*])
  | .blockquote items =>
    let items ← items.mapM blockToManualStx
    `(Verso.Doc.Block.blockquote #[$items,*])
  | .concat content =>
    let content ← content.mapM blockToManualStx
    `(Verso.Doc.Block.concat #[$content,*])
  -- Fallback for docstring extensions not available in the Manual genre.
  | .other _ content =>
    let content ← content.mapM blockToManualStx
    `(Verso.Doc.Block.concat #[$content,*])

end

private partial def partToManualBlocksStx
    (p : Lean.Doc.Part Lean.ElabInline Lean.ElabBlock Empty) : CoreM (Array (TSyntax `term)) := do
  let mut out : Array (TSyntax `term) := #[]
  if !p.title.isEmpty then
    let title ← p.title.mapM inlineToManualStx
    let titleBold ← `(Verso.Doc.Inline.bold #[$title,*])
    let titleBlock ← `(Verso.Doc.Block.para #[$titleBold])
    out := out.push titleBlock
  out := out ++ (← p.content.mapM blockToManualStx)
  for child in p.subParts do
    out := out ++ (← partToManualBlocksStx child)
  pure out

private def statementFromDocstring? (decl : Name) (ref : Syntax) : CoreM (Option Data.InformalData) := do
  let env ← getEnv
  let internalDoc? ← liftM <| findInternalDocString? env decl
  let elabStx ←
    match internalDoc? with
    | none => pure #[]
    | some (.inl doc) =>
      let doc := doc.trimAscii.toString
      if doc.isEmpty then
        pure #[]
      else
        match MD4Lean.parse doc with
        | some ast =>
          ast.blocks.mapM (fun b =>
            Verso.Genre.Manual.Markdown.blockFromMarkdown b
              (handleHeaders := Verso.Genre.Manual.Markdown.strongEmphHeaders))
        | none =>
          pure #[← `(Verso.Doc.Block.para #[Verso.Doc.Inline.text $(quote doc)])]
    | some (.inr d) =>
      let mut blocks ← d.text.mapM blockToManualStx
      for part in d.subsections do
        blocks := blocks ++ (← partToManualBlocksStx part)
      pure blocks
  if elabStx.isEmpty then
    pure none
  else
    pure <| some {
      stx := ref
      deps := #[]
      elabStx := elabStx.map (·.raw)
    }

private def registerLeanOnlyDecl (decl label : Name) (ref : Syntax) : CoreM Unit := do
  let decl := decl.eraseMacroScopes
  let label := label.eraseMacroScopes
  let some info := (← getEnv).find? decl
    | throwError "unknown declaration '{decl}'"
  let declKind ← classifyDeclKind decl info
  let statement? ← statementFromDocstring? decl ref
  -- logDocstringIfPresent decl

  let definedDecl := mkDefinedDecl decl info
  let (definedDefs, definedTheorems) := mkCodeDecls definedDecl declKind

  Environment.modifyM fun state => do
    let data ← state.data.registerCode label ref definedDefs definedTheorems
    let data :=
      match data.get? label with
      | some node =>
        let node :=
          if node.statement.isNone then
            { node with kind := declKind }
          else
            node
        let node :=
          match statement?, node.statement with
          | some statement, none => { node with statement := some statement }
          | _, _ => node
        data.insert label node
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
    applicationTime := .afterCompilation
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
