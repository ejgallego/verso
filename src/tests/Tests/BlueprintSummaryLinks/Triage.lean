/- 
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.BlueprintSummaryLinks.Shared

namespace Verso.Tests.BlueprintSummaryLinks.Triage

open Verso.Tests.Blueprint.Support
open Verso.Tests.BlueprintSummaryLinks.Shared

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let out ← renderManualDocHtmlString manualImpls summaryTriageDoc
    pure (
      hasSubstr out "Actionable priorities</span><span class=\"bp_summary_value\">12</span>" &&
      hasSubstr out "Statement-used entries</span><span class=\"bp_summary_value\">12</span>" &&
      hasSubstr out "Proof-used entries</span><span class=\"bp_summary_value\">2</span>" &&
      hasSubstr out "Top priorities (12)" &&
      hasSubstr out "Show all 2 more priorities" &&
      hasSubstr out "Most used in statements (12)" &&
      hasSubstr out "Show all 2 more statement-used entries" &&
      hasSubstr out "Most used in proofs (2)" &&
      hasSubstr out "proof uses: 1" &&
      hasSubstr out "Group health (1)" &&
      hasSubstr out "By parent groups (1)" &&
      hasSubstr out "Metadata" &&
      hasSubstr out "Quick wins (1)" &&
      hasSubstr out "Owner rollups (2)" &&
      hasSubstr out "Tag rollups (" &&
      hasSubstr out "Linked PRs (2)" &&
      hasSubstr out "Metadata audit" &&
      hasSubstr out "Missing owner (" &&
      hasSubstr out "Missing effort (" &&
      hasSubstr out "Untagged (" &&
      hasSubstr out "Alice Example" &&
      hasSubstr out "Bob Example" &&
      hasSubstr out "https://example.com/pr/12" &&
      hasSubstr out "quick-win" &&
      hasSubstr out "Structure and coverage" &&
      hasSubstr out "Heaviest prerequisites (" &&
      hasSubstr out "No prerequisites (" &&
      hasSubstr out "No dependents (" &&
      !hasSubstr out "Proof debt hotspots (0)" &&
      hasSubstr out "Next:" &&
      hasSubstr out "priority: high" &&
      hasSubstr out "priority: low" &&
      !hasSubstr out "Axiom-like Index (0)" &&
      !hasSubstr out "Proof debt hotspots (0)" &&
      appearsBefore out "def:triage.12" "def:triage.01" &&
      hasSubstr out "def:triage.01" &&
      hasSubstr out "downstream unlocks: 1"
    )

end Verso.Tests.BlueprintSummaryLinks.Triage
