# Worktree Dashboard

Last updated: 2026-03-03 (`feat/versoblueprint-refactor` split implemented and validated)

## Active Worktrees

### `bp` (root checkout)

- Status: `active` (owner action: monitor follow-up builder-boundary work)
- Summary: integration baseline branch with recent commands-path and renderer refactors already validated for `noperthedron`.
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

### `feat/versoblueprint-refactor`

- Status: `validated` (owner action: review and commit split changes)
- Summary: extracted `VersoBlueprint.lean` informal logic into `Informal/Block` and `Informal/Uses`; kept root module as import aggregator.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/versoblueprint-refactor`
- Branch: `feat/versoblueprint-refactor`
- Base commit/branch:
  - rebased onto `bp` at `1b49078e`
- Key commit:
  - `1b49078e` dashboard: mark blueprint-dataflow-audit merged
- Validation status:
  - branch sync validated:
  - `git rebase bp` completed cleanly (no conflicts)
  - split validation passed:
  - `lake build VersoBlueprint`
  - `lake exe noperthedron`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/versoblueprint-refactor`
  - `git status --short`
  - inspect `src/verso-blueprint/VersoBlueprint.lean`
  - inspect `src/verso-blueprint/VersoBlueprint/Informal/Block.lean`
  - inspect `src/verso-blueprint/VersoBlueprint/Informal/Uses.lean`

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

- Merged `feat/blueprint-dataflow-audit` into `bp` (`9fcd85b3 -> c136a915`, fast-forward).
- Validation on branch before merge:
  - `lake build VersoBlueprint`
  - `lake env lean src/tests/Tests/BlueprintGraph.lean`
  - `lake exe noperthedron`
- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/blueprint-dataflow-audit`.
- Deleted branch: `feat/blueprint-dataflow-audit`.
- Merged `feat/docgen-direct-render` into `bp` (`460a78b3 -> 24974b73`, fast-forward).
- Validation on branch before merge:
  - `lake build VersoBlueprint`
  - `lake exe noperthedron`
- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/docgen-direct-render`.
- Deleted branch: `feat/docgen-direct-render`.
- Merged `feat/release-audit` into `bp` (`6dfda830 -> af04fe7b`, fast-forward).
- Validation on branch before merge:
  - `lake build VersoBlueprint`
  - `lake exe noperthedron`
- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/release-audit`.
- Deleted branch: `feat/release-audit`.
- Merged `feat/citation-reverse-details` into `bp` (`889a5814 -> c6f8a1b1`, fast-forward).
- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/citation-reverse-details`.
- Deleted branch: `feat/citation-reverse-details`.
- Merged `feat/external-def-display` into `bp` (`61a5f0a7 -> fd974295`, fast-forward).
- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/external-def-display`.
- Deleted branch: `feat/external-def-display`.
- Merged `feat/commands-path-refactor` into `bp` (`a3381ff3 -> 2d68ac9a`, fast-forward).
- Removed worktree: `/home/egallego/lean/verso-blueprint/.worktrees/commands-path-refactor`.
- Deleted branch: `feat/commands-path-refactor`.
