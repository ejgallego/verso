/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex

Vendored minimal single-declaration HTML renderer.
-/

import Lean
import VersoBlueprint.Vendor.DocGen4.Html

open Lean

namespace Informal.Vendor.DocGen4

structure DeclHtmlInput where
  moduleName : Name
  declName : Name
  kindDescription : String
  typeText : String
  attrs : Array String := #[]
  docString? : Option String := none
  equations : Array String := #[]
  fields : Array String := #[]
  constructors : Array String := #[]
  deriving Inhabited, Repr

private def kindClass (kind : String) : String :=
  match kind with
  | "def" | "abbrev" => "def"
  | "theorem" => "theorem"
  | "axiom" => "axiom"
  | "opaque" => "opaque"
  | "class" => "class"
  | "structure" => "structure"
  | "inductive" | "constructor" | "recursor" => "inductive"
  | _ => "def"

private def codeSpan (code : String) : Html :=
  .element "code" true #[] #[.text code]

private def attrsHtml (attrs : Array String) : Array Html :=
  if attrs.isEmpty then
    #[]
  else
    #[.element "div" true #[("class", "attributes")]
        #[.text s!"[{String.intercalate ", " attrs.toList}]"]]

private def docStringHtml (doc? : Option String) : Array Html :=
  match doc? with
  | none => #[]
  | some txt => #[.element "pre" false #[("class", "docstring")] #[.text txt]]

private def sectionListHtml (cls title : String) (items : Array String) : Array Html :=
  if items.isEmpty then
    #[]
  else
    let children := items.map fun item => .element "li" true #[] #[.text item]
    #[.element "details" false #[("class", cls)]
        #[
          .element "summary" true #[] #[.text title],
          .element "ul" false #[] children
        ]]

/-- Minimal declaration HTML rendering entry point. -/
def docInfoToHtml (input : DeclHtmlInput) : Html :=
  let headerChildren :=
    #[
      .element "span" true #[("class", "decl_kind")] #[.text input.kindDescription],
      .text " ",
      .element "span" true #[("class", "decl_name")] #[.text input.declName.toString],
      .text " : ",
      .element "span" true #[("class", "decl_type")] #[codeSpan input.typeText]
    ]
  let children :=
    #[.element "div" false #[("class", "decl_header")] headerChildren] ++
    attrsHtml input.attrs ++
    docStringHtml input.docString? ++
    sectionListHtml "equations" "Equations" input.equations ++
    sectionListHtml "fields" "Fields" input.fields ++
    sectionListHtml "constructors" "Constructors" input.constructors
  .element "div" false
    #[
      ("class", s!"declaration decl {kindClass input.kindDescription}"),
      ("data-module", input.moduleName.toString),
      ("data-decl", input.declName.toString)
    ]
    children

end Informal.Vendor.DocGen4
