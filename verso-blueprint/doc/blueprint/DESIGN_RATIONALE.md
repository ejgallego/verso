# Blueprint Design Rationale

Last updated: 2026-03-11

This document consolidates the earlier architecture notes, external-rendering
review, preview-hover design notes, and graph-status specification into one
repository-level rationale document.

## Scope

- Record the current Blueprint architecture boundaries.
- Capture the external-declaration rendering/data flow.
- Explain why preview and graph behavior are shaped the way they are.

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
the implementation, which is why future cleanup should be careful about adding
new ad hoc projections.

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

## Preview and Hover Rationale

### Shared browser-side preview helpers

Preview behavior is correctness-sensitive and was previously drifting through
copy/paste. The shared browser runtime therefore owns the reusable preview
operations, including:

- template collection and decoding,
- math rendering for inserted preview bodies,
- anchored-panel positioning,
- close-button policy,
- subtree hydration for nested preview content.

The goal is to keep preview behavior uniform across inline, summary, graph, and
other Blueprint surfaces.

### Statement/proof previews stay separate from Lean-code previews

Statement/proof previews use `PreviewCache` keyed by `(label, facet)`.
Lean-code previews use `Informal.LeanCodePreview` under a dedicated Lean-name
namespace.

That split is intentional:

- statement/proof previews are about informal node overviews,
- Lean-code previews are about declaration-centric code navigation.

The two eventually feed similar UI, but they do not have the same ownership
model or identity scheme.

### Preview retrieval should still look like one API to callers

Even though traversal and widget paths have different internal storage
boundaries, the call sites should converge on `PreviewSource` rather than
decoding multiple payload forms directly.

### Self-contained snippet rendering matters

Rendered HTML hovers are page-output scoped, while editor/LSP hovers are
info-tree scoped. Isolated renderers therefore cannot emit raw shared hover ids
unless they also participate in the surrounding hover table. That is why
Blueprint currently rewrites some isolated hover payloads into self-contained
HTML.

## Graph Status and Completion Rationale

### Two-track status model

The graph pipeline computes two orthogonal tracks per node:

- statement track (`StatementStatus`) drives border color
- proof/background track (`ProofStatus`) drives fill color

This keeps "can I state it?" separate from "can I finish the proof?" and avoids
collapsing all progress into one overloaded color.

### Completion policy comes from `ProvedStatus`

Completion blocking policy is centralized in `Informal.Data.ProvedStatus`:

- `blocksStatementCompletion`
- `blocksProofCompletion`
- `anyBlocksStatementCompletion`
- `anyBlocksProofCompletion`

Definitions and theorem-like nodes intentionally differ:

- definitions are blocked by both type-side and body-side gaps,
- theorem-like statements are blocked only by statement/type gaps,
- proof completion is blocked by any gap.

### Source precision is intentionally asymmetric

Inline/literate code has finer-grained provenance than external declaration
snapshots. External references are still useful, but the UI should not imply
the same per-command precision when that information does not exist.

### Warning overlays are separate from fill colors

Warning conditions such as:

- missing external declarations,
- local sorries,
- lean-only-without-informal-statement

are encoded as border-style overlays rather than as alternate fill colors. This
keeps progress color and warning state orthogonal.

## Current Duplications and Risks

1. Status semantics still drift across local block rendering and global outputs.
2. Preview retrieval still has multiple internal representations/adapters.
3. External hover and external panel rendering still share concepts that are not
   fully unified in one view model.
4. Preview regressions are easy to miss without traversal-level regression
   tests.

This document is intentionally about why the current shape exists. Active
cleanup work and sequencing now live in `ROADMAP.md`.
