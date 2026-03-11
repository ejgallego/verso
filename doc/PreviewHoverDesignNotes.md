# Preview Hover Design Notes

Last updated: 2026-03-10 (`feat/link-preview-audit-20260308` checkpoint)

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

### 2. Statement/proof previews stay in `PreviewCache`

- Added `PreviewCache.Facet.ofInProgressKind : Data.InProgressKind -> Facet`.
- Changed `PreviewCache.Entry.ofBlocks` to accept `facet : Facet` (removed `isProof : Bool`).
- Updated `Informal.Block` preview registration to derive keys from `Facet`.
- Updated `Informal.Uses` preview-id suffix generation to use `Facet.suffix`.

Rationale: statement/proof is a domain choice, not a boolean toggle.

### 3. Lean-code previews use a dedicated manifest namespace

- Lean declaration links now use `Informal.LeanCodePreview`, not `PreviewCache`.
- The preview key is derived from a regular Lean `Name` namespace rooted at `Informal.LeanCodePreview`.
- Inline code blocks and external declaration panels are normalized into one shared code-preview entry type before they are rendered into the shared manifest.
- `Informal.CodeSummary` remains responsible for high-level status/summary UI, not for code-preview hover payloads.

Rationale: a link-to-code preview is a different concern from a statement/proof overview, so the APIs should not share one cache abstraction just because both eventually feed hover UI.

### 4. One helper for preview-render context injection

- Added `Informal.HoverRender.withInlinePreviewRenderContext`.
- Replaced duplicated `withReader` context rewrites in:
  - graph preview rendering,
  - summary preview rendering,
  - uses inline preview rendering.

Rationale: this marker is the anti-recursion boundary for preview rendering, so it must be uniform.

### 5. `uses` HTML path simplified to remove duplicated branches

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

### 6. Preview behavior is now expressed as `mode` + `placement`

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

### 7. Hover metadata has two storage paths with different ownership boundaries

- Editor/LSP hovers use `Verso.Hover.addCustomHover` in `src/verso/Verso/Hover.lean`.
- That API stores `CustomHover` values in Lean's info tree via `Info.ofCustomInfo`.
- `src/verso/Verso/Doc/Lsp.lean` resolves those nodes at request time for `textDocument/hover`.
- Rendered HTML code hovers use `Verso.Code.HighlightHtmlM` in `src/verso/Verso/Code/Highlighted.lean`.
- HTML hover payloads are stored in `Verso.Code.Hover.Dedup Html`, referenced from token DOM by `data-verso-hover="<id>"`, and emitted page-wide to `-verso-docs.json`.
- The client hover JS fetches that JSON table and resolves ids to popup HTML on demand.

Rationale: editor hovers are syntax/info-tree scoped, while rendered-page hovers are document-output scoped and optimized for HTML size by deduplicating repeated payloads.

### 8. Isolated HTML renderers must not emit raw `data-verso-hover` ids without a merge step

- A raw `data-verso-hover="<id>"` token is only valid relative to the page-level `Hover.State Html` that produced the corresponding `-verso-docs.json`.
- Direct or nested renderers that run `HighlightHtmlM` in isolation have their own local hover table, so their ids are not meaningful unless those tables are merged into the surrounding page-level state.
- `VersoBlueprint.DocGenNameRender` now handles this by rewriting local hover ids into inline `.hover-info` payloads before returning external declaration HTML.
- Shared hover JS now treats inline `.hover-info` payloads and fetched docs-json payloads uniformly, including docstring markdown rendering.

Rationale: the real design boundary is not "hover vs non-hover", but "shared page-local hover table" vs "self-contained snippet". Upstream, this should likely become an explicit helper or rendering mode rather than a blueprint-local rewrite.

## 2026-03-10 Checkpoint (`feat/link-preview-audit-20260308`)

This section captures the branch-local hover-link architecture that survived the preview audit work. It is intentionally written as a resume checkpoint, not as a final design endorsement.

### Current Hover-Link Approach

1. Preview data now has two intentional stores.

- Informal blocks register canonical preview payloads in `Informal.Block` via `PreviewCache.Entry.ofBlocks`.
- Lean declaration-link previews register in `Informal.LeanCodePreview` under a dedicated Lean-name namespace.
- `uses` links derive stable inline preview ids from `usePreviewId`, keyed by label plus preview facet suffix.
- Summary label previews, graph previews, bibliography backrefs, and `used by` all reuse the same traversal-rendered statement/proof bodies where available.
- Existing Lean declaration links consume the dedicated declaration-preview manifest entries instead.
- Widget previews are still the notable exception: they continue to use the widget/elaboration-side cache rather than the traversal cache.

2. HTML hover surfaces use one shared browser runtime, but not one shared panel.

- `window.bpPreviewUtils` in `Commands/Common.lean` owns the reusable browser-side helpers:
  - template collection and decoding,
  - hover-mode and placement decoding,
  - anchored positioning,
  - panel close-button policy,
  - subtree hydration,
  - trace/debug capture via `window.bpPreviewTrace`.
- Inline preview uses a single global panel, `#bp-inline-preview-panel`.
- Summary preview uses its own anchored hover panel, but binds through `bindTemplatePreview`.
- Graph preview keeps its own preview and group-hover panels, but reuses shared behavior parsing, close-button wiring, positioning helpers, and subtree hydration.
- `used by` remains a custom panel surface, but it now opts into the shared subtree-hydration path so nested refs can be rebound there too.

3. Newly inserted preview DOM is now treated as a hydration boundary.

- `bpPreviewUtils.registerPreviewHydrator` lets each preview surface register a local rebinding pass.
- `bpPreviewUtils.hydratePreviewSubtree` is called whenever preview HTML is inserted into a panel body.
- This is what lets nested refs inside summary, graph, and `used by` previews participate in the same preview runtime instead of remaining dead HTML.

4. Inline preview resolution now has three tiers.

- Tier 1: page-local inline preview templates in the hidden inline preview store (`template.bp_inline_preview_tpl[data-bp-preview-id]`).
- Tier 2: page-level label preview templates emitted by informal blocks (`template.bp_label_preview_tpl[data-bp-preview-label]`).
- Tier 3: metadata fallback cards synthesized from `data-bp-preview-fallback-*` attributes when neither template path is present.

5. Nested same-panel inline hover is handled by replacing the global inline panel in place.

- Outer inline refs anchor the panel to the hovered trigger.
- Inner refs rendered inside that panel do not spawn a second panel; they swap the existing panel body/title in place.
- The runtime keeps a short delayed hide (`180ms`), a temporary panel size lock, and an `ignoreNextPanelExit` guard to survive obvious synthetic leave events during DOM replacement.
- Debugging for this path lives in `bpPreviewTrace`, with `inline.show`, `inline.trigger.*`, `inline.panel.*`, `inline.scheduleHide.fire`, and `inline.hide` entries.

### What Works Well At This Checkpoint

- Shared preview-data flow is much better aligned than before this branch:
  - summary coverage expanded,
  - bibliography backlinks gained previews,
  - graph previews hydrate nested refs,
  - `used by` nested hover is on the shared hydration path.
- Label-scoped fallback templates emitted by `Informal.Block` mean nested refs are no longer restricted to the local inline-template owner.
- The shared runtime now has enough instrumentation to trace hover ownership problems without guessing blindly.

### Known Failures

1. Nested inline-preview-in-inline-preview is still not correct.

- Known repro: `Rational-Versions`, hover theorem 15, then definition 10 inside the preview.
- Latest checkpoint behavior: the child panel can stay visible, but the nested content still resolves to an empty body in that path.
- Earlier lifecycle failures were reduced, but payload resolution and/or same-panel ownership is still incomplete there.

2. Graph-nested inline preview still needs follow-up validation after the same-panel fix.

- The graph HTML preview body now hydrates nested refs before math rendering.
- That fixed one class of dead nested links, but graph-child preview behavior still needs manual confirmation once the inline recursion bug is solved.

3. Preview titles are still not fully canonicalized.

- Some surfaces use `BlockData.displayTitle`/`displayNumber`.
- Other paths still fall back to raw labels or ad hoc `data-bp-preview-title` strings.
- This is now tracked in `TECHDEBT.md` as “unify preview labels/titles behind one canonical API”.

### Resume Pointers

- Primary files:
  - `src/verso-blueprint/VersoBlueprint/Commands/Common.lean`
  - `src/verso-blueprint/VersoBlueprint/Informal/Block.lean`
  - `src/verso-blueprint/VersoBlueprint/Informal/Uses.lean`
  - `src/verso-blueprint/VersoBlueprint/Commands/graph.js`
- Primary browser probe:
  - `localStorage.setItem("bp-debug-preview", "1")`
  - then inspect `(window.bpPreviewTrace || []).slice(-30)`
- Most useful trace finding so far:
  - after nested `Definition 10` show, panel exit events can still arrive in a way that leaves the child preview selected but without stable content.

### Validation Snapshot

- Focused tests had passed before this checkpoint:
  - `lake build Tests.BlueprintSummaryLinks Tests.BlueprintLinkHover Tests.BlueprintPreviewWiring Tests.BlueprintTexMacros`
  - `lake env lean src/tests/Tests/BlueprintLinkHover.lean`
  - `lake env lean src/tests/Tests/BlueprintPreviewWiring.lean`
- Reliable artifact build path for this branch:
  - `lake env lean --run test-projects/Noperthedron/Main.lean --output /home/egallego/lean/verso-blueprint/_out/link-preview-audit-20260308`
