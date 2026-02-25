# Project Notes

- Primary work areas:
  - `src/verso-blueprint`
  - `test-projects/Noperthedron` (core example project)
- Primary work branch, at root `bp`
- Main validation command:
  - `lake exe noperthedron`
- Validation output:
  - Generated website is written to `_out/`

## General recommendations:

- Avoid duplication
- One one single source of truth

## Important Information about Mathlib project

In the folder `test-projects/Noperthedron/` we have a mathlib project. This needs to be handled with care, due to dependencies. In particular, it will be hard to slice code examples there if they depend on mathlib, but of course YMMV.

When we create a worktree, it is possible that `lake` makes a choice to setup their artifacts there. Try always to copy the `.lake` directory from root when setting the worktree, and also run once `lake exe cache get` so we get a mathlib cache.

## Worktree Layout (Parallel Features + Sub-Agents)

- Keep the main checkout at:
  - `/home/egallego/lean/verso` (branch `main`)
- Put feature worktrees under:
  - `/home/egallego/lean/verso/.worktrees/<feature>`
- This keeps all worktrees under the same writable root, so Codex sub-agents can edit without sandbox path issues.
- When we need to preview the noperthedron artifact, and we are in a worktree, please launch a websever pointint out to the right `_out` directory under the worktree, generate a link I can click.

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
