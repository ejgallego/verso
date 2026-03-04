# Graph Status, Completion, and Coloring Specification

This document is the implementation-aligned specification for status/completion and graph coloring in `VersoBlueprint/Graph.lean`.

## 1. Scope

The graph pipeline computes two orthogonal tracks per node:

- Statement track (`StatementStatus`): drives border color.
- Proof/background track (`ProofStatus`): drives fill color.

Status is computed from:

- Informal node shape (`definition | lemma | theorem | corollary`),
- local code association (`.literate`, `.external`, or `.userOk`),
- per-declaration `ProvedStatus`,
- dependency closure completeness.

## 2. Canonical Completion Policy (Data API)

Completion blocking policy is centralized in `Informal.Data.ProvedStatus`:

- `blocksStatementCompletion (kind)`
- `blocksProofCompletion`
- `anyBlocksStatementCompletion (kind)`
- `anyBlocksProofCompletion`

### 2.1 Statement completion policy

- For `definition`: both statement/type and proof/body gaps block statement completion.
- For theorem-like kinds (`lemma`, `theorem`, `corollary`): only statement/type gaps block statement completion.

### 2.2 Proof completion policy

- Any statement/type or proof/body gap blocks proof completion.

This policy applies uniformly to both local literate declarations and external declaration snapshots (after conservative merge with environment state).

## 3. Graph-Level Predicates

`Graph.lean` derives:

- `nodeHasStatementSorries`
- `nodeHasProofSorries`
- `nodeHasSorries`
- `nodeLocalStatementFormalized`
- `nodeLocalProofFormalized`
- `nodeLocalFormalized`

A node is locally formalized only when:

- it has associated code,
- there are no missing external declarations,
- and relevant completion blockers (per track policy) are absent.

## 4. Dependency Closure

Dependency readiness is path-sensitive:

- statement status readiness checks statement dependencies,
- proof readiness checks statement and proof dependencies by traversal mode,
- ancestor-complete variant (`formalizedWithAncestors`) requires full recursive closure to be locally formalized.

## 5. Color and Warning Mapping

### 5.1 Statement border colors

- blocked: `#f59e0b`
- ready: `#2563eb`
- formalized: `#16a34a`
- mathlib: `#14532d`

### 5.2 Proof/background fill colors

- none (theorem-like): `#f8fafc`
- none (definition): `#ffffff`
- ready: `#dbeafe`
- formalized: `#dcfce7`
- formalizedWithAncestors: `#166534`

### 5.3 Overlay precedence

Single overlay precedence (top to bottom):

1. `leanOnlyNoStatement` (`#ede9fe`)
2. `missingExternalDecl` (`#fee2e2`)
3. `localSorries` (`#fef3c7`)

### 5.4 Additional markers

- unresolved dependency nodes (`unknownRef`) use dedicated unresolved palette,
- `depsWithSorries` uses `peripheries = 2` (double border).

## 6. Informal Heading/Code Summary Coupling

Informal block heading status uses the same statement-track completion policy via `ProvedStatus.anyBlocksStatementCompletion`.

Proof block payloads currently carry no code metadata by type design (`BlockData.kind = none`), so Lean code summary parts are only produced for statement blocks.

## 7. Validation and Test Coverage

Current regression coverage includes:

- per-kind statement/proof completion policy matrix,
- definition regression: proof-gap-only status blocks definition statement completion,
- theorem regression: helper definition proof gaps block theorem proof completion,
- theorem statement/proof separation behavior.

Coverage is broad but not exhaustive. Remaining non-exhaustive areas include:

- full cross-product of external/local mixed statuses with deep dependency closure,
- UI tooltip/assertion-level checks for every warning + overlay combination.
