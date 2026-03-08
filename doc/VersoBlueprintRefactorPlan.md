# VersoBlueprint Refactor Plan (bp)

## Scope

This plan tracks only pending refactor work after the commands-path merge.
Completed tasks have been removed from this document.

## 2026-03-03 Consolidation Notes (`feat/external-def-display`)

Completed in this worktree:

1. External declaration rendering/status dedup in informal block rendering path.
2. Optional external source link support (`verso.blueprint.externalCode.sourceLinkTemplate`).
3. Mechanical extraction of code-render data/view layer from `VersoBlueprint.lean` to:
   - `src/verso-blueprint/VersoBlueprint/Informal/Code.lean`
4. Refactor notes update with `Data.CodeRef` consumer map and redundancy list:
   - `doc/CommandsPathRefactorNotes.md`

Validation snapshot:

1. `lake build VersoBlueprint` passes.
2. `./generate-example-blueprints.sh` passes (warnings only).
3. `python3 test-projects/Noperthedron/check_blueprint_code_panels.py` still has known baseline failure:
   - missing `bp_external_status_sorry` in `The-Local-Theorem`.

## Current Priority

1. Keep one source of truth for blueprint semantics and status derivation.
2. Keep command/traversal render paths aligned with shared `Lib` APIs.
3. Add regression coverage before any new structural split.

## Pending Work Plan

## Phase 1: Shared Status Semantics

1. Define a shared status record derived from `Data.Node` + external decl checks.
2. Route graph, summary, and local block status badges through this record.
3. Remove remaining duplicated status recomputation.

## Phase 2: Preview API Consolidation

1. Keep `PreviewSource` as the only preview retrieval abstraction.
2. Audit call sites for direct preview decoding and replace with shared APIs.
3. Keep traversal/widget adapters separate internally, but behind the same interface.

## Phase 3: Validation and Safety Nets

1. Add targeted regression tests for:
   - graph hover previews
   - summary hover previews
   - bibliography citations/backrefs
   - widget statement preview rendering
2. Run `./generate-example-blueprints.sh` after each boundary change.
3. Keep changes behavior-preserving until tests are green.

## Known Risks

1. Silent divergence between local and global status rendering.
2. Preview rendering regressions not caught by compile-only checks.
3. Worktree drift across long-lived feature branches.

## Immediate Next Action

1. Introduce `buildCodeRenderData` so `Informal/Code.lean` stays pure over precomputed facts.

## 2026-03-04 Summary Streamlining Follow-ups

1. Hide zero-value summary cards/sections by default (for example, empty axiom/no-proof buckets).
2. Merge "Missing external Lean declarations" and "Incomplete details" into a single "Blockers" section with status filters.
3. Reduce theorem-list duplication by defaulting to one primary view:
   - either flat theorem-like index or by-parent index (keep the other behind a toggle/secondary details block).
4. Replace long inline status text with compact chips:
   - `complete`, `deps`, `sorries`, `no-proof`.
5. Add a compact-mode toggle:
   - cards-only summary view,
   - expandable detailed lists.
