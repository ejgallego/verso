# Blueprint Manual Notes

This page documents the `parent` / `group` feature for informal blueprint nodes.

## Blueprint Options

Set Blueprint options with ordinary Lean `set_option` commands in the module that
elaborates your blueprint chapter/document:

```lean
set_option verso.blueprint.numbering global
set_option verso.blueprint.foldProofs true
```

Current user-facing options:

- `verso.blueprint.numbering`
  - default: `sub`
  - `sub`: chapter-prefixed numbering such as `Theorem 5.5`
  - `global`: document-order numbering such as `Theorem 27`
  - `local`: legacy local numbering without a chapter prefix
- `verso.blueprint.foldProofs`
  - default: `true`
  - folds proof bodies in rendered Lean code panels after `by`
- `verso.blueprint.trimTeXLabelPrefix`
  - default: `false`
  - trims TeX-style label prefixes when deriving Lean names (`thm:foo` becomes `foo`)
- `verso.blueprint.math.lint`
  - default: `true`
  - runs best-effort KaTeX validation for blueprint math during elaboration
- `verso.blueprint.externalCode.strictResolve`
  - default: `false`
  - upgrades unresolved or ambiguous `(lean := "...")` names from warnings to errors
- `verso.blueprint.externalCode.sourceLinkTemplate`
  - default: `""` (disabled)
  - builds source links for external declarations using `{path}`, `{relpath}`, `{module}`, `{line}`, `{column}`
- `verso.blueprint.graph.defaultDirection`
  - default: `TB`
  - sets the fallback graph direction for `blueprint_graph` when `(direction := ...)` is omitted
- `verso.blueprint.profile`
  - default: `false`
  - enables timing logs for blueprint directive/code-block elaboration

## Lean Summary States

Statement headers always show the Lean badge `L∃∀N`.

There are three meaningful Lean-summary states for an informal statement:

1. `inline`
   - The statement has an associated labeled Lean code block.
   - The badge links to the rendered code panel for that block.
   - The tooltip summarizes the definitions/theorems contributed by the block and whether any of them still contain `sorry`.

2. `external`
   - The statement uses `(lean := "...")` to point at external Lean declarations.
   - The badge summarizes the referenced declarations rather than a local code block.
   - Missing declarations and declarations with `sorry` are reflected in the status mark and tooltip.

3. `userOk`
   - The statement uses `(leanok := true)`.
   - This is a manual override that marks the Lean side as complete without attaching declarations.
   - The tooltip explicitly says that completion was asserted manually.

If none of these three states is present, the header still renders a muted `L∃∀N` badge as a stable placeholder.
That fallback means "no associated Lean code or declarations".

The global semantic model is intentionally richer than the compact header presentation.

- Source/provenance is tracked separately from completeness:
  - `inline`
  - `external`
  - `userOk`
  - `none`
- Completeness still uses the underlying `ProvedStatus` model:
  - `proved`
  - `missing`
  - `axiomLike`
  - `containsSorry`, with detailed information about whether the gap is in the statement, proof, or both

The header simplifies that richer model into a small Lean-chip status vocabulary:

- `✓ L∃∀N`: Lean side is present and complete
- `⚠ L∃∀N`: Lean side is present but contains `sorry`
- `! L∃∀N`: external Lean references are missing
- `A L∃∀N`: Lean side is axiom-like
- `X L∃∀N`: there is no associated Lean code yet

For now, `✓` and `X` intentionally keep the neutral black Lean Blueprint look; only warning/error-like states use stronger colors.

More detailed distinctions, especially statement-vs-proof incompleteness, remain available in the tooltip.

## Group Labels

Use `:::group` to declare a group label and its display header text:

```md
:::group "local_linear_algebra"
Linear-algebra lemmas for local geometry.
:::
```

- The positional argument is the group label used by `parent := "..."`.
- Group labels are global in the blueprint state.
- Redeclaring the same group with the same rendered header emits a warning.
- Redeclaring a group with different rendered headers emits an error.

## Parent Attribute

Informal nodes may declare `parent` and an optional triage `priority`:

```md
:::lemma_ "lem:pythagoras" (parent := "local_linear_algebra") (priority := "high")
...
:::
```

Supported priority values are `high`, `medium`, and `low`.

Duplicate `parent` declarations on the same label follow this behavior:

- Same `parent`: warning, keeping the existing value.
- Different `parent`: error, keeping the existing value.

Duplicate `priority` declarations on the same label follow the same pattern:

- Same `priority`: warning, keeping the existing value.
- Different `priority`: error, keeping the existing value.

Author metadata is declared separately:

```md
:::author "alice" (name := "Alice Example") (url := "https://example.com/alice")
:::
```

Statement-like blueprint directives may then use:

- `(owner := "alice")`
- `(tags := "analysis, critical")`
- `(effort := "small" | "medium" | "large")`
- `(priority := "high" | "medium" | "low")`
- `(pr_url := "https://github.com/org/repo/pull/123")`

These metadata fields are currently intended for block-level display panels and for summary-side ranking/rollup work.

## Rendering Behavior

The `parent` / `group` data is used in two places.

1. Blueprint summary (`blueprint_summary` / `bp_summary`):
- Keeps the inventory-oriented sections for entry counts, Lean progress, and theorem-like entries by parent.
- Shows a triage section derived from the current dependency/status data:
  - `Actionable priorities`: entries whose next statement/proof step is ready now and already unlocks downstream work.
  - `Statement-used entries`: entries reused in statement dependencies.
  - `Proof-used entries`: entries reused in proof dependencies.
  - `Top priorities`: ranked actionable entries, ordered by downstream unlock impact.
  - `Most used in statements` / `Most used in proofs`: ranked reverse-dependency lists, split by dependency axis.
  - `Group health`: per-parent rollups with counts plus the best next actionable child when one exists.
- Caps long triage lists to a short visible slice and adds a nested "show all" expander for the remainder.
- Uses explicit `(priority := "...")` metadata as an author override when ranking actionable items and parent-group next steps.
- Shows a structure/coverage section derived from the same graph and completion snapshots:
  - `Informal-only`, `Ready to formalize`, `Formalized, ancestors open`, `Fully closed`, and `Blocked or incomplete` coverage buckets.
  - `Heaviest prerequisites`: entries with the largest combined statement/proof prerequisite fan-in.
  - `No prerequisites` / `No dependents`: root and leaf views of the current dependency graph.
  - `Proof debt hotspots`: grouped counts of incomplete declarations and missing external declarations.
- Shows a "Theorem / Lemma / Corollary by Parent" section.
- Uses the `:::group` header text when available.
- Filters out groups with only one child.

2. Dependency graph (`blueprint_graph`):
- Renders parent groups as Graphviz clusters (supernodes).
- Uses the `:::group` header text as cluster labels when available.
- Filters out groups with only one child.

## Preview Manifest

Blueprint builds that import `VersoBlueprint` emit a shared preview manifest automatically at:

- `html-multi/-verso-data/blueprint-preview-manifest.json`

This file is the canonical runtime source for informal statement/proof preview
bodies. The page HTML no longer embeds a second copy of those block previews.
It currently includes per-preview metadata such as `key`, `label`, `facet`,
`kind`, `title`, optional `href`, optional `parent` / `parentTitle`, split
statement/proof dependencies, owner display name, tags, priority, effort, and
rendered `html`.

To print the current JSON Schema for the manifest, run an example executable
with `--dump-schema`, for example:

```bash
lake exe noperthedron --dump-schema
```

To print the generated manifest JSON itself instead of writing the site and then
reading the file, use `--dump-manifest`:

```bash
lake exe noperthedron --dump-manifest
```

For a short CLI summary of these preview-manifest-specific options plus the
standard manual-rendering flags, use:

```bash
lake exe noperthedron --help
```

## Notes

- Parent grouping is structural metadata; it does not change dependency edges.
- Grouping currently targets summary/visualization and triage rollups, not proof status semantics.
- Group labels are metadata, not first-class reference targets; linking to a parent/group label is not currently supported.
- The local block-header group chip is shown only for entries whose parent is shared by other entries, or when a `parent := "..."` label is present but no matching `:::group` was declared. The summary and dependency graph still fall back to the raw parent label text instead of failing.
- More generally, unresolved blueprint references are not currently accumulated into a global diagnostics report. Reference-oriented surfaces such as `{uses ...}` and `used by` resolve against the final traversal state and degrade locally if a target remains unavailable.
