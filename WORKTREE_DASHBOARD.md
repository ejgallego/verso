# Worktree Dashboard

Last updated: 2026-03-06 (cleaned up `feat/inline-command-codeblock-first-try` without merge)

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
  - `lake exe noperthedron`
- Resume commands/notes:
  - `git status --short`
  - `git log --oneline -1`

### `feat/graph-review-20260306`

- Status: `active` (owner action: review graph implementation findings and decide which refactors to prioritize)
- Summary: analysis-only review worktree for blueprint graph architecture, semantics, and group-view presentation.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/graph-review-20260306`
- Branch: `feat/graph-review-20260306`
- Base commit/branch:
  - merge-base with `bp`: `ef43594e` (`0` behind / `0` ahead)
- Key commit:
  - none yet (analysis-only review branch)
- Validation status:
  - `lake exe cache get`
  - `lake exe noperthedron --output /home/egallego/lean/verso-blueprint/_out/graph-review-20260306` (passed; existing Noperthedron warnings only)
- Preview link:
  - `http://127.0.0.1:8150/graph-review-20260306/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/graph-review-20260306`
  - `git status --short`
  - inspect `src/verso-blueprint/VersoBlueprint/Graph.lean`, `src/verso-blueprint/VersoBlueprint/Commands/Graph.lean`, `src/verso-blueprint/VersoBlueprint/Commands/graph.css`

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

### `feat/sphere-packing-blueprint`

- Status: `blocked` (owner action: checkpoint dirty edits, then rebase)
- Summary: sphere-packing blueprint branch is blocked by uncheckpointed local edits and temporary compatibility workarounds.
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

- Closed `feat/inline-command-codeblock-first-try` without merge (experiment discarded at user request).
- Validation before discard:
  - `lake exe cache get`
  - `lake build VersoBlueprint`
  - `lake exe noperthedron` (passed; warnings only)
- Discarded local prototype changes in:
  - `src/verso/Verso/Doc/Elab/Incremental.lean`
  - `src/verso/Verso/Doc/Elab/Monad.lean`
  - `src/verso/Verso/Doc/Concrete.lean`
  - `src/verso/Verso/Doc/Concrete/InlineString.lean`
  - `src/verso-manual/VersoManual/Literate.lean`
  - `src/verso-blueprint/VersoBlueprint/Lean.lean`
- Confirmed preview server `http://127.0.0.1:8141/` was not running at cleanup time.
- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/inline-command-codeblock-first-try`.
- Deleted branch: `feat/inline-command-codeblock-first-try`.

- Closed `feat/verso-block-incremental-snapshots-20260305` without merge (experiment discarded; uncommitted prototype changes were removed with the worktree).
- Validation before discard:
  - `lake exe cache get`
  - `lake build Verso.Doc.Concrete VersoManual.InlineLean VersoBlueprint.Lean`
  - `lake exe noperthedron` (passed; warnings only)
  - note: full `lake build` in that worktree still hit the unrelated `test-projects/website-literate` clang crash
- Confirmed preview server `http://127.0.0.1:8146/` was not running at cleanup time.
- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/verso-block-incremental-snapshots-20260305`.
- Deleted branch: `feat/verso-block-incremental-snapshots-20260305`.
