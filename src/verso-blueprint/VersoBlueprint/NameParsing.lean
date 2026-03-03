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

end Informal.NameParsing
