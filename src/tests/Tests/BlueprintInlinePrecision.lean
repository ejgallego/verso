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
open Informal.Graph

namespace Verso.Tests.BlueprintInlinePrecision

#docs (Manual) inlineHelperProofGapDoc "Inline Helper Proof Gap" :=
:::::::
:::theorem "inline.theorem.helper"
Statement body.
:::

```lean "inline.theorem.helper"
def helper_inline_proof_gap : Nat := by
  sorry

theorem inline_main_complete : True := by
  trivial
```
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show CoreM Bool from do
    let label := Name.mkSimple "inline.theorem.helper"
    let state := Informal.Environment.informalExt.getState (← getEnv)
    match state.data.get? label with
    | none => pure false
    | some node =>
      let external : ExternalCodeStatus := {}
      let helperProofGapOnly :=
        match node.code with
        | some (.literate code) =>
          code.definedDefs.any fun decl =>
            let (typeRefs, proofRefs) := decl.provedStatus.sorryRefCounts
            decl.provedStatus.hasProofGap &&
            !decl.provedStatus.hasTypeGap &&
            typeRefs == 0 &&
            proofRefs > 0
        | _ => false
      pure <|
        node.kind == .theorem &&
        nodeLocalStatementFormalized external node &&
        !nodeLocalProofFormalized external node &&
        helperProofGapOnly

end Verso.Tests.BlueprintInlinePrecision
