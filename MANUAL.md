# Blueprint Manual Notes

This page documents the `parent` / `group` feature for informal blueprint nodes.

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

Informal nodes may declare `parent`:

```md
:::lemma_ "lem:pythagoras" (parent := "local_linear_algebra")
...
:::
```

Duplicate `parent` declarations on the same label follow this behavior:

- Same `parent`: warning, keeping the existing value.
- Different `parent`: error, keeping the existing value.

## Rendering Behavior

The `parent` / `group` data is used in two places.

1. Blueprint summary (`blueprint_summary` / `bp_summary`):
- Shows a "Theorem / Lemma / Corollary by Parent" section.
- Uses the `:::group` header text when available.
- Filters out groups with only one child.

2. Dependency graph (`blueprint_graph`):
- Renders parent groups as Graphviz clusters (supernodes).
- Uses the `:::group` header text as cluster labels when available.
- Filters out groups with only one child.

## Notes

- Parent grouping is structural metadata; it does not change dependency edges.
- Grouping currently targets summary/visualization, not proof status semantics.
