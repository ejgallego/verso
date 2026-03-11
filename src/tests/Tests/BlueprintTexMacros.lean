/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintTexMacros.Root
import Tests.Blueprint.Support

namespace Verso.Tests.BlueprintTexMacros

open Lean
open Verso
open Verso.Genre.Manual
open Informal
open Verso.Tests.Blueprint.Support

set_option doc.verso true

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let chunks ← Informal.Macros.getTexPreludeChunks
    pure (chunks == #[r#"\newcommand{\sharedmacro}{\mathsf{Shared}}"#])

tex_prelude r#"\newcommand{\widgetmacro}{\mathsf{Widget}}"#

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let chunks ← Informal.Macros.getTexPreludeChunks
    pure (
      chunks == #[
        r#"\newcommand{\sharedmacro}{\mathsf{Shared}}"#,
        r#"\newcommand{\widgetmacro}{\mathsf{Widget}}"#
      ]
    )

#docs (Genre.Manual) widgetPreviewDoc "Blueprint Widget Preview" :=
:::::::
:::definition "widget_preview"
Widget preview uses $`\widgetmacro`.
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show Lean.Elab.Term.TermElabM Bool from do
    let out ← buildFor (Name.mkSimple "widget_preview")
    let statementHtml := toJson (← Informal.PreviewSource.renderWidgetHtml out.statementPreview?)
    let encoded := Json.compress statementHtml
    pure (
      out.statementPreview?.map (fun preview => !preview.blocks.isEmpty && preview.stxs.isEmpty) == some true &&
      hasSubstr encoded "data-bp-tex-prelude" &&
      hasSubstr encoded "sharedmacro" &&
      hasSubstr encoded "widgetmacro" &&
      !hasSubstr encoded "\"texPrelude\"" &&
      !hasSubstr blueprintWidget.javascript "texPrelude"
    )

end Verso.Tests.BlueprintTexMacros
