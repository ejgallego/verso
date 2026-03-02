# Worktree Dashboard

Last updated: 2026-03-02 (feat/axioms-as-sorries)

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

- `feat/axioms-as-sorries`
  - Path: `/home/egallego/lean/verso-blueprint/.worktrees/axioms-as-sorries`
  - Branch: `feat/axioms-as-sorries`
  - Status: validated (includes `ProvedStatus` refactor); owner action: review diff and commit
  - Base: `bp` @ `1cb7cbe5`
  - Key commits: none yet (working tree changes only)
  - Notes:
    - summary now consumes `ProvedStatus` directly (explicit `axiom-like` rows, no legacy ref-count classification path)
    - external declarations now contribute to incomplete summary counts/details when status is not `.proved`
    - summary includes a dedicated "Missing external Lean declarations" card + detail section for unresolved `(lean := ...)` names
    - external missing-declaration reporting now uses a registration-time snapshot (`ExternalRef.presentAtRegistration`) as single source for both code panels and summary
    - verified case: `Local.congruent_iff_sym_matrix_eq` appears in summary missing section when panel marks it missing
  - Validation:
    - `lake build VersoBlueprint.Data VersoBlueprint.Commands VersoBlueprint Tests.BlueprintGraph` passed
    - `lake env lean src/tests/Tests/BlueprintGraph.lean` passed
    - `lake exe noperthedron` passed
  - Resume notes:
    - `git -C .worktrees/axioms-as-sorries status --short`
    - `git -C .worktrees/axioms-as-sorries diff -- src/verso-blueprint/VersoBlueprint/Data.lean src/verso-blueprint/VersoBlueprint/Lean.lean src/verso-blueprint/VersoBlueprint/Graph.lean src/verso-blueprint/VersoBlueprint/Commands.lean src/verso-blueprint/VersoBlueprint.lean src/tests/Tests/BlueprintGraph.lean`
    - `lake exe noperthedron`

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
