/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintAttribute.Provider

open Lean
open Informal

namespace Verso.Tests.BlueprintAttribute

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let state := Informal.Environment.informalExt.getState (← getEnv)
    let some theoremNode := state.data.get? (Name.mkSimple "attr.exported.theorem")
      | return false
    let some definitionNode := state.data.get? (Name.mkSimple "attr.exported.definition")
      | return false
    pure (
      theoremNode.kind == .theorem &&
      theoremNode.code.isSome &&
      theoremNode.statement.isSome &&
      definitionNode.kind == .definition &&
      definitionNode.code.isSome &&
      definitionNode.statement.isSome
    )

end Verso.Tests.BlueprintAttribute
