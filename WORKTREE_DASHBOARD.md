# Worktree Dashboard

Last updated: 2026-02-26

## Inventory and Recommendation

### Active worktrees

- `bp` (root checkout)
  - Path: `/home/egallego/lean/verso-blueprint`
  - Status: keep
  - Notes: primary branch; currently includes dashboard/docs commit `b2f69acf`.

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
  - Decision: implemented

### Removed/Cleaned Up

- `feat/code-folding`
  - Decision implemented: removed worktree and deleted branch.
  - Pre-removal synthesis (uncommitted state):
    - 6-file patch, `+237/-15`
    - Added proof-folding plumbing around external Lean code rendering.
    - Added `verso.code.foldProofs` and propagated `foldProofs` through code config/rendering.
    - Added block-level proof-fold UI behavior in highlighting (`data-lean-proof-fold`, CSS/JS toggles).
    - Integrated proof-fold setup into blueprint style switcher/blueprint block rendering.
    - Affected files:
      - `src/verso/Verso/Code/Highlighted.lean`
      - `src/verso/Verso/Code/External.lean`
      - `src/verso/Verso/Code/External/Config.lean`
      - `src/verso-manual/VersoManual/ExternalLean.lean`
      - `src/verso-blueprint/VersoBlueprint/StyleSwitcher.lean`
      - `src/verso-blueprint/VersoBlueprint.lean`


### Branch-only items (no worktree)

- `bp+refactor`
  - Status: keep until reviewed (summary prepared)
  - Unique commits vs `bp`:
    - `70e7a656` `[blueprint] Initial support for informal objects with dependencies.`
      - large historical import-style change touching blueprint and broad Noperthedron tree
      - mostly superseded by current `bp` history
    - `ebed716d` `wip`
      - adds blueprint report-related artifacts/tests and modifies `VersoBlueprint/{Commands,Lean,Widget}.lean`
  - Decision: summary delivered; deletion pending explicit follow-up decision

- `backup/feat-lsp-folding-chain-pre-rebase`
  - Status: removed
  - Decision: implemented (branch deleted)

### Suggested cleanup order

1. Review/cherry-pick selected changes (if any) from `bp+refactor`.
2. Decide lifecycle for `feat/versoblueprint-critique` after planning phase.

## lsp-folding-chain

- Status: In progress, needs Emilio action
- Worktree: `/home/egallego/lean/verso-blueprint/.worktrees/lsp-folding-chain`
- Branch: `feat/lsp-folding-chain`
- Base branch: `bp` (`34e826ce`)
- Worktree git status: clean

### Completed Work

- Implemented chained `textDocument/foldingRange` handling for Verso integration.
- Added folding support for:
  - Verso sections and syntactic foldable blocks/lists.
  - Header fallback (when TOC-based section folds are unavailable).
  - Inline Lean blocks via info-tree folding metadata.
- Added/updated interactive test cases for folding behavior.
- Cleanup pass:
  - Removed accidental duplicate TOC info push.
  - Centralized inline Lean fold-range extraction helper in `Verso.Doc.Elab.Basic`.

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
### Pending Emilio Action

1. Review the two commits and decide merge strategy (keep as-is or squash).
2. Merge/cherry-pick to the target branch (bp/upstream path).
