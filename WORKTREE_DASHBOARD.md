# Worktree Dashboard

Last updated: 2026-03-03 (bp dependency/profiling consolidation + validation)

## Inventory and Recommendation

### Active worktrees

- `bp` (root checkout)
  - Path: `/home/egallego/lean/verso-blueprint`
  - HEAD: `807771d0`
  - Status: primary branch; dependency/profiling maintenance commit prepared locally
  - Notes:
    - contains merged critique plan at `doc/VersoBlueprintRefactorPlan.md`
    - non-branch-local untracked dirs present (`.worktrees/`, `test-projects/Noperthedron/tex-src/`, `test-projects/Sphere-Packing-Lean/`)
    - consolidated dependency bump to mathlib `v4.29.0-rc3` in `lakefile.lean` + `lake-manifest.json`
    - updated `verso.blueprint.profile` option read path in `src/verso-blueprint/VersoBlueprint/Profiling.lean`
    - validation: `lake exe noperthedron` passed on 2026-03-03 (warnings only)

- `feat/lsp-folding-chain`
  - Path: `/home/egallego/lean/verso-blueprint/.worktrees/lsp-folding-chain`
  - HEAD: `4cafd289`
  - Status: clean worktree
  - Divergence vs `bp`: `66` behind / `28` ahead
  - Recommendation: rebase onto current `bp` before next integration step

- `feat/sphere-packing-blueprint`
  - Path: `/home/egallego/lean/verso-blueprint/.worktrees/sphere-packing-blueprint`
  - HEAD: `8120a6e5`
  - Status: dirty worktree (multiple chapter edits + `tmp/` untracked)
  - Divergence vs `bp`: `25` behind / `2` ahead
  - Recommendation: checkpoint current edits, then rebase on `bp` to reduce drift

### Recently cleaned up

- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/versoblueprint-critique`
- Deleted branch: `feat/versoblueprint-critique`
