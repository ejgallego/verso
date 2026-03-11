# Blueprint Docs

This directory is the repository-level home for Blueprint-specific design notes,
refactor plans, implementation reviews, and behavior specs.

It intentionally collects docs that were previously split between the root
`doc/` directory and `src/verso-blueprint/VersoBlueprint/`.

Current contents:

- `CommandsPathRefactorNotes.md`
  - Notes from the commands-path split and the remaining cleanup surface.
- `ExternalDefinitionsRenderingReview.md`
  - Review of external declaration rendering and status/data flow.
- `GRAPH_STATUS_COMPLETION_AND_COLORING_SPEC.md`
  - Implementation-aligned spec for graph status, completion, and coloring.
- `PreviewHoverDesignNotes.md`
  - Design notes for shared preview/hover behavior and runtime ownership.
- `VersoBlueprintRefactorPlan.md`
  - Active refactor backlog and follow-up plan for Blueprint internals.

Project-local operational notes for specific examples, such as
`test-projects/Noperthedron/OPTIONS.md`, remain with those example projects.
