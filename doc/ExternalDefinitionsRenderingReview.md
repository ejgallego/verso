# External Definitions Rendering Review (Post-Rebase)

Date: 2026-03-03  
Worktree: `feat/external-def-display`  
Base: `bp@2d68ac9a`  
Scope: external declaration rendering/status paths after command-path modularization

## What Changed in `bp` Since Initial Review

1. Commands path split completed:
   - `Commands/Graph.lean`, `Commands/Summary.lean`, `Commands/Bibliography.lean`, `Commands/Common.lean`.
2. Shared libraries now exist for reuse:
   - `Lib/PreviewLookup.lean`
   - `Lib/HoverRender.lean`
   - `Lib/PreviewSource.lean`
3. Summary data build now reads external declaration snapshots directly from `Data.ExternalRef`.

## Current Rendering/Data Flow

1. `(lean := "...")` references become `Data.ExternalRef`.
2. `externalDeclStatus` enriches references with:
   - presence,
   - provenance/range,
   - pretty-printed metadata,
   - optional `sourceHref?`.
3. `BlockData.codeStatus` carries `Array ExternalDeclStatus`.
4. `Block.informal.toHtml` projects to `ExternalHoverDecl` and renders:
   - hover list (`externalHoverListItems`),
   - code panel list (`externalPanelListItems`).
5. Global summary uses `Commands/Summary.buildSummary`.

## Name Ownership Boundary

1. Informal object labels (blueprint node labels) are blueprint-owned metadata.
2. `(lean := "...")` declaration names are Lean-owned identifiers.
3. Blueprint label policies (for example TeX-prefix trimming) must not rewrite `(lean := "...")` names.

## Remaining Redundancies

1. Hover and panel rendering still duplicate some body-row HTML shape (metadata/details composition), even though head/status/source-fact derivation is now shared.
2. CSS selectors `.bp_external_decl_details` and `.bp_external_decl_preview` remain unused.

## Implemented in This Worktree

1. Optional source-link support for external declarations:
   - option `verso.blueprint.externalCode.sourceLinkTemplate`
   - fields `ExternalDeclStatus.sourceHref?` and `ExternalHoverDecl.sourceHref?`
   - optional `"source ref"` link in hover/panel entries.
2. Deduped external declaration status logic in `Block.informal.toHtml`:
   - one `ExternalDeclAggregate` helper reused for title/status icon/status mark,
   - shared `externalDecl*` helpers for class/text/sorry/source info across hover and panel.
3. Option docs updated:
   - `test-projects/Noperthedron/OPTIONS.md`
4. Mechanical render extraction:
   - moved code-view model + renderer into `src/verso-blueprint/VersoBlueprint/Informal/Code.lean`
   - `src/verso-blueprint/VersoBlueprint.lean` now keeps orchestration plus external ref enrichment
5. Follow-up cleanup:
   - removed unused `sourceBodyPretty?` payload and `verso.blueprint.externalCode.previewLimit.rhs`
   - reduced hover/status field duplication by making `ExternalHoverDecl` extend `ExternalDeclStatus`

## Next Rendering-Focused Steps

1. Introduce a builder boundary (`buildCodeRenderData`) so rendering stays pure over precomputed facts.
2. Remove or reintroduce UI usage for `.bp_external_decl_details` / `.bp_external_decl_preview`.
3. Add regression checks for source-link presence when template option is enabled.
