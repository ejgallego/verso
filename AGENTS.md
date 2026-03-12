# Project Notes

- CRITICAL INVARIANT: the coordination branch `agents.md` is an overlay branch only.
- CRITICAL INVARIANT: `agents.md` must track `upstream/main` and stay minimal (normally one small commit ahead).
- CRITICAL INVARIANT: overlay commits on `agents.md` may modify only `AGENTS.md`, `DASHBOARD.md`, and `COMMIT_CONVENTION.md`.
- CRITICAL INVARIANT: feature code changes must never be committed on `agents.md`; use feature branches/worktrees.
- If `agents.md` drifts from this policy, stop and repair branch state before any other work.
- Main validation commands for feature branches: `lake build` and `lake test`.

## Overlay Workflow

- Sync base: `git fetch upstream main && git rebase upstream/main`.
- Keep only overlay files on `agents.md`: `AGENTS.md`, `DASHBOARD.md`, `COMMIT_CONVENTION.md`.
- Create feature branches from `agents.md`, but do feature commits only in feature worktrees.
- Before pushing `agents.md`, verify scope:
  - `git diff --name-only upstream/main..HEAD` should list only `AGENTS.md`, `DASHBOARD.md`, and `COMMIT_CONVENTION.md`.
  - `git rev-list --count upstream/main..HEAD` should be `1` (consolidate overlay updates before push).

## Task Queue Convention

- CRITICAL INVARIANT: task order in `DASHBOARD.md` is an execution queue, not a suggestion.
- Default execution policy: take the first task in `Tasks Ongoing`.
- Only start a task from `Tasks Planned` when explicitly directed by the user/manager.
- Reordering queue entries is a deliberate action and should be documented in commit notes or task notes.
- CRITICAL INVARIANT: the `Decision:` field in `DASHBOARD.md` is user-controlled next-step input.
- CRITICAL INVARIANT: `Decision: pending` means the task is blocked and not a candidate for action.
- Agents must remove `Decision:` from a task when they start executing it.
- Special status `locked` means an agent is currently working that task; do not pick it for parallel work.

## Commit + PR Convention

- Source of truth for commit/PR message format: `COMMIT_CONVENTION.md`.
- Commit subject must remain human-friendly while still following `<type>: <subject>`.
- Commit body should be a natural-language explanation that follows the convention constraints.
- For `feat`/`fix`, enforce the convention requirements around changelog labels and body prefix.
- If a feature branch has exactly one commit, derive PR title/body directly from that commit message.
- If a feature branch has more than one commit, require explicit `PR Title` and `PR Body` fields in `DASHBOARD.md` before opening the PR.

## Validation Convention

- Standard validation for implemented feature work is `lake build` and `lake test` unless a task specifies otherwise.
- In `DASHBOARD.md` planned tasks, omit validation details by default.
- Add validation details in planned tasks only when non-standard checks are required.

## Dashboard Task Format

- `DASHBOARD.md` task entries must follow the current list format and field names exactly.
- Planned task entries must include at least:
  - task title line
  - `Scope`
  - `Observation`
  - `Impact`
  - `Proposed fix`
  - `Expected effort`
  - `Status`
  - `Decision`
- Ongoing task entries must include at least:
  - task title line
  - `Path`
  - `Status`
  - `Decision`
  - `Summary`
  - `Notes`
- Ongoing entries may additionally include:
  - `PR`
  - `PR Title`
  - `PR Body`
  - `Ahead/Behind vs upstream/main`
- `Decision` is user-managed; agents remove it when actively executing that task.

## Worktree Layout (Parallel Features + Sub-Agents)

- Keep the coordination checkout at:
  - `/home/egallego/lean/verso` (branch `agents.md`)
- Put feature worktrees under:
  - `/home/egallego/lean/verso/.worktrees/<feature>`
- This keeps all worktrees under the same writable root, so Codex sub-agents can edit without sandbox path issues.

## VS Code + Path References

- Open VS Code in the worktree you are actively editing, not only in the coordination checkout.
- Treat the active worktree directory as the project root for commands, searches, and file links.
- When referring to files in another worktree, include the `.worktrees/<feature>/...` prefix.

## Creating Feature Worktrees

- Example commands:
  - `git worktree add .worktrees/feature-search -b feat/feature-search agents.md`
  - `git worktree add .worktrees/feature-graph -b feat/feature-graph agents.md`
- For existing local branches without a worktree, create one under `.worktrees/` immediately.
- Policy target: one branch ↔ one worktree for all active local branches.

## Sub-Agent Rules

- Run each sub-agent from the feature worktree it owns.
- Do not run multiple sub-agents in the same worktree simultaneously.
- Keep shared fixes in a dedicated branch/worktree and merge or cherry-pick as needed.
- Update `DASHBOARD.md` whenever branch/worktree state changes (new worktree, PR opened, branch status changed, cleanup needed).
