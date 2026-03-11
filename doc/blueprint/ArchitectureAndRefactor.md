# Blueprint Architecture and Refactor Notes

Last updated: 2026-03-11

This document consolidates the earlier command-path notes, external-rendering
review, and refactor backlog into one repository-level Blueprint architecture
and planning note.

Focused behavior specs that still stand alone:

- `GRAPH_STATUS_COMPLETION_AND_COLORING_SPEC.md`
- `PreviewHoverDesignNotes.md`

## Scope

- Record the current Blueprint architecture boundaries.
- Capture the external-declaration rendering/data flow.
- Keep one current refactor backlog instead of multiple overlapping notes.

## Current Architecture Snapshot

1. Canonical semantic source remains `Environment.State.data`.
2. Command modules are split by concern:
   - `VersoBlueprint/Commands/Graph.lean`
   - `VersoBlueprint/Commands/Summary.lean`
   - `VersoBlueprint/Commands/Bibliography.lean`
   - shared command JS in `VersoBlueprint/Commands/Common.lean`
3. Shared preview/render helpers live in `VersoBlueprint/Lib/`:
   - `HoverRender.lean`
   - `PreviewSource.lean`
4. Command CSS is per-command:
   - `Commands/graph.css`
   - `Commands/summary.css`
   - `Commands/bibliography.css`

## Active Traversal and Rendering Clients

1. Link resolution:
   - `Inline.informal`
   - `Block.informal`
   - `Block.informalCode`
2. Global rendering outputs:
   - `Block.graph`
   - `Block.summary`
   - `Block.bibliography`
3. Widget path:
   - consumes `PreviewSource` over environment payloads

## `Data.CodeRef` Consumer Map

`Data.CodeRef` still feeds multiple independent paths:

1. Registration and merge semantics in `Data.register`, `Data.registerCode`,
   and `Data.registerCodeRef`.
2. Informal block/code rendering in `Informal/Block.lean` and
   `Informal/Code.lean`.
3. Graph semantics in `Graph.lean`.
4. Summary semantics in `Commands/Summary.lean`.

This is the main place where "one source of truth" pressure still shows up in
the implementation.

## External Declaration Flow

1. `(lean := "...")` references become `Data.ExternalRef`.
2. Snapshot/enrichment adds:
   - presence,
   - provenance and ranges,
   - optional `sourceHref?`,
   - declaration rendering result.
3. Informal block rendering projects those snapshots into hover/panel views.
4. Summary and graph logic read the same snapshots for status reporting.

## Name Ownership Boundary

1. Blueprint node labels are blueprint-owned metadata.
2. `(lean := "...")` names are Lean-owned identifiers.
3. Blueprint label policies must not rewrite external Lean declaration names.

## Current Duplications and Risks

1. Status semantics still drift across local block rendering and global outputs.
2. Preview retrieval still has multiple internal representations/adapters.
3. External hover and external panel rendering still share concepts that are not
   fully unified in one view model.
4. Preview regressions are easy to miss without traversal-level regression
   tests.

## Validation Snapshot

1. `lake build VersoBlueprint` passed on the last dedicated refactor pass.
2. `./generate-example-blueprints.sh` passed with warnings only.
3. `python3 test-projects/Noperthedron/check_blueprint_code_panels.py` had a
   known baseline failure at the time of the earlier refactor note:
   - missing `bp_external_status_sorry` in `The-Local-Theorem`

## Current Priority

1. Keep one source of truth for Blueprint semantics and status derivation.
2. Keep command/traversal render paths aligned with shared `Lib` APIs.
3. Add regression coverage before any new structural split.

## Pending Work Plan

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

## Immediate Next Actions

1. Introduce `buildCodeRenderData` so `Informal/Code.lean` stays pure over
   precomputed facts.
2. Keep the summary streamlining follow-ups in view:
   - hide zero-value sections by default,
   - collapse duplicate blocker lists,
   - prefer one primary theorem list,
   - use compact status chips where possible.
