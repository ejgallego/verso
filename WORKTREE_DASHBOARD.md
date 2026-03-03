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
  - HEAD: in progress (`git log --oneline -1`)
  - Status: active; command-path modularization in progress (dirty worktree, expected)
  - Base branch: `bp`
  - Key commits:
    - `873ce284` refactor: share preview lookup across graph and summary
    - `b0cb3f80` refactor: extract shared external node facts adapter
    - `b88ef562` refactor: move summary model and builder to lib module
    - `1b0d6902` refactor: extract graph part command module
    - `f6a5de69` refactor: split summary and bibliography command modules
    - `8aa11a90` refactor: extract shared hover preview rendering helpers
  - In-progress changes:
    - add `src/verso-blueprint/VersoBlueprint/Lib/PreviewSource.lean`
    - route traversal preview lookup in `Commands.lean` through `PreviewSource`
    - route widget preview acquisition/rendering in `Widget.lean` through `PreviewSource`
    - expose `renderPreviewBlocksHtml` in `PreviewRender.lean` for shared rendering path
    - update `doc/CommandsPathRefactorNotes.md` with new adapter checkpoint
  - Validation:
    - `lake build VersoBlueprint.Lib.PreviewLookup VersoBlueprint.PreviewRender VersoBlueprint.Lib.PreviewSource VersoBlueprint.Commands VersoBlueprint.Widget VersoBlueprint` passed on 2026-03-03
    - `lake exe noperthedron` passed on 2026-03-03 (warnings only)
  - Resume notes:
    - `cd /home/egallego/lean/verso-blueprint/.worktrees/commands-path-refactor`
    - `git status --short`
    - next target: continue renderer/data split in `Commands.lean` by extracting graph/summary renderer-heavy helpers

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
