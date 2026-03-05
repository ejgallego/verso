/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Lean
import VersoManual
import VersoBlueprint.Macros

open Verso Doc Elab
open Verso.Genre Manual

namespace Informal.Math

open Lean Elab Syntax
open Lean.Doc.Syntax

instance : Quote MathMode where
  quote
    | .inline => mkCApp ``Lean.Doc.MathMode.inline #[]
    | .display => mkCApp ``Lean.Doc.MathMode.display #[]

structure BpMathData where
  mode : MathMode
  source : String
  texPrelude : String := ""
deriving FromJson, ToJson, Repr, Quote

private def mathClasses (mode : MathMode) : String :=
  "math " ++ match mode with
    | .inline => "inline"
    | .display => "display"

inline_extension Inline.bpMath (data : BpMathData) where
  data := toJson data
  traverse _id _data _contents := pure none
  toTeX :=
    open Verso.Output.TeX in
    some <| fun _go _id data _contents => do
      let .ok { mode, source, .. } := fromJson? (α := BpMathData) data
        | TeX.logError s!"Malformed blueprint math payload: {data}"
          pure .empty
      pure <| match mode with
        | .inline => .raw s!"${source}$"
        | .display => .raw s!"\\[{source}\\]"
  toHtml :=
    open Verso.Doc.Html in
    some <| fun _goI _id data _contents => do
      let .ok { mode, source, texPrelude } := fromJson? (α := BpMathData) data
        | HtmlT.logError s!"Malformed blueprint math payload: {data}"
          pure .empty
      let attrs :=
        if texPrelude.isEmpty then
          #[("class", mathClasses mode)]
        else
          #[("class", mathClasses mode), ("data-bp-tex-prelude", texPrelude)]
      pure <| .tag "code" attrs (.text true source)

set_option quotPrecheck false in
def mkBpMathInlineTerm [Monad m] [MonadEnv m] [MonadQuotation m]
    (mode : MathMode) (source : String) : m (TSyntax `term) := do
  let texPrelude ← Informal.Macros.getTexPrelude
  let data : BpMathData := { mode, source, texPrelude }
  ``(
    Verso.Doc.Inline.other
      (Informal.Math.Inline.bpMath $(quote data))
      #[]
  )

@[inline_expander Lean.Doc.Syntax.inline_math]
public meta def _root_.Informal.Math.inlineMathExpand : InlineExpander
  | `(inline| \math code( $s )) =>
    mkBpMathInlineTerm .inline s.getString
  | _ => Lean.Elab.throwUnsupportedSyntax

@[inline_expander Lean.Doc.Syntax.display_math]
public meta def _root_.Informal.Math.displayMathExpand : InlineExpander
  | `(inline| \displaymath code( $s )) =>
    mkBpMathInlineTerm .display s.getString
  | _ => Lean.Elab.throwUnsupportedSyntax

end Informal.Math
