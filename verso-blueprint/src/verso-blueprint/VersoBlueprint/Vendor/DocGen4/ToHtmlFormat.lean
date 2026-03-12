/-
Copyright (c) 2021 Wojciech Nawrocki. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.

Authors: Wojciech Nawrocki, Sebastian Ullrich, Henrik Böving
-/
import Lean.Data.Json

namespace DocGen4

open Lean

inductive Html where
  -- TODO(WN): it's nameless for shorter JSON; re-add names when we have deriving strategies for From/ToJson
  -- element (tag : String) (flatten : Bool) (attrs : Array HtmlAttribute) (children : Array Html)
  | element : String → Bool → Array (String × String) → Array Html → Html
  /-- A text node, which will be escaped in the output -/
  | text : String → Html
  /-- An arbitrary string containing HTML -/
  | raw : String → Html
  deriving Repr, BEq, Inhabited, FromJson, ToJson

instance : Coe String Html :=
  ⟨Html.text⟩

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
  if i = s.startPos then s  -- no escaping needed, return original
  else out ++ s.extract i j
where
  subst : Char → Option String
    | '&' => some "&amp;"
    | '<' => some "&lt;"
    | '>' => some "&gt;"
    | '"' => some "&quot;"
    | _ => none



def attributesToString (attrs : Array (String × String)) :String :=
  attrs.foldl (fun acc (k, v) => acc ++ " " ++ k ++ "=\"" ++ escape v ++ "\"") ""

-- TODO: Termination proof
partial def toStringAux : Html → String
| element tag false attrs #[text s] => s!"<{tag}{attributesToString attrs}>{escape s}</{tag}>\n"
| element tag false attrs #[raw s] => s!"<{tag}{attributesToString attrs}>{s}</{tag}>\n"
| element tag false attrs #[child] => s!"<{tag}{attributesToString attrs}>\n{child.toStringAux}</{tag}>\n"
| element tag false attrs children => s!"<{tag}{attributesToString attrs}>\n{children.foldl (· ++ toStringAux ·) ""}</{tag}>\n"
| element tag true attrs children => s!"<{tag}{attributesToString attrs}>{children.foldl (· ++ toStringAux ·) ""}</{tag}>"
| text s => escape s
| raw s => s

def toString (html : Html) : String :=
  html.toStringAux.trimAsciiEnd.copy

partial def textLength : Html → Nat
| raw s => s.length  -- measures lengths of escape sequences too!
| text s => s.length
| element _ _ _ children =>
  let lengths := children.map textLength
  lengths.foldl Nat.add 0

end Html

end DocGen4
