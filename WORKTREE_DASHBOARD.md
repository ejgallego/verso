# Worktree Dashboard

Last updated: 2026-03-03 (commands path refactor progress + validation)

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

- `feat/commands-path-refactor`
  - Path: `/home/egallego/lean/verso-blueprint/.worktrees/commands-path-refactor`
  - HEAD: `1b0d6902`
  - Status: active; command-path modularization in progress (dirty worktree, expected)
  - Base branch: `bp`
  - Key commits:
    - `873ce284` refactor: share preview lookup across graph and summary
    - `b0cb3f80` refactor: extract shared external node facts adapter
    - `b88ef562` refactor: move summary model and builder to lib module
    - `1b0d6902` refactor: extract graph part command module
  - In-progress changes:
    - add `src/verso-blueprint/VersoBlueprint/Commands/ShowSummary.lean`
    - add `src/verso-blueprint/VersoBlueprint/Commands/ShowBibliography.lean`
    - add `src/verso-blueprint/VersoBlueprint/Lib/HoverRender.lean`
    - move summary/bibliography part builders and command registrations out of `src/verso-blueprint/VersoBlueprint/Commands.lean`
    - route graph and summary preview markup through shared hover-render helpers
    - wire top-level imports in `src/verso-blueprint/VersoBlueprint.lean`
    - update `doc/CommandsPathRefactorNotes.md` with checkpoint log
  - Validation:
    - `lake build VersoBlueprint.Lib.HoverRender VersoBlueprint.Commands VersoBlueprint.Commands.ShowGraph VersoBlueprint.Commands.ShowSummary VersoBlueprint.Commands.ShowBibliography VersoBlueprint` passed on 2026-03-03
    - `lake exe noperthedron` passed on 2026-03-03 (warnings only)
  - Resume notes:
    - `cd /home/egallego/lean/verso-blueprint/.worktrees/commands-path-refactor`
    - `git status --short`
    - next target: extend hover-render API to widget path and continue renderer/data split in `Commands.lean`

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
