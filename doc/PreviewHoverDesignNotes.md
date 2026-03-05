# Preview Hover Design Notes

Last updated: 2026-03-05 (`feat/preview-modes-placement-20260305`)

## Scope

- Address duplication and API-shape concerns in preview-hover handling.
- Keep behavior stable while reducing drift across graph/summary/inline paths.
- Out of scope for this pass:
  - persistent vs non-persistent graph preview mode selection (deferred),
  - multi-graph-per-page support (current project assumption: one blueprint graph per page).

## Decisions

### 1. Shared preview UI helpers live in `bpPreviewUtils`

- The shared utility now contains:
  - `collectPreviewTemplates`
  - `readPreviewTemplate`
  - `renderMath`
  - `bindCloseOnce`
  - `positionAnchoredPanel`
  - `shouldKeepOpen`
- Inline and summary preview scripts call these helpers instead of reimplementing:
  - preview-entry parsing,
  - viewport-clamped floating panel positioning,
  - leave/focus transition checks between trigger and panel.
- Graph preview now also consumes shared helpers for template entry parsing and close-button wiring.

Rationale: these behaviors are correctness-sensitive and were diverging via copy/paste.

### 2. Preview facet API is sum-type based end-to-end

- Added `PreviewCache.Facet.ofInProgressKind : Data.InProgressKind -> Facet`.
- Changed `PreviewCache.Entry.ofBlocks` to accept `facet : Facet` (removed `isProof : Bool`).
- Updated `Informal.Block` preview registration to derive keys from `Facet`.
- Updated `Informal.Uses` preview-id suffix generation to use `Facet.suffix`.

Rationale: statement/proof is a domain choice, not a boolean toggle.

### 3. One helper for preview-render context injection

- Added `Informal.HoverRender.withInlinePreviewRenderContext`.
- Replaced duplicated `withReader` context rewrites in:
  - graph preview rendering,
  - summary preview rendering,
  - uses inline preview rendering.

Rationale: this marker is the anti-recursion boundary for preview rendering, so it must be uniform.

### 4. `uses` HTML path simplified to remove duplicated branches

- Consolidated the previous `(some block, true)` and `(some block, false)` branches into one block-resolved path.
- Shared logic now computes:
  - plain rendered content,
  - preview ownership,
  - preview payload fallback,
  - hover wrapping.

Behavior intentionally preserved:

- unresolved + empty inline content: `[??]`,
- unresolved + non-empty inline content: pass-through rendered inlines,
- resolved content keeps same hover template dedupe and fallback body semantics.

### 5. Preview behavior is now expressed as `mode` + `placement`

- Introduced shared behavior enums in `HoverRender`:
  - `PreviewMode`: `hover | pinned`
  - `PreviewPlacement`: `anchored | docked`
- Preview panel HTML now carries a consistent attribute contract:
  - `data-bp-preview-mode`
  - `data-bp-preview-placement`
- Shared helper wiring in `bpPreviewUtils` now owns behavior decoding and close-button policy:
  - `readPanelBehavior`
  - `resetPanelPosition`
  - `configureCloseButton`
- Defaults currently wired:
  - inline preview: `hover + anchored`
  - summary preview: `hover + anchored`
  - graph preview: `pinned + docked`
  - graph group-hover panel: `pinned + anchored`
- Non-pinned close controls are hidden by contract in both JS and CSS.

Rationale: this keeps one code path for future configurability and avoids per-command behavior drift.
