/-
Copyright (c) 2026 Lean FRO LLC. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Author: OpenAI Codex
-/

import Tests.Blueprint.Support

namespace Verso.Tests.BlueprintSummaryLinks

open Verso
open Verso.Genre.Manual
open Informal
open Verso.Tests.Blueprint.Support

set_option doc.verso true

private def manualImpls : ExtensionImpls := extension_impls%

#docs (Genre.Manual) externalSummaryLinksDoc "External Summary Links" :=
:::::::
:::definition "def:external.summary" (lean := "Nat.add")
External declaration wiring test.
:::

{bp_summary}
:::::::

/--
warning: Label «def:blocker.missing»: external Lean name 'Nat.nope' could not be resolved in current namespace/open declarations; keeping parsed name
---
info: Blueprint summary for 3 entries
-/
#guard_msgs in
#docs (Genre.Manual) summaryBlockersDoc "Summary Blockers" :=
:::::::
:::definition "def:blocker.missing" (lean := "Nat.nope")
Missing external declaration sample.
:::

:::definition "def:blocker.sorry"
Inline sorry sample.
:::

```lean "def:blocker.sorry"
theorem summaryBlockerSorry : True := by
  sorry
```

{bp_summary}
:::::::

#docs (Genre.Manual) summaryTriageDoc "Summary Triage" :=
:::::::
:::author "alice" (name := "Alice Example")
:::

:::author "bob" (name := "Bob Example")
:::

:::group "triage.group"
Triage group heading.
:::

:::definition "def:triage.01" (parent := "triage.group") (owner := "alice") (tags := "foundation, local") (effort := "small") (priority := "low") (pr_url := "https://example.com/pr/1")
Definition 01.
:::

:::definition "def:triage.02" (parent := "triage.group")
Definition 02.
:::

:::definition "def:triage.03" (parent := "triage.group")
Definition 03.
:::

:::definition "def:triage.04" (parent := "triage.group")
Definition 04.
:::

:::definition "def:triage.05" (parent := "triage.group")
Definition 05.
:::

:::definition "def:triage.06" (parent := "triage.group")
Definition 06.
:::

:::definition "def:triage.07" (parent := "triage.group")
Definition 07.
:::

:::definition "def:triage.08" (parent := "triage.group")
Definition 08.
:::

:::definition "def:triage.09" (parent := "triage.group")
Definition 09.
:::

:::definition "def:triage.10" (parent := "triage.group")
Definition 10.
:::

:::definition "def:triage.11" (parent := "triage.group")
Definition 11.
:::

:::definition "def:triage.12" (parent := "triage.group") (owner := "bob") (tags := "critical, quick-win") (effort := "small") (priority := "high") (pr_url := "https://example.com/pr/12")
Definition 12.
:::

:::theorem "thm:triage.main" (parent := "triage.group") (owner := "alice") (tags := "critical") (effort := "large")
Depends on
{uses "def:triage.01"}[],
{uses "def:triage.02"}[],
{uses "def:triage.03"}[],
{uses "def:triage.04"}[],
{uses "def:triage.05"}[],
{uses "def:triage.06"}[],
{uses "def:triage.07"}[],
{uses "def:triage.08"}[],
{uses "def:triage.09"}[],
{uses "def:triage.10"}[],
{uses "def:triage.11"}[],
and {uses "def:triage.12"}[].
:::

:::theorem "thm:triage.proof" (parent := "triage.group")
Proof-only dependency sample.
:::

:::proof "thm:triage.proof"
Proof uses {uses "def:triage.01"}[] and {uses "def:triage.02"}[].
:::

{bp_summary}
:::::::

/-- info: true -/
#guard_msgs in
#eval
  show IO Bool from do
    let out ← renderManualDocHtmlString manualImpls externalSummaryLinksDoc
    pure (
      hasSubstr out "class=\"bp_summary_decl_list\"" &&
      hasSubstr out "class=\"bp_inline_preview_ref\" data-bp-preview-id=\"bp-lean-code-Informal-002ELeanCodePreview-002ENat-002Eadd\"" &&
      hasSubstr out "data-bp-preview-key=\"Informal.LeanCodePreview.Nat.add\"" &&
      hasSubstr out "href=\"#--informal-external-decl-" &&
      hasSubstr out "class=\"bp_external_decl_item bp_external_decl_item_rendered\" id=\"--informal-external-decl-" &&
      !hasSubstr out "Lean code:"
    )

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

end Verso.Tests.BlueprintSummaryLinks
