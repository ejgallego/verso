# Worktree Dashboard

Last updated: 2026-03-05 (`feat/external-code-visual-refresh-20260305` ready for review with three incremental commits)

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

### `feat/tex-macro-import-20260305`

- Status: `created` (owner action: implement importable TeX prelude registry and per-math injection refactor)
- Summary: move blueprint math prelude handling from transient document blocks and global KaTeX patching onto importable Lean commands plus per-node HTML math payloads.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/tex-macro-import-20260305-wt`
- Branch: `feat/tex-macro-import-20260305`
- Base commit/branch:
  - merge-base with `bp`: `0c18436e` (`0` behind / `0` ahead)
- Key commit:
  - none yet
- Validation status:
  - worktree created; validation pending
- Preview link:
  - pending
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/tex-macro-import-20260305-wt`
  - `git status --short`
  - `lake build`
  - `lake exe noperthedron`

### `feat/external-code-visual-refresh-20260305`

- Status: `ready-for-review` (owner action: review each incremental external-code refresh commit)
- Summary: implementation worktree for the external-code visual redesign, staged as three reviewable commits.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/external-code-visual-refresh-20260305`
- Branch: `feat/external-code-visual-refresh-20260305`
- Base commit/branch:
  - merge-base with `bp`: `0c18436e` (`0` behind / `0` ahead)
- Key commit:
  - `9ef4a982` style(external-code): improve panel readability and mobile spacing
  - `1d3f306d` feat(external-code): add native headers and summary badges
  - `3bb49a05` refactor(external-code): flatten rendered declaration wrapper
- Validation status:
  - `lake exe cache get`
  - `lake exe noperthedron` (warnings only; no errors)
  - `python3 test-projects/Noperthedron/check_blueprint_code_panels.py`
- Preview link:
  - `http://127.0.0.1:8147`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/external-code-visual-refresh-20260305`
  - `git log --oneline --decorate -3`
  - `lake exe noperthedron`
  - server session: `68315`

### `feat/verso-block-incremental-snapshots-20260305`

- Status: `validated` (owner action: review the prototype and decide whether to add a direct incremental regression test before committing the feature branch)
- Summary: prototype now threads block-local snapshot state through Verso block elaboration for embedded Lean code blocks in both manual and blueprint paths.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/verso-block-incremental-snapshots-20260305`
- Branch: `feat/verso-block-incremental-snapshots-20260305`
- Base commit/branch:
  - merge-base with `bp`: `af911f1e` (`2` behind / `0` ahead)
- Key commit:
  - none yet (prototype changes currently uncommitted in the worktree)
- Validation status:
  - `lake exe cache get`
  - `lake exe noperthedron` (passed; warnings only)
  - `lake build` reaches the touched Verso/manual/blueprint targets; full build still hits an unrelated `clang` crash in `test-projects/website-literate`
- Preview link:
  - `http://127.0.0.1:8146`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/verso-block-incremental-snapshots-20260305`
  - `lake build Verso.Doc.Concrete VersoManual.InlineLean VersoBlueprint.Lean`
  - `lake exe noperthedron`
  - server session: `52605`
  - key files: `src/verso/Verso/Doc/Elab/Monad.lean`, `src/verso/Verso/Doc/Concrete.lean`, `src/verso-manual/VersoManual/InlineLean.lean`, `src/verso-blueprint/VersoBlueprint/Lean.lean`

### `feat/inline-command-codeblock-first-try`

- Status: `active` (owner action: review validated prototype and decide whether to harden or replace it)
- Summary: streamed nested-snapshot prototype now hooks a real child `snap?` into fenced Lean blocks and replaces the prior ad hoc prefix cache in `VersoBlueprint.Lean`.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/inline-command-codeblock-first-try`
- Branch: `feat/inline-command-codeblock-first-try`
- Base commit/branch:
  - merge-base with `bp`: `054b0c02` (`3` behind / `4` ahead, including dashboard-only checkpoint)
- Key commit:
  - `ce6ae3a9` docs(dashboard): record nested snapshot prototype validation
- Validation status:
  - `lake exe cache get`
  - `lake build VersoBlueprint`
  - `lake exe noperthedron` (warnings only; no errors)
  - note: prototype code changes are still uncommitted in the worktree for review
- Preview link:
  - `http://127.0.0.1:8141`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/inline-command-codeblock-first-try`
  - `git status --short`
  - inspect `src/verso/Verso/Doc/Elab/Incremental.lean`, `src/verso/Verso/Doc/Concrete.lean`, and `src/verso-blueprint/VersoBlueprint/Lean.lean`

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
