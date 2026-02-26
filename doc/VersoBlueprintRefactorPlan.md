# VersoBlueprint Refactor Plan (bp-aligned)

Date: 2026-02-26  
Status: active branch, in planning  
Working branch: `feat/versoblueprint-critique`  
Target baseline branch: `bp`

## Planning Status

1. This branch is retained as the planning branch for the VersoBlueprint modularization pass.
2. The document here is the current planning baseline and should be updated before any structural split starts.
3. Implementation work should begin only after rebasing/syncing against current `bp`.

## Baseline Update from `bp`

`bp` moved from `2be228be` to `f47d5b61` with 3 relevant commits:

1. `f2213eca` - parent grouping (`:::group`) + docs
2. `f816a5f4` - unified blueprint code panels + external status UX
3. `f47d5b61` - flattened external hover and statement panel behavior

High-impact files changed on `bp` since `2be228be`:

- `src/verso-blueprint/VersoBlueprint.lean`
- `src/verso-blueprint/VersoBlueprint/Commands.lean`
- `src/verso-blueprint/VersoBlueprint/Data.lean`
- `src/verso-blueprint/VersoBlueprint/Environment.lean`
- `src/verso-blueprint/VersoBlueprint/Graph.lean`
- `src/verso-blueprint/VersoBlueprint/Widget.lean`
- `MANUAL.md`
- `test-projects/Noperthedron/Chapters/*.lean`
- `test-projects/Noperthedron/check_blueprint_code_panels.py`

## Problem Statement

`src/verso-blueprint/VersoBlueprint.lean` is still oversized and multi-responsibility.  
Current risk is high merge/conflict pressure because recent `bp` work is concentrated in this same file.

## Refactor Goals

1. Split `VersoBlueprint.lean` into smaller modules with clear responsibility boundaries.
2. Preserve behavior from the latest `bp` commits (group directive + code panel/external hover UX).
3. Reduce duplication across `VersoBlueprint.lean`, `Commands.lean`, and `Widget.lean`.
4. Keep one source of truth for preview lookup and graph visual semantics.

## Execution Plan

### Phase 0: Sync and Safety

1. Rebase/cherry-pick this branch to include `bp@f47d5b61` before structural edits.
2. Run baseline validation:
   - `lake exe noperthedron`
3. Record baseline behavior snapshots for code-panel and hover UX in Noperthedron.

### Phase 1: Mechanical Split (No Behavior Change)

Extract from `VersoBlueprint.lean` into new modules:

1. Config + external-name parsing/resolution
2. Block/code/inline view data types
3. Block HTML renderer + CSS asset handling
4. Inline role renderer (`uses`)
5. Directive expanders (`definition/lemma/theorem/corollary/proof`)
6. Code block expanders (`lean/internal/rocq`)

Keep `VersoBlueprint.lean` as the thin aggregator/re-export entry point.

### Phase 2: Deduplication

1. Centralize preview cache decode helper used by graph and summary rendering paths.
2. Centralize graph DOT header + legend semantics shared by `Commands` and `Widget`.
3. Remove stale/unused fields in moved structures when confirmed safe.

### Phase 3: Verification and Cleanup

1. Re-run `lake exe noperthedron`.
2. Re-run blueprint panel checker:
   - `test-projects/Noperthedron/check_blueprint_code_panels.py`
3. Review `MANUAL.md` for moved module references and update docs.

## Risks and Mitigation

1. Merge conflicts against active `bp` work:
   - Mitigation: phase 0 sync first; keep phase 1 mechanical/minimal.
2. UI regressions in hover/panel behavior:
   - Mitigation: explicit panel checker + manual Noperthedron verification.
3. Hidden coupling through widget activation side effects:
   - Mitigation: keep behavior identical in phase 1; postpone semantics changes to follow-up.

## Out of Scope for This Pass

1. Redesigning graph/status semantics.
2. Major UX redesign of panels/hovers.
3. Changing Noperthedron content semantics beyond compatibility fixes.
