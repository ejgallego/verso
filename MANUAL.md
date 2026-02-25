# Blueprint Manual Notes

This page documents the `parent` / `group` feature for informal blueprint nodes.

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
