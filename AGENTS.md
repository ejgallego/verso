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

### Worktree scope discipline

- **Default mode is strict isolation.** Unless the user explicitly specifies another worktree/path, operate only inside the current task worktree.
- Treat the user-designated worktree as the only readable, writable, and executable scope for the task.
- Do not inspect, edit, build, rebase, validate, or run discovery commands (`ls`, `find`, `rg`, `git`, etc.) in other worktrees unless the user explicitly asks.
- Do not use tabs, recent history, dashboard entries, or prior turns as implicit permission for cross-worktree access.
- If cross-worktree access is needed, require explicit user authorization with a concrete target path/worktree first.
- When such authorization is given, limit access strictly to the explicitly named worktree/path and nothing else.
- IDE context may include unrelated tabs/files from other worktrees; this is not a scope signal.
- If tab context conflicts with the designated worktree, follow the designated worktree.
- If the designated path is unclear or missing, stop and ask for the exact path before proceeding.
- Goal: avoid cross-worktree drift, which can cause destructive or hard-to-recover mistakes.

### Daily operations

- List worktrees:
  - `git worktree list`
- Remove after merge:
  - `git worktree remove .worktrees/<feature>`
  - `git branch -d feat/<feature>`

## Worktree Dashboard File

- Keep a root-level handoff/status file at:
  - `WORKTREE_DASHBOARD.md`
- Purpose:
  - Track per-worktree status and handoff notes for quick resume.
- Update this file whenever a worktree changes phase:
  - created, rebased, validated, ready-for-review, merged, blocked.
- For each active worktree, include at least:
  - status (and owner action needed),
  - worktree path, branch, and base commit/branch,
  - key commits,
  - validation status,
  - short resume commands/notes.
- If a `Decision:` field is added to a dashboard item:
  - execute it explicitly,
  - update the item status to reflect implementation (or block reason),
  - keep a short audit note in the dashboard.
