/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import VersoBlueprint
import VersoManual

open Lean
open Verso Genre Manual
open Informal

namespace Verso.Tests.BlueprintInformal

/-- info: true -/
#guard_msgs in
#eval
  Informal.shouldWritePreviewDataByIds (#[] : Array Nat) 7 &&
  Informal.shouldWritePreviewDataByIds #[1, 7, 9] 7 &&
  !(Informal.shouldWritePreviewDataByIds #[1, 2, 3] 7)

/--
warning: Label «bad.warning»: external Lean name 'No.Such.Decl' could not be resolved in current namespace/open declarations; keeping parsed name
-/
#guard_msgs in
#docs (Manual) malformedLeanRef "Malformed Lean Ref" :=
:::::::
:::definition "bad.warning" (lean := "No.Such.Decl")
Simple body.
:::
:::::::

/--
error: Label «bad.error» cannot use '(leanok := true)' together with '(lean := ...)'
-/
#guard_msgs in
#docs (Manual) conflictingLeanHints "Conflicting Lean Hints" :=
:::::::
:::definition "bad.error" (lean := "Nat.add") (leanok := true)
Simple body.
:::
:::::::

#docs (Manual) groupHeaderDoc "Group Header" :=
:::::::
:::group "grp.quoted"
A "quoted" heading.
:::
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let state := Informal.Environment.informalExt.getState (← getEnv)
    pure <| state.groups.get? (Name.mkSimple "grp.quoted") == some "A \"quoted\" heading."

end Verso.Tests.BlueprintInformal
