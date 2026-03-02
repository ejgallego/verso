# Worktree Dashboard

Last updated: 2026-03-02 (merged feat/axioms-as-sorries into bp)

## Inventory and Recommendation

### Active worktrees

- `bp` (root checkout)
  - Path: `/home/egallego/lean/verso-blueprint`
  - Status: rebased over `upstream/main`; owner action: finish full validation pass
  - Base: `upstream/main` @ `8fd45fae` (2026-03-02 fetch)
  - Rebase safety pointer: `bp-pre-rebase-2026-03-02` @ `2eac3ccf`
  - Notes: primary branch.

- `feat/lsp-folding-chain`
  - Path: `/home/egallego/lean/verso-blueprint/.worktrees/lsp-folding-chain`
  - Status: keep (in progress, needs Emilio action)
  - Notes: clean worktree; 2 commits on top of `bp`.

- `feat/versoblueprint-critique`
  - Path: `/home/egallego/lean/verso-blueprint/.worktrees/versoblueprint-critique`
  - Status: active branch, in planning
  - Notes:
    - planning document committed as `a7a0d420`
    - document path: `doc/VersoBlueprintRefactorPlan.md`

### Recently merged / cleaned up

- `feat/axioms-as-sorries`
  - Status: merged into `bp` and cleaned up
  - Merge commit on `bp`: `2ad7bcc4` (fast-forward)
  - Cleanup:
    - worktree removed: `/home/egallego/lean/verso-blueprint/.worktrees/axioms-as-sorries`
    - branch deleted: `feat/axioms-as-sorries`
  - Validation at merge time:
    - `lake build VersoBlueprint.Data VersoBlueprint.Commands VersoBlueprint Tests.BlueprintGraph` passed
    - `lake env lean src/tests/Tests/BlueprintGraph.lean` passed
    - `lake exe noperthedron` passed

### Key Commits (on top of `bp`)

- `b1821909` - `verso: add chained folding ranges including headers and inline Lean`
- `4cafd289` - `verso: cleanup folding metadata plumbing and dedupe helpers`

### Validation Done

- `lake exe noperthedron` passed.
- Interactive tests passed:
  - `src/tests/interactive/test-cases/folding_verso.lean`
  - `src/tests/interactive/test-cases/verso_folding.lean`
  - `src/tests/interactive/test-cases/verso_folding_headers.lean`
  - `src/tests/interactive/test-cases/verso_folding_inline_lean.lean`

### Helpful Resume Notes

- Compare work vs `bp`:
  - `git log --oneline bp..feat/lsp-folding-chain`
  - `git diff --name-only bp..feat/lsp-folding-chain`
- Validate quickly from the worktree:
  - `lake env bash src/tests/interactive/test_single.sh src/tests/interactive/test-cases/verso_folding_inline_lean.lean`
  - `lake exe noperthedron`

## Rebase Notes (2026-03-02)

- Worktree path: `/home/egallego/lean/verso-blueprint`
- Branch: `bp`
- Base branch and commit: `upstream/main` @ `8fd45fae`
- Key commits:
  - New `bp` tip: `1dbc37fe` (`docs: apply dashboard decision and codify decision workflow`)
  - Pre-rebase tip preserved at `bp-pre-rebase-2026-03-02` (`2eac3ccf`)
- Validation status:
  - `lake exe noperthedron` started after rebase and ran until ~`1217/6777` build steps.
  - No build errors observed before manual stop (runtime constrained).
- Resume commands:
  - `git log --oneline --decorate --max-count=20`
  - `git range-diff bp-pre-rebase-2026-03-02...bp`
  - `lake exe noperthedron`
