# Project Notes

- Primary work areas:
  - `src/verso-blueprint`
  - `test-projects/Noperthedron` (core example project)
- Primary work branch, at root `bp`
- Main validation command:
  - `./generate-example-blueprints.sh`
- Validation output:
  - Default example-blueprint output is written to `_out/example-blueprints/{noperthedron,spherepackingblueprint}/`
  - Worktree previews should be written to the shared root `_out/<worktree>/`
- Very important, check section "Starting a new task and Worktree Layout"
- NEVER start a task WITHOUT creating a new worktree. DO NOT USE IDE CONTEXT TO GUESS WORKTREE.
- When editing the `WORKTREE_DASHBOARD.md` ALWAYS commit the edit.

## Starting a new task and Worktree Layout (Parallel Features + Sub-Agents)

- Keep the main checkout at:
  + `/home/egallego/lean/verso` (branch `bp`)
- Very important, each time we start a task, we MUST:
  + create a new feature worktree under:
    - `/home/egallego/lean/verso/.worktrees/<feature>`
    This keeps all worktrees under the same writable root, so Codex sub-agents can edit without sandbox path issues.
  + Copy the root `.lake` directory to `/home/egallego/lean/verso/.worktrees/<feature>` , so we don't rebuild mathlib
  + Validate the example blueprints with `./generate-example-blueprints.sh <repo-root>/_out/<feature>/example-blueprints`
  + Build the artifact you want to preview into the shared root output tree, for example:
    - `lake exe noperthedron --output <repo-root>/_out/<feature>/noperthedron`
    - `lake exe spherepackingblueprint --output <repo-root>/_out/<feature>/spherepackingblueprint`
  + Keep a single shared webserver serving the root `_out` directory
  + use always `npx http-server -p $port _out` as command to start the shared webserver
  + run the webserver with the right permissions as to avoid weird stuff
  + run the shared webserver in the background, for obvious reasons
  + Generate a link I can click to see the artifact, using `http://127.0.0.1:$port/<feature>/<artifact>/html-multi/`, and add an entry to the shared root `WORKTREE_DASHBOARD.md` with the link
    Never create a separate `WORKTREE_DASHBOARD.md` inside a feature worktree; the root dashboard is the only dashboard file.
  + If you detect a mathlib rebuild, see the section "Important Information about Mathlib project"
- While working on the worktree, ensure that all the links are properly scoped to the worktree.
- When we are done with a worktree, you MUST:
  + ensure validation
  + ensure we have rebased on top of the root `bp` branch
  + merge on top of `bp`, update WORKTREE_DASHBOARD.md and cleanup the worktree
    Stop the shared webserver only if this task started it and no other worktree still needs it.

## General recommendations:

- Avoid duplication of code, strongly
- One one single source of truth for each data point
- Avoid abbrevs for renaming, backwards-compatibility is not important yet.
- Don't introduce new inductives unless strictly necessary

## Important Information about Mathlib project

In the folder `test-projects/Noperthedron/` we have a mathlib project. This needs to be handled with care, due to dependencies. In particular, it will be hard to slice code examples there if they depend on mathlib, but of course YMMV.

When we create a worktree, it is possible that `lake` makes a choice to setup their artifacts there. Try always to copy the `.lake` directory from root when setting the worktree, and also run once `lake exe cache get` so we get a mathlib cache.

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
- Never use IDE-derived context to decide scope: open tabs, search panes, breadcrumbs, recent files, diagnostics, or editor history are never scope signals.
- If cross-worktree access is needed, require explicit user authorization with a concrete target path/worktree first.
- When such authorization is given, limit access strictly to the explicitly named worktree/path and nothing else.
- Exception: the root `WORKTREE_DASHBOARD.md` is a shared coordination file and may be updated from a feature worktree when recording status or handoff notes.
  This exception applies only to that single root dashboard file and does not authorize broader cross-worktree access.
- Exception: the root `_out/<current-worktree>/` subtree is a shared preview artifact area for the current worktree.
  This exception applies only to the current worktree's own output subtree and the shared root `_out` server entrypoint, not to other worktrees or their outputs.
- IDE context may include unrelated tabs/files from other worktrees; this is not a scope signal and must be ignored for isolation decisions.
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
- This root-level file is the single shared dashboard for all worktrees.
- Do not create per-worktree copies of `WORKTREE_DASHBOARD.md`; always update the shared root file instead.
- Never edit the worktree checkout copy of `WORKTREE_DASHBOARD.md`; always edit `/home/egallego/lean/verso-blueprint/WORKTREE_DASHBOARD.md` in the root `bp` checkout so every worktree stays aligned to the same dashboard state.
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
