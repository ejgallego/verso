# VersoBlueprint Refactor Plan (bp)

## Scope

This plan tracks only pending refactor work after the commands-path merge.
Completed tasks have been removed from this document.

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
2. Run `lake exe noperthedron` after each boundary change.
3. Keep changes behavior-preserving until tests are green.

## Known Risks

1. Silent divergence between local and global status rendering.
2. Preview rendering regressions not caught by compile-only checks.
3. Worktree drift across long-lived feature branches.

## Immediate Next Action

1. Implement Phase 1 task 1 (shared status record) in `VersoBlueprint/Lib/`.
