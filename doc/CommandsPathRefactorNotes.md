# VersoBlueprint Commands Path Refactor Notes

Date: 2026-03-03
Status: merged into `bp` (follow-up cleanup planning only)

## Current Boundary Snapshot

1. Canonical semantic source remains `Environment.State.data`.
2. Command modules are now split by concern:
   - `VersoBlueprint/Commands/Graph.lean`
   - `VersoBlueprint/Commands/Summary.lean`
   - `VersoBlueprint/Commands/Bibliography.lean`
   - shared command JS in `VersoBlueprint/Commands/Common.lean`
3. Shared preview/render helpers now live in `VersoBlueprint/Lib/`:
   - `PreviewLookup.lean`
   - `HoverRender.lean`
   - `PreviewSource.lean`
4. Command CSS is now per-command:
   - `Commands/graph.css`
   - `Commands/summary.css`
   - `Commands/bibliography.css`

## Traversal Clients (Still Active)

1. Link resolution:
   - `Inline.informal`
   - `Block.informal`
   - `Block.informalCode`
2. Graph and summary rendering:
   - `Block.graph`
   - `Block.summary`
3. Citation resolution:
   - `Inline.bpCite`
   - `Block.bibliography`
4. Widget rendering path:
   - uses `PreviewSource` adapter over environment payloads

## Data.CodeRef Consumer Map (2026-03-03 refresh)

`Data.CodeRef` is currently consumed in five distinct paths:

1. Registration/merge semantics:
   - `Data.register` / `Data.registerCode` / `Data.registerCodeRef`
   - `src/verso-blueprint/VersoBlueprint/Data.lean`
2. Informal block status projection:
   - `BlockCodeStatus.ofCodeRef`
   - `src/verso-blueprint/VersoBlueprint.lean`
3. Graph semantics:
   - `nodeExternalDecls`, `nodeHasMissingExternalDecls`, `nodeHasTypeSorries`, `nodeHasProofSorries`
   - `src/verso-blueprint/VersoBlueprint/Graph.lean`
4. Summary semantics:
   - `buildSummary`
   - `src/verso-blueprint/VersoBlueprint/Commands/Summary.lean`
5. Informal HTML rendering:
   - `Block.informal.toHtml` and `Block.informalCode.toHtml`
   - `src/verso-blueprint/VersoBlueprint.lean`

## Remaining Refactor Items (Pending Only)

1. Converge status semantics across local block rendering and global outputs.
   - Today, graph/summary and local block panels still derive parts of status through different paths.
2. Harden the preview-source abstraction as the single API boundary.
   - Keep current adapters, but make all preview consumers call through one minimal contract.
3. Add focused regression checks for command outputs.
   - Graph and summary hover output
   - Bibliography back-link resolution
   - Widget statement preview rendering
4. Revisit optional caching only after API boundaries are stable.

## Consolidation Update (`feat/external-def-display`)

1. Implemented extraction of code-view model and renderer to:
   - `src/verso-blueprint/VersoBlueprint/Informal/Code.lean`
2. `VersoBlueprint.lean` now keeps external reference enrichment and orchestration.
3. Remaining gap is the builder boundary:
   - move to `buildCodeRenderData` so `toHtml` call sites become thin wrappers over pure rendering.

## Next Step Order

1. Introduce `buildCodeRenderData` and keep rendering pure.
2. Replace remaining direct status recomputation with shared library calls.
3. Add traversal-level regression tests for graph/summary/bibliography rendering paths.
4. Only then evaluate whether additional module slicing is still warranted.
