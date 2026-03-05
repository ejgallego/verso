/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean

namespace Informal.NameParsing

open Lean

register_option verso.blueprint.trimTeXLabelPrefix : Bool := {
  defValue := false
  descr := "Trim TeX-style label prefixes for Lean-facing names (`thm:foo` -> `foo`)"
}

/-- Trim leading/trailing ASCII whitespace from a user-provided name fragment. -/
def normalize (s : String) : String :=
  s.trimAscii.toString

/-- Return the suffix of a TeX-style `prefix:suffix` label when present and non-empty. -/
private def texStyleSuffix? (s : String) : Option String :=
  match s.splitOn ":" with
  | [] => none
  | _ :: [] => none
  | pref :: suffixParts =>
    let suffix := String.intercalate ":" suffixParts
    if pref.isEmpty || suffix.isEmpty then
      none
    else
      some suffix

/-- Trim TeX-style `prefix:suffix` labels to `suffix`; non-matching inputs are unchanged. -/
def trimTeXStylePrefix (s : String) : String :=
  (texStyleSuffix? s).getD s

/-- Whether TeX-style label trimming is enabled in the provided option set. -/
def trimTeXStylePrefixEnabled (opts : Lean.Options) : Bool :=
  opts.get
    verso.blueprint.trimTeXLabelPrefix.name
    verso.blueprint.trimTeXLabelPrefix.defValue

/-- Conditionally trim TeX-style prefixes according to `verso.blueprint.trimTeXLabelPrefix`. -/
def maybeTrimTeXStylePrefix (opts : Lean.Options) (s : String) : String :=
  if trimTeXStylePrefixEnabled opts then
    trimTeXStylePrefix s
  else
    s

/-- Parse a user-provided dotted Lean name using Lean's standard `String.toName` parser. -/
def parseName? (s : String) : Option Name :=
  let s := normalize s
  if s.isEmpty then
    none
  else
    let n := s.toName
    if n.isAnonymous then none else some n

/--
Parse a Lean-facing name from user input while applying the TeX-prefix trimming policy.
-/
def parseLeanName? (opts : Lean.Options) (s : String) : Option Name :=
  parseName? <| maybeTrimTeXStylePrefix opts (normalize s)

/-- Like `parseLeanName?`, but returns an error string preserving prior caller behavior. -/
def parseLeanNameE (opts : Lean.Options) (s : String) : Except String Name :=
  let normalized := maybeTrimTeXStylePrefix opts (normalize s)
  if normalized.isEmpty then
    .error "empty name"
  else
    match parseName? normalized with
    | some n => .ok n
    | none => .error s!"invalid Lean name '{normalized}'"

/-- Apply TeX-prefix trimming policy to a label/name that is already a Lean `Name`. -/
def maybeTrimTeXStyleName (opts : Lean.Options) (name : Name) : Name :=
  match parseLeanName? opts name.toString with
  | some parsed => parsed
  | none => name

end Informal.NameParsing
