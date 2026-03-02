# Blueprint Graph Coloring Spec

This document describes the current coloring and warning logic implemented in `VersoBlueprint/Graph.lean`.

## 1. Inputs

Each node has:
- kind: `definition | lemma | theorem | corollary`
- optional informal statement/proof blocks and their dependency labels
- optional associated Lean code:
  - local literate block (`.literate`)
  - external declaration refs (`.external` from `(lean := "...")`)

External declaration status is provided by `ExternalCodeStatus`:
- `isMissing : Name -> Bool`
- `provedStatus : Name -> ProvedStatus`
  - `ProvedStatus = proved | axiomLike | containsSorry (Array SorryInfo)`

## 2. Dependency Graph Semantics

- Statement dependencies are rendered as regular edges.
- Definition-source dependencies are rendered as dashed edges.
- Proof-only dependencies are rendered as dotted edges.
- Missing dependency labels become synthetic unresolved nodes (`unknownRef := true`).

## 3. Status Tracks

Two status tracks are computed per node:

- Statement status (border color):
  - `blocked`
  - `ready`
  - `formalized`
  - `mathlib` (currently placeholder path)

- Proof/background status (fill color):
  - `none`
  - `ready`
  - `formalized`
  - `formalizedWithAncestors`

### 3.1 Local formalization predicates

A node is considered locally formalized only if:
- it has associated code, and
- it has no missing external declarations, and
- it has no relevant sorries:
  - statement track: no type sorries
  - proof track (theorem-like): no statement/type sorries and no proof sorries
  - declarations with no body (`axiom`) are treated as incomplete and count as both type/proof sorry

## 4. Warning Flags

Warnings are orthogonal overlays/markers:

- `unknownRef`: unresolved dependency label (special unresolved node style)
- `leanOnlyNoStatement`: code attached but no informal statement block
- `missingExternalDecl`: `(lean := "...")` declaration not found in environment (including lean-only nodes)
- `localSorries`: associated code has at least one sorry
- `depsWithSorries`: node is locally proof-formalized but ancestors are not all formalized

Note: `depsWithSorries` is historical naming; it indicates incomplete formalization ancestry, not necessarily literal sorries.

## 5. Visual Mapping

### 5.1 Border colors (statement)

- blocked: `#f59e0b`
- ready: `#2563eb`
- formalized: `#16a34a`
- mathlib: `#14532d`

### 5.2 Base fill colors (proof/background)

- none (theorem-like): `#f8fafc`
- none (definition): `#ffffff`
- ready: `#dbeafe`
- formalized: `#dcfce7`
- formalizedWithAncestors: `#166534`

### 5.3 Overlay precedence

For non-`unknownRef` nodes, one overlay can be added as a vertical gradient:
1. `leanOnlyNoStatement` (`#ede9fe`)
2. `missingExternalDecl` (`#fee2e2`)
3. `localSorries` (`#fef3c7`)

If none applies, the base fill is used.

### 5.4 Extra markers

- `depsWithSorries = true` -> double border (`peripheries = 2`)

## 6. Tooltip Contents

Tooltips include:
- statement status text
- proof status text
- warning strings for active flags

## 7. Environment Resolution Rule

For external declarations (`(lean := "...")`):
- user strings are parsed with `NameParsing.parseNameE`
- parsed names are resolved against the current namespace/open declarations via Lean's name-resolution machinery
- missing declaration is reported as `missingExternalDecl`
- missing declaration is **not** treated as `has sorry`
- if a parsed name is unresolved or ambiguous during resolution, a warning is emitted and the parsed name is kept as fallback

This avoids false positives like "contains sorries" when the declaration is simply unavailable in the current elaboration environment.

## 8. Known Gaps / Follow-ups

- The `mathlib` status path is stubbed in current implementation.
- Ambiguous external names currently fall back to the parsed name after warning; a future policy could prefer hard errors or explicit disambiguation syntax.
