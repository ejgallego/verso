# Blueprint Roadmap

Last updated: 2026-03-11

This document tracks the active cleanup and refactor plan for Blueprint support
in this repository.

Background and design rationale live in `DESIGN_RATIONALE.md`.

## Current Priority

1. Keep one source of truth for Blueprint semantics and status derivation.
2. Keep command/traversal render paths aligned with shared `Lib` APIs.
3. Add regression coverage before any new structural split.

## Immediate Next Actions

1. Introduce `buildCodeRenderData` so `Informal/Code.lean` stays pure over
   precomputed facts.
2. Fix the highest-priority review issues:
   - `@[blueprint]` export persistence across module boundaries
   - nested and duplicate block soft-fail behavior
   - duplicated preview-source representations

## Planned Work

### Phase 1: Shared Status Semantics

1. Define a shared status record derived from `Data.Node` plus external
   declaration checks.
2. Route graph, summary, and local block status badges through that record.
3. Remove remaining duplicated status recomputation.

### Phase 2: Preview API Consolidation

1. Keep `PreviewSource` as the only preview retrieval abstraction.
2. Audit call sites for direct preview decoding and replace them with shared
   APIs.
3. Keep traversal/widget adapters separate internally, but behind the same
   interface.

### Phase 3: Validation and Safety Nets

1. Add targeted regression tests for:
   - graph hover previews
   - summary hover previews
   - bibliography citations/backrefs
   - widget statement preview rendering
2. Run `./generate-example-blueprints.sh` after each boundary change.
3. Keep behavior-preserving changes until the regression surface is covered.

## UI and Summary Follow-ups

1. Hide zero-value summary cards and sections by default.
2. Collapse duplicate blocker lists into one filtered blockers section.
3. Prefer one primary theorem list by default instead of parallel repeated
   views.
4. Use compact status chips where possible.
5. Consider a compact-mode toggle once the semantics are stable.

## Known Risks

1. Silent divergence between local and global status rendering.
2. Preview regressions not caught by compile-only checks.
3. Drift across long-lived worktrees and branches.

## Validation Baseline

1. `lake build VersoBlueprint` passed on the last dedicated refactor pass.
2. `./generate-example-blueprints.sh` passed with warnings only.
3. `python3 test-projects/Noperthedron/check_blueprint_code_panels.py` had a
   known baseline failure at the time of the earlier refactor note:
   - missing `bp_external_status_sorry` in `The-Local-Theorem`
