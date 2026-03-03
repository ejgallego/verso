# Worktree Dashboard

Last updated: 2026-03-03 (commands module unification + css split)

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
    - unify split command modules into single files:
      - `src/verso-blueprint/VersoBlueprint/Commands/Graph.lean`
      - `src/verso-blueprint/VersoBlueprint/Commands/Summary.lean`
      - `src/verso-blueprint/VersoBlueprint/Commands/Bibliography.lean`
    - add `src/verso-blueprint/VersoBlueprint/Commands/Common.lean` for shared command JS
    - split CSS into:
      - `src/verso-blueprint/VersoBlueprint/Commands/graph.css`
      - `src/verso-blueprint/VersoBlueprint/Commands/summary.css`
      - `src/verso-blueprint/VersoBlueprint/Commands/bibliography.css`
    - move/remove legacy files:
      - remove `Commands/Show*.lean` and `Commands/Render*.lean`
      - remove legacy `src/verso-blueprint/VersoBlueprint/graph.css`
    - keep `src/verso-blueprint/VersoBlueprint/Commands.lean` as compatibility import layer
  - Validation:
    - `lake build VersoBlueprint.Commands.Common VersoBlueprint.Commands.Graph VersoBlueprint.Commands.Summary VersoBlueprint.Commands.Bibliography VersoBlueprint.Commands VersoBlueprint` passed on 2026-03-03
    - `lake env lean test-projects/Noperthedron/Contents.lean` passed on 2026-03-03
    - `lake exe noperthedron` passed on 2026-03-03 (warnings only)
  - Resume notes:
    - `cd /home/egallego/lean/verso-blueprint/.worktrees/commands-path-refactor`
    - `git status --short`
    - next target: decide whether to keep `Commands.lean` compatibility import permanently or switch call sites to direct `Commands/{Graph,Summary,Bibliography}` imports

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
