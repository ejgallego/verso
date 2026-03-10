# TECHDEBT

## VersoBlueprint preview pipeline

- [ ] Consolidate widget preview cache (`elabStx`) and traversal preview cache (`PreviewCache.Entry`) behind a single phase-safe representation.
- [ ] Deduplicate preview-domain decode logic currently duplicated in graph and summary renderers.
- [ ] Unify preview labels/titles behind one canonical API so every surface uses the same resolved block title/number instead of mixing `BlockData.displayTitle`, raw labels, and ad hoc `data-bp-preview-title` fallbacks.
- [ ] Unify preview UI behavior across graph panel and summary hovers (shared component or shared renderer helper).
- [ ] Remove graph `setTimeout` fallback for preview handler attachment once graphviz `end` lifecycle is verified stable on supported runtimes.
- [ ] Add regression tests:
  - PreviewCache keying/JSON roundtrip.
  - Graph preview rendering and hover behavior.
  - Summary preview hover rendering.
