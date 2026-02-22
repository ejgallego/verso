# Project Notes

- Primary work areas:
  - `src/verso-blueprint`
  - `test-projects/Noperthedron` (core example project)
- Main validation command:
  - `lake exe noperthedron`
- Validation output:
  - Generated website is written to `_out/`

## Worktree Layout (Parallel Features + Sub-Agents)

- Keep the main checkout at:
  - `/home/egallego/lean/verso` (branch `main`)
- Put feature worktrees under:
  - `/home/egallego/lean/verso/.worktrees/<feature>`
- This keeps all worktrees under the same writable root, so Codex sub-agents can edit without sandbox path issues.

### One-time setup

- From repo root:
  - `mkdir -p .worktrees`
  - `printf ".worktrees/\n" >> .git/info/exclude`
  - `git fetch origin`

### Create feature worktrees

- Example commands:
  - `git worktree add .worktrees/feature-search -b feat/feature-search origin/main`
  - `git worktree add .worktrees/feature-graph -b feat/feature-graph origin/main`

### Sub-agent rule

- Run each sub-agent from the feature worktree it owns (its CWD must be that worktree path).
- Do not run multiple sub-agents in the same worktree simultaneously.
- Keep shared fixes in a separate worktree/branch and merge/cherry-pick as needed.

### Daily operations

- List worktrees:
  - `git worktree list`
- Remove after merge:
  - `git worktree remove .worktrees/<feature>`
  - `git branch -d feat/<feature>`
