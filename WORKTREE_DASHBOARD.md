# Worktree Dashboard

Last updated: 2026-03-03 (citation reverse-metadata + Noperthedron advanced cite migration validated)

## Active Worktrees

### `bp` (root checkout)

- Status: `active` (owner action: monitor follow-up builder-boundary work)
- Path: `/home/egallego/lean/verso-blueprint`
- Branch: `bp`
- Base commit/branch:
  - local integration branch
- Key commit:
  - `fd974295` refactor: extract informal code renderer and refresh roadmap
- Validation status:
  - commands-path validation passed before merge:
  - `lake build VersoBlueprint.Commands.Common VersoBlueprint.Commands.Graph VersoBlueprint.Commands.Summary VersoBlueprint.Commands.Bibliography VersoBlueprint`
  - `lake exe noperthedron`
- Resume commands/notes:
  - `git status --short`
  - `git log --oneline -1`

### `feat/citation-reverse-details`

- Status: `ready-for-review` (owner action: review diff and commit/cherry-pick into `bp`)
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/citation-reverse-details`
- Branch: `feat/citation-reverse-details`
- Base commit/branch:
  - branched from `bp` at `889a5814`
- Key commit:
  - working tree (not committed): bibliography reverse-citation metadata display + migration of Noperthedron chapter cites to structured `kind`/`index`
- Validation status:
  - `lake build VersoBlueprint` (pass; existing doc warnings only)
  - `lake exe noperthedron` (pass; existing project warnings only)
  - output check: `_out/html-multi/Blueprint-Bibliography/index.html` now includes human-readable reverse-citation details (e.g. `Cites Lemma 18`, `Cites Section 4.2`, `Cites Corollary 50`)
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/citation-reverse-details`
  - `git status --short`
  - `git diff -- src/verso-blueprint/VersoBlueprint/Cite.lean src/verso-blueprint/VersoBlueprint/Commands/Bibliography.lean src/verso-blueprint/VersoBlueprint/Commands/bibliography.css test-projects/Noperthedron/Chapters/Bounding.lean test-projects/Noperthedron/Chapters/GlobalTheorem.lean test-projects/Noperthedron/Chapters/LocalTheorem.lean test-projects/Noperthedron/Chapters/Rational.lean`

### `feat/docgen-direct-render`

- Status: `active` (owner action: finish or checkpoint WIP; branch is behind `bp`)
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/docgen-direct-render`
- Branch: `feat/docgen-direct-render`
- Base commit/branch:
  - merge-base with `bp`: `a3381ff3` (`11` behind / `0` ahead)
- Key commit:
  - `a3381ff3` docs: consolidate commands path refactor notes
- Validation status:
  - not rerun in this update
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/docgen-direct-render`
  - `git status --short`
  - rebase or merge `bp` after checkpointing local edits

### `feat/external-def-display`

- Status: `merged` (owner action: optional worktree cleanup when no longer needed)
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/external-def-display`
- Branch: `feat/external-def-display`
- Base commit/branch:
  - aligned with `bp` at `2d68ac9a`
- Key commit:
  - `fd974295` refactor: extract informal code renderer and refresh roadmap
- Validation status:
  - `lake build VersoBlueprint` (pass)
  - `lake exe noperthedron` (pass, warnings only)
  - `python3 test-projects/Noperthedron/check_blueprint_code_panels.py` (known baseline fail: missing `bp_external_status_sorry` in `The-Local-Theorem`)
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/external-def-display`
  - `git status --short`

### `feat/lsp-folding-chain`

- Status: `active` (owner action: rebase before integration)
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

### `feat/sphere-packing-blueprint`

- Status: `blocked` (owner action: checkpoint dirty edits, then rebase)
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/sphere-packing-blueprint`
- Branch: `feat/sphere-packing-blueprint`
- Base commit/branch:
  - merge-base with `bp`: `887d3300` (`19` behind / `2` ahead)
- Key commit:
  - `8120a6e5` sphere-packing: add temporary external-name workarounds
- Validation status:
  - not rerun in this update
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/sphere-packing-blueprint`
  - `git status --short`
  - commit/stash local chapter changes before rebasing on `bp`

## Recently Completed

- Merged `feat/external-def-display` into `bp` (`61a5f0a7 -> fd974295`, fast-forward).
- Merged `feat/commands-path-refactor` into `bp` (`a3381ff3 -> 2d68ac9a`, fast-forward).
- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/commands-path-refactor`.
- Deleted branch: `feat/commands-path-refactor`.
