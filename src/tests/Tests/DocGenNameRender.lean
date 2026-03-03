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
    let natAdd? ← (Informal.renderDeclHtmlStringDirect? `Nat.add).run'
    let prod? ← (Informal.renderDeclHtmlStringDirect? `Prod).run'
    let missing? ← (Informal.renderDeclHtmlStringDirect? `No.Such.Declaration).run'
    pure (natAdd?.isSome && prod?.isSome && missing?.isNone)

end Verso.Tests.DocGenNameRender
