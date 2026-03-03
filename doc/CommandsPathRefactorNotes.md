# VersoBlueprint Commands Path Analysis

Date: 2026-03-02  
Scope: command/elaboration/traversal boundary audit for `VersoBlueprint`

## Goals (from discussion)

1. Make elaboration vs traversal boundaries explicit and aligned.
2. Keep a single source of truth for blueprint data semantics.
3. Prioritize reusable core APIs (even if some callers recompute for now).
4. Prepare modular split of `Commands.lean` (`ShowGraph.lean`, etc.).
5. Support shared hover rendering needs across final HTML paths.

## 0) Implementation Progress (2026-03-03)

Completed extraction checkpoints (behavior-preserving):

1. `873ce284`:
   - shared traversal preview decoding via `Lib/PreviewLookup.lean`
   - graph + summary HTML paths now use a single preview lookup helper

2. `b0cb3f80`:
   - shared external declaration adapter in `Lib/NodeFacts.lean`
   - graph/summary external status reads use one adapter abstraction

3. `b88ef562`:
   - summary model + builder moved to `Lib/SummaryBuild.lean`
   - `Commands.lean` now consumes the shared builder instead of owning model logic

4. `1b0d6902`:
   - graph part-command path moved to `Commands/ShowGraph.lean`
   - top-level load path updated in `VersoBlueprint.lean`

5. (working tree, validated):
   - summary command registration moved to `Commands/ShowSummary.lean`
   - bibliography command registration moved to `Commands/ShowBibliography.lean`
   - summary/bibliography part builders (`mkSummaryPart`, `mkBibliographyPart`) moved with their command modules
   - top-level imports updated accordingly

6. (working tree, validated):
   - added `Lib/HoverRender.lean` as shared hover/preview markup API
   - graph preview template/store/panel markup now routed through `HoverRender`
   - summary preview tooltip wrapper now routed through `HoverRender`

7. (working tree, validated):
   - added `Lib/PreviewSource.lean` as a shared preview adapter boundary
   - traversal path now consumes previews via `PreviewSource.traversalBlocks?`
   - widget path now consumes previews via `PreviewSource.fromEnvironment?` + `PreviewSource.renderWidgetHtml`
   - `PreviewRender` now exposes `renderPreviewBlocksHtml` so adapter consumers can render manual preview blocks directly

8. (working tree, validated):
   - moved summary block renderer to `Commands/RenderSummary.lean`
   - moved bibliography block renderer to `Commands/RenderBibliography.lean`
   - updated `ShowSummary`/`ShowBibliography` to import renderer modules and use fully qualified block constructors for robust quotation precheck
   - top-level imports updated in `VersoBlueprint.lean`

Current boundary status:

- `Environment.State.data` remains the single semantic source for graph/summary derivation.
- Shared derivation utilities now live in `Lib/`.
- Graph/summary/bibliography command paths are split out of monolithic `Commands.lean`.
- Shared hover/preview HTML contracts now live in `Lib/HoverRender.lean`.
- Traversal + widget preview acquisition now share a common adapter contract in `Lib/PreviewSource.lean`.
- Graph/summary/bibliography block renderers now live in dedicated modules under `Commands/`.
- `Commands.lean` now mainly owns shared command data types/options and shared CSS/JS payload constants.

Immediate next step:

1. Extract shared command payload/constants (`GraphBlockData`, `GraphDirection`, `d3DotCss`, `openTargetDetailsJs`) into a dedicated shared module (`Commands/Shared.lean` or equivalent), then make render modules depend on that.
2. Keep `Commands.lean` as a compatibility shim temporarily, then trim it to a thin re-export once call sites are updated.

## 1) Current Data Model by Phase

### A. Elaboration-time mutable/persistent state (`Environment.State`)

Source:
- `InProgress`/`State`: `src/verso-blueprint/VersoBlueprint/Environment.lean:16`
- env extension export stripping `elabStx`: `src/verso-blueprint/VersoBlueprint/Environment.lean:31`

Stored:
- `stack : List InProgress` for open directives (`label`, `kind?`, `isProof`, `codeHint`, `deps`, `elabStx`).
- `data : NameMap Node` as project-level blueprint DB.
- `texPrelude` chunks.

Key point:
- `elabStx` is explicitly transient across module boundaries (`exportEntriesFnEx` clears it).

### B. Canonical node payload (`Data.Node`)

Source:
- `Node` and sub-structures: `src/verso-blueprint/VersoBlueprint/Data.lean:193`
- merge/register logic: `src/verso-blueprint/VersoBlueprint/Data.lean:226`

Stored per label:
- `kind`, `count`
- `statement : Option InformalData` (`deps`, `elabStx`, plus `stx`)
- `proof : Option InformalData` (`deps`, `elabStx`, plus `stx`)
- `code : Option CodeRef`
  - `.userOk`
  - `.external (Array ExternalRef)`
  - `.literate (Code)` with Lean-defined decl metadata

### C. Block/inline serialized data in doc AST (elaboration output)

Source:
- `BlockData`, `CodeBlockData`: `src/verso-blueprint/VersoBlueprint.lean:184`
- `GraphBlockData`, `Summary`, `BibliographyData`: `src/verso-blueprint/VersoBlueprint/Commands.lean:117`

Meaning:
- `BlockData` and `CodeBlockData`: local per-block rendering info.
- `GraphBlockData` and `Summary`: global snapshot computed during part elaboration.
- `BibliographyData`: bibliography entry list snapshot.

### D. Traversal domain objects (cross-block linking & hover lookup)

Source:
- domain names: `src/verso-blueprint/VersoBlueprint/Resolve.lean:14`
- preview payload format: `src/verso-blueprint/VersoBlueprint/PreviewCache.lean:14`

Stored during traversal:
- `Informal.Block.informal` -> label anchor + `BlockData`
- `Informal.Block.informalCode` -> label anchor + `CodeBlockData`
- `Informal.Block.informalPreview` -> statement/proof preview blocks
- `Informal.Block.bpCitations` -> bibliography anchors
- `Informal.Inline.bpCite.usages` -> citation backrefs and context summaries

## 2) Producer Map

1. Directive elaboration (`definition/lemma/theorem/corollary/proof`) pushes/pops env stack, registers deps and optional code hints:
   - `src/verso-blueprint/VersoBlueprint.lean:969`

2. Lean code block elaboration computes:
   - highlighted block term for rendered code,
   - per-declaration metadata (`definedDefs`/`definedTheorems` + sorry refs):
   - `src/verso-blueprint/VersoBlueprint/Lean.lean:258`
   - then writes both `CodeBlockData` and env code facts:
   - `src/verso-blueprint/VersoBlueprint.lean:1021`

3. `@[blueprint "..."]` attribute registers Lean-only/external nodes (optionally statement from docstring):
   - `src/verso-blueprint/VersoBlueprint/Attribute.lean:150`

4. Part commands compute global snapshots:
   - graph from env DB: `src/verso-blueprint/VersoBlueprint/Commands.lean:797`
   - summary from env DB: `src/verso-blueprint/VersoBlueprint/Commands.lean:847`
   - bibliography entry list from citation registry: `src/verso-blueprint/VersoBlueprint/Commands.lean:960`

## 3) Traversal Consumers (clients + needs)

### Base link/citation resolution clients

1. `Inline.informal` (`{uses}` links):
   - needs label -> block anchor + kind/count text.
   - writes/fills missing block data via informal domain.
   - `src/verso-blueprint/VersoBlueprint.lean:1062`

2. `Inline.bpCite`:
   - needs bibliography target resolution.
   - records citation usage locations for reverse links.
   - `src/verso-blueprint/VersoBlueprint/Cite.lean:349`

3. `Block.bibliography.toHtml`:
   - needs citation usage aggregation + href resolution.
   - `src/verso-blueprint/VersoBlueprint/Commands.lean:714`

### Global graph/summary rendering clients

4. `Block.graph.toHtml`:
   - needs node links + preview blocks from preview domain.
   - `src/verso-blueprint/VersoBlueprint/Commands.lean:415`

5. `Block.summary.toHtml`:
   - needs entry links, code links, decl links, preview blocks.
   - `src/verso-blueprint/VersoBlueprint/Commands.lean:528`

### Informal block renderer clients

6. `Block.informal.toHtml`:
   - needs code block domain data and example decl href resolution for hover/status.
   - `src/verso-blueprint/VersoBlueprint.lean:803`

7. `Block.informalCode.toHtml`:
   - needs owning block data for "Code for X N" summary label.
   - `src/verso-blueprint/VersoBlueprint.lean:905`

### Widget path (separate rendering channel)

8. Widget panel uses env `statement.elabStx` and local graph build:
   - `src/verso-blueprint/VersoBlueprint/Widget.lean:275`
   - HTML rendering path in term elaboration: `src/verso-blueprint/VersoBlueprint/PreviewRender.lean:60`

## 4) Misalignments / Refactor Pressure Points

1. Preview representation split:
   - traversal uses `PreviewCache.Entry.blocks`;
   - widget uses env `elabStx` + `PreviewRender`.
   - Existing TODO already calls this out:
     - `src/verso-blueprint/VersoBlueprint.lean:991`
     - `src/verso-blueprint/VersoBlueprint/PreviewCache.lean:33`

2. Duplicated preview decode logic in two renderers:
   - graph and summary each define local `previewBlocks?`.
   - `src/verso-blueprint/VersoBlueprint/Commands.lean:438`
   - `src/verso-blueprint/VersoBlueprint/Commands.lean:541`

3. Global semantic duplication:
   - graph status logic in `Graph.lean` considers external missing/sorries (`buildAll` wires external callbacks).
   - summary logic in `Commands.buildSummary` recomputes lean/sorry stats separately and only counts literate sorries.
   - `src/verso-blueprint/VersoBlueprint/Graph.lean:103`
   - `src/verso-blueprint/VersoBlueprint/Commands.lean:847`

4. External status semantics diverge by output:
   - local block status (`BlockData.codeStatus`) only stores external presence boolean computed at directive elaboration time.
   - no external sorry status encoded there.
   - `src/verso-blueprint/VersoBlueprint.lean:176`

5. Very large mixed-responsibility files:
   - `VersoBlueprint.lean` and `Commands.lean` both mix data types, traversal registration, rendering, part command assembly, and JS/CSS.

6. Candidate dead/transitional fields:
   - `InformalData.stx` and `Data.Code.stx` are stored but not consumed by current render/global paths.
   - `src/verso-blueprint/VersoBlueprint/Data.lean:153`
   - `src/verso-blueprint/VersoBlueprint/Data.lean:193`

## 5) Proposed Target Boundaries

### Core principle

`Environment.State.data` remains the canonical blueprint DB.  
Everything else is either:
- derived projection for rendering (`BlockData`, `Summary`, `GraphBlockData`), or
- traversal index/cache for links (`Resolve` domains + preview cache).

### A. New `Lib/` layer (first extraction target)

Create a `VersoBlueprint/Lib/` folder for reusable pure-ish functions:

1. `Lib/NodeFacts.lean`
   - normalize one `Data.Node` into a derived record used by graph + summary + local status badges.
   - include external checks via injectable callbacks (presence/typeSorry/proofSorry).

2. `Lib/Summary.lean`
   - `buildSummaryFromState` using `NodeFacts`.
   - no HTML; just data.

3. `Lib/GraphBuild.lean`
   - thin wrapper around `Graph` with shared external status adapter.
   - keep `Graph.lean` as display/style + DOT emitter.

4. `Lib/PreviewLookup.lean`
   - shared decode of statement/proof preview blocks from traversal state.
   - remove duplicated `previewBlocks?` in graph/summary HTML.

5. `Lib/HoverRender.lean`
   - helper constructors for preview tooltip fragments and link-with-preview wrappers.
   - used by graph + summary HTML paths.

This meets the "recompute is fine, deduplicate abstractions first" requirement.

### B. Commands module split

Split current `Commands.lean` into:

1. `Commands/Shared.lean`
   - shared types (`Summary`, `GraphBlockData`, etc.) and arg parsing.

2. `Commands/ShowGraph.lean`
   - graph part command + graph block renderer.

3. `Commands/ShowSummary.lean`
   - summary part command + summary block renderer.

4. `Commands/ShowBibliography.lean`
   - bibliography part command + bibliography block renderer.

5. `Commands.lean`
   - thin aggregator import.

### C. Hover API direction

Define a generic preview contract instead of hardcoding traversal-vs-widget internals at callsites:

1. `PreviewPayload` abstraction with two adapters:
   - traversal adapter: `PreviewCache.Entry.blocks`
   - widget adapter: env `elabStx` rendered via `PreviewRender`

2. shared `renderPreviewHtml` entrypoints:
   - traversal renderer for `Output.Html` block fragments.
   - widget renderer for panel JSON payload.

This gives one API surface while allowing different underlying payloads for now.

## 6) Phased Implementation Plan

### Phase 1 (safe extraction, no behavior changes)

1. Introduce `Lib/PreviewLookup.lean` and switch graph+summary to it.
2. Introduce `Lib/NodeFacts.lean` and move duplicated status/sorry helpers there.
3. Wire `buildAll` and `buildSummary` through shared library functions.
4. Keep recomputation behavior unchanged.

### Phase 2 (commands modularization)

1. Split `Commands.lean` into `Commands/ShowGraph.lean`, `Commands/ShowSummary.lean`, `Commands/ShowBibliography.lean`, `Commands/Shared.lean`.
2. Keep command syntax/behavior 1:1.
3. Add focused tests/snapshots for generated graph+summary+bibliography sections.

### Phase 3 (hover API unification)

1. Add shared hover rendering helpers (`Lib/HoverRender.lean`).
2. Use same helper in graph and summary HTML.
3. Introduce adapter interface for widget/traversal preview sources; keep current storage split.

### Phase 4 (optional cleanup)

1. Re-evaluate unused `stx` fields in `InformalData`/`Code`.
2. Decide whether `BlockCodeStatus` should carry richer external status (including sorry presence) or defer all such status to shared facts.
3. Consider caching derived facts only if performance requires it.

## 7) Immediate Next Step Recommendation

Start with **Phase 1 / Step 1**:

1. extract shared preview decode helper (`Lib/PreviewLookup.lean`);
2. migrate both graph and summary renderers to it;
3. verify with `lake exe noperthedron`.

This is the smallest high-value change that improves alignment without changing semantics.
