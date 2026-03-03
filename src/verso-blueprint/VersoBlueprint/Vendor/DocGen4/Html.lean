/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex

Vendored/adapted from doc-gen4 `DocGen4/Output/ToHtmlFormat.lean`.
-/

import Lean

namespace Informal.Vendor.DocGen4

/--
Minimal HTML tree for vendored single-declaration rendering.
This intentionally avoids doc-gen's global JSX parser categories.
-/
inductive Html where
  | element : String → Bool → Array (String × String) → Array Html → Html
  | text : String → Html
  | raw : String → Html
  deriving Inhabited, Repr, Lean.ToJson, Lean.FromJson

mutual
  private def quoteHtml : Html → Lean.TSyntax `term
    | .element tag inline attrs children =>
        Lean.Syntax.mkApp (Lean.mkCIdent ``Html.element)
          #[Lean.quote tag, Lean.quote inline, Lean.quote attrs, quoteHtmlArray children]
    | .text s =>
        Lean.Syntax.mkApp (Lean.mkCIdent ``Html.text) #[Lean.quote s]
    | .raw s =>
        Lean.Syntax.mkApp (Lean.mkCIdent ``Html.raw) #[Lean.quote s]

  private def quoteHtmlArray (children : Array Html) : Lean.TSyntax `term :=
    children.foldl
      (init := (Lean.Syntax.mkApp (Lean.mkCIdent ``Array.empty) #[] : Lean.TSyntax `term))
      (fun acc child => Lean.Syntax.mkApp (Lean.mkCIdent ``Array.push) #[acc, quoteHtml child])
end

instance : Lean.Quote Html where
  quote := quoteHtml

instance : Coe String Html := ⟨Html.text⟩

namespace Html

def escape (s : String) : String := Id.run do
  let mut out := ""
  let mut i := s.startPos
  let mut j := s.startPos
  while h : j ≠ s.endPos do
    let c := j.get h
    if let some esc := subst c then
      out := out ++ s.extract i j ++ esc
      j := j.next h
      i := j
    else
      j := j.next h
  if i = s.startPos then s else out ++ s.extract i j
where
  subst : Char → Option String
    | '&' => some "&amp;"
    | '<' => some "&lt;"
    | '>' => some "&gt;"
    | '"' => some "&quot;"
    | _ => none

def attributesToString (attrs : Array (String × String)) : String :=
  attrs.foldl (fun acc (k, v) => acc ++ " " ++ k ++ "=\"" ++ escape v ++ "\"") ""

partial def toStringAux : Html → String
  | .element tag false attrs #[.text s] =>
      s!"<{tag}{attributesToString attrs}>{escape s}</{tag}>\n"
  | .element tag false attrs #[.raw s] =>
      s!"<{tag}{attributesToString attrs}>{s}</{tag}>\n"
  | .element tag false attrs #[child] =>
      s!"<{tag}{attributesToString attrs}>\n{toStringAux child}</{tag}>\n"
  | .element tag false attrs children =>
      s!"<{tag}{attributesToString attrs}>\n{children.foldl (· ++ toStringAux ·) ""}</{tag}>\n"
  | .element tag true attrs children =>
      s!"<{tag}{attributesToString attrs}>{children.foldl (· ++ toStringAux ·) ""}</{tag}>"
  | .text s => escape s
  | .raw s => s

def toString (html : Html) : String :=
  html.toStringAux.trimAsciiEnd.copy

partial def textLength : Html → Nat
  | .raw s => s.length
  | .text s => s.length
  | .element _ _ _ children =>
      children.foldl (fun len child => len + textLength child) 0

end Html

end Informal.Vendor.DocGen4
