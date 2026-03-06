/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import VersoBlueprint

namespace Verso.Tests.BlueprintMathLint

open Informal

private def extractedRaw? (rawSource : String) (span : Informal.MathLint.Span) : Option String := do
  let (start, stop) ← Informal.MathLint.inlineCodeRawRangeOfDecodedSpan? rawSource span
  pure <| start.extract rawSource stop

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let source := r#"\undefinedmacro"#
    let some failure ← Informal.MathLint.lint? {
      mode := .inline
      source
    }
      | pure true
    pure <|
      failure.reason.contains "Undefined control sequence" &&
      failure.site == .source { start := 0, length := source.length } { start := 0, length := source.length }

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let report ← Informal.MathLint.lint? {
      mode := .inline
      source := r#"\foo + 1"#
      texPrelude := r#"\newcommand{\foo}{\mathsf{Foo}}"#
    }
    pure report.isNone

/-- info: true -/
#guard_msgs in
#eval
  show Bool from
    extractedRaw? r#"\`x"# { start := 0, length := 1 } == some r#"\`"#

/-- info: true -/
#guard_msgs in
#eval
  show Bool from
    extractedRaw? r#"\\x"# { start := 0, length := 1 } == some r#"\\"#

/-- info: true -/
#guard_msgs in
#eval
  show Bool from
    extractedRaw? r#"\alpha"# { start := 0, length := 6 } == some r#"\alpha"#

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let some failure ← Informal.MathLint.lint? {
      mode := .inline
      source := r#"\frac{a}{"#
    }
      | pure true
    pure <| failure.site == .source { start := 9, length := 0 } { start := 9, length := 0 }

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let some failure ← Informal.MathLint.lint? {
      mode := .display
      source := r#"\foo + 1"#
      texPrelude := r#"\newcommand{\foo}{\mathsf{Foo}"#
    }
      | pure true
    pure <|
      failure.reason.contains "expected '}'" &&
      match failure.site with
      | .prelude { start, length } => start > 0 && length == 0
      | _ => false

end Verso.Tests.BlueprintMathLint
