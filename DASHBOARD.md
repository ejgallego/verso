# DASHBOARD

## Operating Notes

- This dashboard is the shared coordination surface for the manager agent and human.
- Keep one entry per worktree and one worktree per active local branch.
- Branch/worktree coverage is complete right now: all local branches have a worktree.
- Task order is a strict queue: execute from top to bottom.
- Default policy: always attack the first task in `Tasks Ongoing`.
- Exception: start from `Tasks Planned` only when the user/manager explicitly directs it.
- For `Tasks Planned`, omit validation details unless non-standard validation is needed.
- `Decision:` is a special user-controlled field that sets next step for a task.
- `Decision: pending` means the task is blocked and not a candidate for action.
- When an agent starts a task, it removes that task's `Decision:` field.
- Special status `locked` means an agent is actively working on that task.
- Commit and PR messages must follow `COMMIT_CONVENTION.md`.
- If a branch has one commit, PR title/body are derived from the commit message.
- If a branch has multiple commits, the corresponding task entry must include explicit `PR Title` and `PR Body` before PR submission.
- Status tags:
  - `needs: rebase`: branch has an open PR and should be rebased/synced with `upstream/main`.
  - `needs: progress`: no open PR yet; work is still local/draft.
  - `needs: decision`: non-standard state (coordination branch, detached worktree, or baseline mirror).
  - `needs review from human`: branch work is ready for human review/approval.
  - `pending on human action`: task is paused until explicit human follow-up.
  - `special`: management/baseline worktree entry (not an implementation task).
  - `locked`: task is currently being executed by an agent.
- PR mapping below uses the last successful GitHub query from this session. Re-run `gh api repos/leanprover/verso/pulls --paginate` when network is available.

## Task Entry Format

- Planned task format:
```markdown
- [ ] `<task title>`
  - Scope: `<where change applies>`
  - Observation: `<what we saw>`
  - Impact: `<why it matters>`
  - Proposed fix: `<intended change>`
  - Expected effort: `<small|medium|large + note>`
  - Status: `<needs: ...>`
  - Decision: `<user-provided next step>`
```

- Ongoing task format:
```markdown
- [ ] `<branch or task>`
  - Path: `<absolute worktree path>`
  - Status: `keep (<needs: ...>)` or `keep (pending on human action)` or `special` or `locked`
  - Decision: `<user-provided next step>`   # `pending` blocks action; removed by agent when task is being executed
  - PR Title: `<required before PR submission when branch has >1 commit>`
  - PR Body: `<required before PR submission when branch has >1 commit>`
  - PR: `<#id + url>` or `none` or `n/a`
  - Ahead/Behind vs `upstream/main`: `+X/-Y`   # optional
  - Summary: `<one-line branch summary>`
  - Notes: `<state and special context>`
```

## Tasks Planned (Not Started)

- [ ] `Concrete.lean` task A: remove duplicate genre resolution in `verso` term elaboration.
  - Scope: `/home/egallego/lean/verso/src/verso/Verso/Doc/Concrete.lean` around the `elab_rules : term` for `verso`.
  - Observation: `findGenreTm` is called twice on the same explicit genre path.
  - Impact: redundant resolution/info work and avoidable noise in elaboration traces.
  - Proposed fix: keep a single `findGenreTm` call in the `some g` branch and remove the extra pre-pass.
  - Expected effort: small (about 5 lines, low risk).
  - Status: `needs: progress`.
  - Decision: pending (set by user)

- [ ] `Concrete.lean` task B: make incremental `#doc` ref-info emission linear.
  - Scope: `/home/egallego/lean/verso/src/verso/Verso/Doc/Concrete.lean` in `runVersoBlock`/`saveRefsInEnv` and environment threading.
  - Observation: incremental mode re-pushes all ref custom info each block; current behavior trends quadratic in top-level block count.
  - Impact: unnecessary elaboration overhead for larger docs and noisier info trees.
  - Proposed fix: track emitted ref progress in `DocElabEnvironment` and push only newly added def/use syntax per ref key.
  - Expected effort: medium (state extension + delta computation + regression checks).
  - Status: `needs: progress`.
  - Decision: pending (set by user)

## Tasks Ongoing (Branch + Worktree)

### Open PRs (`needs: rebase`)

- [ ] `feat/folding-doc-start-range`
  - Path: `/home/egallego/lean/verso/.worktrees/folding-doc-start-range`
  - Status: keep (`needs review from human`)
  - Decision: pending (set by user)
  - PR: #771 <https://github.com/leanprover/verso/pull/771>
  - Ahead/Behind vs `upstream/main`: `+2/-0`
  - Summary: `fix: preserve #docs syntax range and expand LSP regressions`
  - Notes: queue-priority action executed; unlocked and awaiting human review.
- [ ] `feat/ci-userguide-deploy`
  - Path: `/home/egallego/lean/verso/.worktrees/ci-userguide-deploy`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #765 <https://github.com/leanprover/verso/pull/765>
  - Ahead/Behind vs `upstream/main`: `+1/-2`
  - Summary: `ci: gate PR manual preview on user guide changes`
  - Notes: clean worktree.
- [ ] `ci-win`
  - Path: `/home/egallego/lean/verso/.worktrees/ci-win`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #724 <https://github.com/leanprover/verso/pull/724>
  - Ahead/Behind vs `upstream/main`: `+6/-7`
  - Summary: `wip`
  - Notes: clean worktree.
- [ ] `feature/dark-mode-support`
  - Path: `/home/egallego/lean/verso/.worktrees/dark-mode-support`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #676 <https://github.com/leanprover/verso/pull/676>
  - Ahead/Behind vs `upstream/main`: `+2/-71`
  - Summary: `style: apply prettier formatting to theme-toggle.js`
  - Notes: clean worktree.
- [ ] `codex/issue-762-inline-role`
  - Path: `/home/egallego/lean/verso/.worktrees/issue-762-inline-role`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #766 <https://github.com/leanprover/verso/pull/766>
  - Ahead/Behind vs `upstream/main`: `+1/-0`
  - Summary: `fix: align inline Lean role names with Manual`
  - Notes: clean worktree.
- [ ] `parse_start`
  - Path: `/home/egallego/lean/verso/.worktrees/parse_start`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #750 <https://github.com/leanprover/verso/pull/750>
  - Ahead/Behind vs `upstream/main`: `+4/-7`
  - Summary: `fix for VersoManual.imports`
  - Notes: dirty worktree.
- [ ] `remove_warns`
  - Path: `/home/egallego/lean/verso/.worktrees/remove-warns`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #749 <https://github.com/leanprover/verso/pull/749>
  - Ahead/Behind vs `upstream/main`: `+1/-7`
  - Summary: `chore: remove unused variables warning showing up in build`
  - Notes: clean worktree.
- [ ] `research/role-fallback`
  - Path: `/home/egallego/lean/verso/.worktrees/role-fallback-research`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #763 <https://github.com/leanprover/verso/pull/763>
  - Ahead/Behind vs `upstream/main`: `+3/-3`
  - Summary: `refine: cap unknown-role fallback hints to 5 closest entries`
  - Notes: clean worktree.

### No Open PR Yet (`needs: progress`)

- [ ] `feat/issue-135-multilean`
  - Path: `/home/egallego/lean/verso/.worktrees/issue-135-multilean`
  - Status: keep (`needs review from human`)
  - Decision: human review (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+4/-0`
  - Summary: `add :::multilean with synthetic combined elaboration and interleaved explanation rendering`
  - Notes: branch pushed to `ejgallego/verso:feat/issue-135-multilean`; local implementation includes the shared inline-lean elaboration refactor, multilean block renderer/splitting helpers, explanation styling, and the follow-up fix preserving indentation for split proof steps. Validation passed with `lake build` and `lake test`.

- [ ] `feat/doc-elab-build-mode`
  - Path: `/home/egallego/lean/verso/.worktrees/doc-elab-build-mode`
  - Status: keep (`needs review from human`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+1/-0`
  - Summary: `thread batch vs interactive document elaboration mode into DocElabContext`
  - Notes: user-directed task completed locally with build-mode plumbing for `#doc`/`#docs`, batch and LSP regression coverage, and successful `lake build` plus `lake test`.
- [ ] `perf/manual-bench-infra`
  - Path: `/home/egallego/lean/verso/.worktrees/manual-bench-infra`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+12/-0`
  - Summary: `benchmark harness, downstream result snapshot, and manual-harness repair work`
  - Notes: downstream `reference-manual` benchmark is valid and shows a median speedup; manual benchmark is being reworked around fresh snapshots plus baseline-vs-single-commit comparisons and is still blocked on `subverso` helper compatibility in the workload path.
- [ ] `perf/manual-elab-review`
  - Path: `/home/egallego/lean/verso/.worktrees/manual-elab-review`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+7/-0`
  - Summary: `perf-only stack for manual elaboration changes plus local cleanup commit`
  - Notes: rebased cleanly onto latest `upstream/main`; still the code branch we are measuring, with benchmark/docs kept on the infra branch.
- [ ] `perf/manual-genre-scaling`
  - Path: `/home/egallego/lean/verso/.worktrees/manual-genre-scaling`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+12/-0`
  - Summary: `research branch with profiling hooks and exploratory manual perf history`
  - Notes: instrumentation-heavy branch for profiling Verso/VersoManual behavior; attempted rebase hit a real conflict in `src/verso-manual/VersoManual/InlineLean.lean`, so it was left unrebased rather than merged ad hoc.
- [ ] `feat/doc-html-preview`
  - Path: `/home/egallego/lean/verso/.worktrees/doc-html-preview`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+10/-3`
  - Summary: `feat(doc-preview): add inline hover docs support in preview widget`
  - Notes: dirty worktree.
- [ ] `refactor_syntaxutils`
  - Path: `/home/egallego/lean/verso/.worktrees/refactor-syntaxutils`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+1/-9`
  - Summary: `refactor: use Verso's runParserCategory function for string parsing`
  - Notes: clean worktree.
- [ ] `tex-widget`
  - Path: `/home/egallego/lean/verso/.worktrees/tex-widget`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+5/-49`
  - Summary: `wip`
  - Notes: clean worktree.
- [ ] `docs/open-issues-triage`
  - Path: `/home/egallego/lean/verso/.worktrees/open-issues-triage`
  - Status: keep (`pending on human action`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+4/-3`
  - Summary: `doc: add open issues triage snapshot report`
  - Notes: clean worktree; report updated with a prioritized queue, waiting for human follow-up on resolved/closed issue cleanup.

### Special Trees, for Management / Metadata

- [ ] `agents.md`
  - Path: `/home/egallego/lean/verso`
  - Status: `special`
  - Decision: pending (set by user)
  - Ahead/Behind vs `upstream/main`: `+1/-0`
  - Summary: `Add AGENTS and dashboard overlay files`
  - Notes: special retained metadata/coordination tree.
- [ ] `main`
  - Path: `/home/egallego/lean/verso/.worktrees/main`
  - Status: `special`
  - Decision: pending (set by user)
  - PR: n/a
  - Ahead/Behind vs `upstream/main`: `+0/-0`
  - Summary: `chore: adapt to SubVerso's client-side pretty print support (#767)`
  - Notes: special retained baseline mirror; local refs currently up to date with `upstream/main`.

## Tasks Finished (PR Submitted / Cleanup Pending)

- [x] `bp` cleanup complete.
  - Outcome: removed worktree `.worktrees/bp` and deleted local branch `bp`.
- [x] `bp+refactor` cleanup complete.
  - Outcome: removed worktree `.worktrees/bp-plus-refactor` and deleted local branch `bp+refactor`.
- [x] `feat/folding-outline-doc-dup` merge check + cleanup complete.
  - Outcome: confirmed merged into `upstream/main`, removed worktree `.worktrees/folding-outline-doc-dup`, deleted local branch `feat/folding-outline-doc-dup`.
- [x] `codex/pr-768-assets` cleanup complete.
  - Outcome: removed worktree `.worktrees/pr-768-assets` and deleted local branch `codex/pr-768-assets`.
- [x] `tmp/component-hygiene-log` cleanup complete.
  - Outcome: removed worktree `.worktrees/tmp-component-hygiene-log`, deleted local branch `tmp/component-hygiene-log`, and deleted remote branch `ejgallego/tmp/component-hygiene-log`.
- [x] Detached cleanup complete: `.worktrees/pr768-before`.
  - Outcome: removed detached historical worktree.
- [x] Detached cleanup complete: `/tmp/verso-reg-bisect`.
  - Outcome: removed external detached bisect worktree.
- [x] `main` upkeep check executed.
  - Outcome: `main` is `+0/-0` vs local `upstream/main`; remote fetch attempted but temporary DNS/network prevented refresh.
- [x] `feat/folding-doc-start-range` queue-priority action complete.
  - Outcome: moved to first actionable position in `Tasks Ongoing`; currently `+1/-0` vs local `upstream/main`.
- [x] `feat/folding-ranges-lsp` review + cleanup complete.
  - Outcome: branch commit was patch-equivalent (`git cherry -`) to changes already in `upstream/main`; removed worktree `.worktrees/folding-ranges-lsp` and deleted local branch `feat/folding-ranges-lsp`.
- [x] `chore/bump-toolchain-v4.29.0-rc2` cleanup/state sync complete.
  - Outcome: local branch/worktree no longer exist, remote branch `ejgallego/chore/bump-toolchain-v4.29.0-rc2` already absent, and stale entry removed from `Tasks Ongoing`.
