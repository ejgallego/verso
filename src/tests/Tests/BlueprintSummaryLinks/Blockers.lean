/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintSummaryLinks.Shared

namespace Verso.Tests.BlueprintSummaryLinks.Blockers

open Verso.Tests.Blueprint.Support
open Verso.Tests.BlueprintSummaryLinks.Shared

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let out ← renderManualDocHtmlString manualImpls summaryBlockersDoc
    pure (
      hasSubstr out "Blockers (2)" &&
      hasSubstr out "Missing external Lean declarations (1)" &&
      hasSubstr out "Incomplete Lean declarations (1)" &&
      !hasSubstr out "Incomplete details ("
    )

end Verso.Tests.BlueprintSummaryLinks.Blockers
