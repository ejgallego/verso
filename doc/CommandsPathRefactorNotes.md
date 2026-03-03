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
3. Shared derivation/render helpers now live in `VersoBlueprint/Lib/`:
   - `PreviewLookup.lean`
   - `NodeFacts.lean`
   - `SummaryBuild.lean`
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

## Next Step Order

1. Introduce a shared status record for all command and local renderers.
2. Replace any remaining direct status recomputation with shared library calls.
3. Add traversal-level regression tests for graph/summary/bibliography rendering paths.
4. Only then evaluate whether additional module slicing is still warranted.
