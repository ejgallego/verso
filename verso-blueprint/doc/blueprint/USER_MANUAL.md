# Blueprint User Manual

Last updated: 2026-03-11

This document is the repository-level manual for working with Blueprint in this
repo.

It focuses on practical usage and maintenance:

- how to validate the example blueprints,
- where generated artifacts land,
- where Blueprint-specific options and project-local policy live,
- which other docs to read next.

Design background lives in `DESIGN_RATIONALE.md`.
Planned cleanup and implementation work lives in `ROADMAP.md`.

## Scope

This is a maintainer-oriented manual for the Blueprint support in
`verso-blueprint`, not a full end-user syntax reference for every directive.

## Main Validation Workflow

To validate the example Blueprint projects, run:

```bash
./generate-example-blueprints.sh
```

This builds:

- `noperthedron`
- `spherepackingblueprint`

Outputs go to:

- `_out/example-blueprints/noperthedron/`
- `_out/example-blueprints/spherepackingblueprint/`

## Shared Preview Manifest

Each generated Blueprint site emits a shared preview manifest at:

`html-multi/-verso-data/blueprint-preview-manifest.json`

This manifest is the canonical runtime source for Blueprint statement/proof
preview bodies. It also carries structured preview metadata such as:

- label
- facet
- kind
- parent
- dependencies
- ownership and triage fields

Useful CLI entry points:

```bash
lake exe noperthedron --dump-schema
lake exe noperthedron --dump-manifest
lake exe noperthedron --help
```

## Where Option Policy Lives

Repository-level Blueprint implementation notes live in this directory.

Project-local option policy stays with the project that owns it. In particular:

- `test-projects/Noperthedron/OPTIONS.md`

That file is currently the detailed option-policy reference for the
Noperthedron example, including:

- chapter-local `set_option` conventions,
- Blueprint-specific options already in use,
- example values and known follow-ups.

## Current Repo-Level Doc Set

- `USER_MANUAL.md`
  - operational guide for validating and maintaining Blueprint support here
- `DESIGN_RATIONALE.md`
  - architecture, ownership boundaries, preview rationale, and graph-status rationale
- `ROADMAP.md`
  - active priorities, planned cleanup phases, and near-term implementation work

## Practical Reading Order

1. Start here for commands and artifact locations.
2. Read `DESIGN_RATIONALE.md` to understand why the implementation is shaped the
   way it is.
3. Read `ROADMAP.md` before starting structural refactors.
