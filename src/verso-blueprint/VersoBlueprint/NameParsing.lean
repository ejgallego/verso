/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: Emilio J. Gallego Arias
-/

import Lean

namespace Informal.NameParsing

open Lean

/-- Trim leading/trailing ASCII whitespace from a user-provided name fragment. -/
def normalize (s : String) : String :=
  s.trimAscii.toString

/-- Parse a user-provided dotted Lean name using Lean's standard `String.toName` parser. -/
def parseName? (s : String) : Option Name :=
  let s := normalize s
  if s.isEmpty then
    none
  else
    let n := s.toName
    if n.isAnonymous then none else some n

/--
Parse a user-provided Lean name and return a detailed error when parsing fails.
-/
def parseNameE (s : String) : Except String Name :=
  let normalized := normalize s
  if normalized.isEmpty then
    .error "empty name"
  else
    let n := normalized.toName
    if n.isAnonymous then
      .error s!"invalid Lean name '{normalized}'"
    else
      .ok n

/--
Split a comma-separated list of user names and normalize each entry.

TODO: This parser is plain CSV (`splitOn ","`) and does not support quoted commas
inside escaped name components such as `«a,b»`.
-/
def splitCsvNormalized (s : String) : Array String :=
  s.splitOn ","
  |>.toArray
  |>.map normalize
  |>.filter (fun p => !p.isEmpty)

end Informal.NameParsing
