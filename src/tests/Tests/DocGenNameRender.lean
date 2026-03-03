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
      | some html => Informal.DocGenHtml.textLength html > 0
      | none => false
    pure (natAddHasPayload && prod?.isSome && missing?.isNone)

end Verso.Tests.DocGenNameRender
