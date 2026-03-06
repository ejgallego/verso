/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import VersoBlueprint.DocGenNameRender

namespace Verso.Tests.DocGenNameRender

/-- info: true -/
#guard_msgs in
#eval
  show Lean.CoreM Bool from do
    let natAdd? ← (Informal.renderDeclHtmlNodeDirect? `Nat.add).run'
    let prod? ← (Informal.renderDeclHtmlNodeDirect? `Prod).run'
    let missing? ← (Informal.renderDeclHtmlNodeDirect? `No.Such.Declaration).run'
    let natAddHasPayload :=
      match natAdd? with
      | some html => html.asString.length > 0
      | none => false
    let natAddHasLocalHover :=
      match natAdd? with
      | some html =>
        let out := html.asString
        out.contains "class=\"hover-info\"" && !out.contains "data-verso-hover="
      | none => false
    pure (natAddHasPayload && natAddHasLocalHover && prod?.isSome && missing?.isNone)

end Verso.Tests.DocGenNameRender
