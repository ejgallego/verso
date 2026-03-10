# Worktree Dashboard

Last updated: 2026-03-10 (retired `feat/worktree-output-dedup-20260310` after landing its workflow updates on `bp`)

## Active Worktrees

### `bp` (root checkout)

- Status: `active` (owner action: monitor follow-up builder-boundary work)
- Summary: integration baseline branch with recent commands-path and renderer refactors already validated for `noperthedron`.
- Path: `/home/egallego/lean/verso-blueprint`
- Branch: `bp`
- Base commit/branch:
  - local integration branch
- Key commit:
  - `b579013b` informal: harden block parsing and extract group directive
- Validation status:
  - commands-path validation passed before merge:
  - `lake build VersoBlueprint.Commands.Common VersoBlueprint.Commands.Graph VersoBlueprint.Commands.Summary VersoBlueprint.Commands.Bibliography VersoBlueprint`
  - `./generate-example-blueprints.sh`
- Resume commands/notes:
  - `git status --short`
  - `git log --oneline -1`

### `feat/lean-lean-interactive-latency-20260310`

- Status: `active` (owner action: implement the interactive fast path and document the interactive-vs-batch behavior in the user guide)
- Summary: review worktree focused on `src/verso-blueprint/VersoBlueprint/Lean.lean`, where interactive elaboration still unconditionally builds highlighted Lean blocks and declaration metadata even though core editor LSP features appear to read from syntax and info trees. The task now also includes documenting the resulting behavior in the manual.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/lean-lean-interactive-latency-20260310`
- Branch: `feat/lean-lean-interactive-latency-20260310`
- Base commit/branch:
  - branched from `bp` at `2a11a8f9`
- Key commits:
  - none yet
- Validation status:
  - setup complete: worktree created, root `.lake` copied, and `lake exe cache get` completed successfully
  - `./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/lean-lean-interactive-latency-20260310/example-blueprints`
  - reused shared `_out` preview server on `http://127.0.0.1:8154`
- Preview link:
  - `http://127.0.0.1:8154/lean-lean-interactive-latency-20260310/example-blueprints/noperthedron/html-multi/`
  - `http://127.0.0.1:8154/lean-lean-interactive-latency-20260310/example-blueprints/spherepackingblueprint/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/lean-lean-interactive-latency-20260310`
  - inspect `src/verso-blueprint/VersoBlueprint/Lean.lean`, `src/verso-blueprint/VersoBlueprint/Informal/Code.lean`, `src/verso/Verso/Doc/Lsp.lean`, and `doc/UsersGuide/Elab.lean`
  - likely change shape: thread an explicit interactive flag from outer `Command.Context.snap?` into `DocElabContext`, then gate highlight generation and declaration analysis in blueprint Lean blocks
  - manual target: record that interactive Lean editing uses a latency-oriented fast path while batch builds still run full highlighting and blueprint analysis

### `feat/preview-hover-tweaks-20260310`

- Status: `ready-for-review` (owner action: inspect the hover UX follow-up and decide whether this should replace `feat/preview-template-removal-20260310` as the active preview branch)
- Summary: restores bibliography-page hover previews by rendering shared-manifest-backed inline preview refs in "Cited from" rows, and changes nested inline preview behavior so subhovers use a separate transient child panel instead of replacing the parent panel or inheriting pinned+docked behavior from graph/used-by hosts.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/preview-hover-tweaks-20260310`
- Branch: `feat/preview-hover-tweaks-20260310`
- Base commit/branch:
  - rebased on current `bp`
- Key commits:
  - `db39ff3e` fix(preview): align block rebase resolution and group preview test
  - `9e2885e1` fix(preview): restore bibliography hovers and nested subhover panels
- Validation status:
  - post-rebase validation:
  - `lake build Tests.BlueprintPreviewWiring Tests.BlueprintLinkHover Tests.BlueprintSummaryLinks Tests.BlueprintTexMacros`
  - `lake env lean src/tests/Tests/BlueprintPreviewWiring.lean`
  - earlier branch validation before rebase:
  - `lake env lean src/tests/Tests/BlueprintPreviewWiring.lean`
  - `lake env lean src/tests/Tests/BlueprintLinkHover.lean`
  - `lake exe noperthedron --output /home/egallego/lean/verso-blueprint/_out/preview-hover-tweaks-20260310`
  - `./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/preview-hover-tweaks-20260310/example-blueprints`
  - built HTML spot checks:
  - `Blueprint-Bibliography` now emits `.bp_inline_preview_ref` rows with manifest-backed `data-bp-preview-key`
  - `Computational-Step` still emits the theorem 7.15 -> definition 7.10 nested trigger chain
  - `Dependency-Graph` still renders graph previews with nested inline refs in the preview body
  - note: an iframe-based headless hover smoke harness was inconclusive for firing the actual hover handlers, so final UX still wants an interactive browser pass
- Preview link:
  - `http://127.0.0.1:8154/preview-hover-tweaks-20260310/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/preview-hover-tweaks-20260310`
  - inspect `src/verso-blueprint/VersoBlueprint/Commands/Common.lean` and `src/verso-blueprint/VersoBlueprint/Commands/Bibliography.lean`
  - shared `_out` server is running on `http://127.0.0.1:8154/` in session `77001`

### `feat/preview-runtime-fix-20260310`

- Status: `active` (owner action: finish the cold artifact rebuild, then re-check the shipped page that was throwing `cancelChildHide is not defined`)
- Summary: minimal runtime hotfix for the rebased preview line. The inline preview child panel path was calling `cancelChildHide()` without defining it inside `inlineLinkPreviewJs`, which broke all preview hides/shows at runtime. This worktree removes the stray helper from the unrelated shared binder and restores the helper in the actual inline preview closure.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/preview-runtime-fix-20260310`
- Branch: `feat/preview-runtime-fix-20260310`
- Base commit/branch:
  - branched from `feat/preview-hover-tweaks-20260310` at `50407611`
- Key commit:
  - `ab94e276` fix(preview): restore inline child hide helper
- Validation status:
  - `lake build Tests.BlueprintPreviewWiring Tests.BlueprintLinkHover Tests.BlueprintSummaryLinks Tests.BlueprintTexMacros`
  - `lake env lean src/tests/Tests/BlueprintPreviewWiring.lean`
  - `lake env lean src/tests/Tests/BlueprintLinkHover.lean`
  - note: the cold `lake exe noperthedron --output /home/egallego/lean/verso-blueprint/_out/preview-runtime-fix-20260310` rebuild was still running when this dashboard entry was recorded
- Preview link:
  - `http://127.0.0.1:8154/preview-runtime-fix-20260310/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/preview-runtime-fix-20260310`
  - inspect `src/verso-blueprint/VersoBlueprint/Commands/Common.lean`
  - browser repro to re-check after rebuild: `The-Global-Theorem` bibliography hover and inline preview hide path

### `feat/blueprint-metadata-json-review-20260310`

- Status: `active` (owner action: inspect metadata JSON generation and review it for invariants, duplication, and efficiency issues)
- Summary: review worktree forked from the committed head of `feat/preview-template-removal-20260310` to audit the blueprint metadata JSON pipeline without disturbing the source worktree's uncommitted edits.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/blueprint-metadata-json-review-20260310`
- Branch: `feat/blueprint-metadata-json-review-20260310`
- Base commit/branch:
  - branched from `feat/preview-template-removal-20260310` at `a2a6c290`
- Key commits:
  - none yet
- Validation status:
  - setup complete: worktree created, root `.lake` copied, and `lake exe cache get` completed successfully
  - `./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/blueprint-metadata-json-review-20260310/example-blueprints`
  - emitted shared preview manifests:
  - `/home/egallego/lean/verso-blueprint/_out/blueprint-metadata-json-review-20260310/example-blueprints/noperthedron/html-multi/-verso-data/bp-previews.json` (`134` entries, `399424` bytes)
  - `/home/egallego/lean/verso-blueprint/_out/blueprint-metadata-json-review-20260310/example-blueprints/spherepackingblueprint/html-multi/-verso-data/bp-previews.json` (`222` entries, `212375` bytes)
- Preview link:
  - `http://127.0.0.1:8154/blueprint-metadata-json-review-20260310/example-blueprints/noperthedron/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/blueprint-metadata-json-review-20260310`
  - inspect metadata JSON producers and consumers under `src/verso-blueprint`
  - source worktree `/home/egallego/lean/verso-blueprint/.worktrees/preview-template-removal-20260310` was dirty at fork time; this review branch intentionally starts from committed head `a2a6c290`

### `feat/code-summary-badge-unification-20260310`

- Status: `ready-for-review` (owner action: inspect the validated renderer refactor and decide whether to polish further or prepare it for merge)
- Summary: squashed review branch that unifies code-summary rendering in `Informal.CodeSummary`, keeps the pill and `L∃∀N` trigger skins, and routes both through one canonical hover-preview body listing associated constants plus status.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/code-summary-badge-unification-20260310`
- Branch: `feat/code-summary-badge-unification-20260310`
- Base commit/branch:
  - rebased on current `bp`
- Key commits:
  - `b5eab05c` refactor(blueprint): unify code summary surfaces
- Validation status:
  - setup complete: worktree created, root `.lake` copied, and `lake exe cache get` run
  - `lake build Tests.BlueprintExternalHeadingStatus Tests.BlueprintPreviewWiring Tests.BlueprintLinkHover Tests.BlueprintSummaryLinks`
  - `./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/code-summary-badge-unification-20260310/example-blueprints`
  - `lake exe noperthedron --output /home/egallego/lean/verso-blueprint/_out/code-summary-badge-unification-20260310/noperthedron`
- Preview link:
  - `http://127.0.0.1:8156/code-summary-badge-unification-20260310/noperthedron/html-multi/`
  - `http://127.0.0.1:8156/code-summary-badge-unification-20260310/example-blueprints/noperthedron/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/code-summary-badge-unification-20260310`
  - `git status --short`
  - inspect `src/verso-blueprint/VersoBlueprint/Informal/CodeSummary.lean`, `src/verso-blueprint/VersoBlueprint/Informal/ExternalCode.lean`, `src/verso-blueprint/VersoBlueprint/Commands/Common.lean`, `src/verso-blueprint/VersoBlueprint/Commands/Summary.lean`

### `feat/lean-commandm-incremental-20260306`

- Status: `active` (owner action: retest editor UX from the reverted “best current” checkpoint and decide whether a true incremental elaborator is still needed)
- Summary: blueprint Lean fences currently keep doc-side prefix reuse plus outer incremental Verso block commands, while declaration analysis/highlighting/output capture remain disabled for latency. The later full reuse-history fence tree was reverted after regressing UX.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/lean-commandm-incremental-20260306`
- Branch: `feat/lean-commandm-incremental-20260306`
- Base commit/branch:
  - merge-base with `bp`: `ec3cf1ec` (`1` behind / `17` ahead)
- Key commits:
  - `d94efa46` Revert "feat(blueprint): preserve reuse history in fence snapshot tree"
  - `a430f8e0` feat(verso): mark incremental doc blocks as reusable
  - `7719853e` feat(blueprint): add inner fence command snapshots
  - `07d3c604` perf(blueprint): trim fence latency further
- Validation status:
  - `lake build VersoBlueprint.Lean VersoBlueprint.Informal.Code`
  - `lake build Verso.Doc.Concrete VersoManual.Literate VersoBlueprint.Lean VersoBlueprint.Informal.Code`
  - `lake exe noperthedron --output /home/egallego/lean/verso-blueprint/_out/lean-commandm-incremental-20260306` (passed; existing Noperthedron warnings only)
  - note: `lake build Tests` still fails at `Tests.BlueprintInlinePrecision` because blueprint code-block analysis is intentionally disabled in this experiment
- Preview link:
  - `http://127.0.0.1:8152/lean-commandm-incremental-20260306/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/lean-commandm-incremental-20260306`
  - `git log --oneline --decorate -6`
  - inspect `src/verso/Verso/Doc/Concrete.lean`, `src/verso/Verso/Doc/Elab/Monad.lean`, `src/verso-blueprint/VersoBlueprint/Lean.lean`

### `feat/lsp-folding-chain`

- Status: `active` (owner action: rebase before integration)
- Summary: long-running folding-chain refactor with substantial local progress but significant drift from `bp`.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/lsp-folding-chain`
- Branch: `feat/lsp-folding-chain`
- Base commit/branch:
  - merge-base with `bp`: `07af066c` (`60` behind / `28` ahead)
- Key commit:
  - `4cafd289` verso: cleanup folding metadata plumbing and dedupe helpers
- Validation status:
  - worktree currently clean
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/lsp-folding-chain`
  - `git status --short`
  - `git rebase bp`

## Recently Completed

- Retired `feat/worktree-output-dedup-20260310` after landing its workflow updates directly on `bp` in `57795969` (`docs(agents): dedupe preview outputs and add lean wrapper`).
- Validation carried forward from the feature worktree before cleanup:
  - `./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/worktree-output-dedup-20260310/example-blueprints`
- Sanity check on `bp` after landing the wrapper:
  - `script/lean-low-priority true`
- Rebased `feat/worktree-output-dedup-20260310` onto `bp`; the stale one-commit delta dropped because `bp` already carried the stronger `AGENTS.md` wording plus the new tracked wrapper script.
- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/worktree-output-dedup-20260310`.
- Deleted branch: `feat/worktree-output-dedup-20260310`.
