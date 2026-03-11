# Worktree Dashboard

Last updated: 2026-03-11 (merged and cleaned up `feat/style-review-20260311`)

## Active Worktrees

### `bp` (root checkout)

- Status: `active` (owner action: monitor follow-up builder-boundary work)
- Summary: integration baseline branch with recent commands-path and renderer refactors already validated for `noperthedron`.
- Path: `/home/egallego/lean/verso-blueprint`
- Branch: `bp`
- Base commit/branch:
  - local integration branch
- Key commit:
  - `b579013b` informal: harden block parsing and extract group directive
- Validation status:
  - commands-path validation passed before merge:
  - `lake build VersoBlueprint.Commands.Common VersoBlueprint.Commands.Graph VersoBlueprint.Commands.Summary VersoBlueprint.Commands.Bibliography VersoBlueprint`
  - `./generate-example-blueprints.sh`
- Resume commands/notes:
  - `git status --short`
  - `git log --oneline -1`

### `feat/lean-lean-interactive-latency-20260310`

- Status: `active` (owner action: implement the interactive fast path and document the interactive-vs-batch behavior in the user guide)
- Summary: review worktree focused on `src/verso-blueprint/VersoBlueprint/Lean.lean`, where interactive elaboration still unconditionally builds highlighted Lean blocks and declaration metadata even though core editor LSP features appear to read from syntax and info trees. The task now also includes documenting the resulting behavior in the manual.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/lean-lean-interactive-latency-20260310`
- Branch: `feat/lean-lean-interactive-latency-20260310`
- Base commit/branch:
  - branched from `bp` at `2a11a8f9`
- Key commits:
  - `b2979b45` refactor(preview): share panel chrome
  - `376b20bc` chore(style): remove dead blueprint placeholders
  - `68073da2` fix(html): use native blueprint controls
  - `6ddaf4ae` refactor(style): promote bp selector surface
  - `698ceb47` refactor(style): unify blueprint asset registration
- Validation status:
  - setup complete: worktree created, root `.lake` copied, and `lake exe cache get` completed successfully
  - `./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/lean-lean-interactive-latency-20260310/example-blueprints`
  - reused shared `_out` preview server on `http://127.0.0.1:8154`
- Preview link:
  - `http://127.0.0.1:8154/lean-lean-interactive-latency-20260310/example-blueprints/noperthedron/html-multi/`
  - `http://127.0.0.1:8154/lean-lean-interactive-latency-20260310/example-blueprints/spherepackingblueprint/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/lean-lean-interactive-latency-20260310`
  - inspect `src/verso-blueprint/VersoBlueprint/Lean.lean`, `src/verso-blueprint/VersoBlueprint/Informal/Code.lean`, `src/verso/Verso/Doc/Lsp.lean`, and `doc/UsersGuide/Elab.lean`
  - likely change shape: thread an explicit interactive flag from outer `Command.Context.snap?` into `DocElabContext`, then gate highlight generation and declaration analysis in blueprint Lean blocks
  - manual target: record that interactive Lean editing uses a latency-oriented fast path while batch builds still run full highlighting and blueprint analysis

### `feat/lean-commandm-incremental-20260306`

- Status: `active` (owner action: retest editor UX from the reverted “best current” checkpoint and decide whether a true incremental elaborator is still needed)
- Summary: blueprint Lean fences currently keep doc-side prefix reuse plus outer incremental Verso block commands, while declaration analysis/highlighting/output capture remain disabled for latency. The later full reuse-history fence tree was reverted after regressing UX.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/lean-commandm-incremental-20260306`
- Branch: `feat/lean-commandm-incremental-20260306`
- Base commit/branch:
  - merge-base with `bp`: `ec3cf1ec` (`1` behind / `17` ahead)
- Key commits:
  - `d94efa46` Revert "feat(blueprint): preserve reuse history in fence snapshot tree"
  - `a430f8e0` feat(verso): mark incremental doc blocks as reusable
  - `7719853e` feat(blueprint): add inner fence command snapshots
  - `07d3c604` perf(blueprint): trim fence latency further
- Validation status:
  - `lake build VersoBlueprint.Lean VersoBlueprint.Informal.Code`
  - `lake build Verso.Doc.Concrete VersoManual.Literate VersoBlueprint.Lean VersoBlueprint.Informal.Code`
  - `lake exe noperthedron --output /home/egallego/lean/verso-blueprint/_out/lean-commandm-incremental-20260306` (passed; existing Noperthedron warnings only)
  - note: `lake build Tests` still fails at `Tests.BlueprintInlinePrecision` because blueprint code-block analysis is intentionally disabled in this experiment
- Preview link:
  - `http://127.0.0.1:8152/lean-commandm-incremental-20260306/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/lean-commandm-incremental-20260306`
  - `git log --oneline --decorate -6`
  - inspect `src/verso/Verso/Doc/Concrete.lean`, `src/verso/Verso/Doc/Elab/Monad.lean`, `src/verso-blueprint/VersoBlueprint/Lean.lean`

### `feat/lsp-folding-chain`

- Status: `active` (owner action: rebase before integration)
- Summary: long-running folding-chain refactor with substantial local progress but significant drift from `bp`.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/lsp-folding-chain`
- Branch: `feat/lsp-folding-chain`
- Base commit/branch:
  - merge-base with `bp`: `07af066c` (`60` behind / `28` ahead)
- Key commit:
  - `4cafd289` verso: cleanup folding metadata plumbing and dedupe helpers
- Validation status:
  - worktree currently clean
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/lsp-folding-chain`
  - `git status --short`
  - `git rebase bp`

### `feat/blueview-20260311`

- Status: `active` (owner action: polish the summary UI now that status evaluation is centralized)
- Summary: isolated review worktree for an audit of blueprint implementation quality. The core cleanup passes are now in place: the repo-level docs were consolidated, `@[blueprint]` export persistence was fixed, duplicate identity handling was hardened, preview sources were unified, and status evaluation was centralized. The current phase is summary polish: hide zero-value sections, consolidate blocker reporting, and reduce duplicated theorem/group views.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/blueview-20260311`
- Branch: `feat/blueview-20260311`
- Base commit/branch:
  - branched from `bp` at `57ebc3a7`
- Key commits:
  - `bfa10976` docs(blueprint): centralize blueprint docs
  - `af681591` docs(blueprint): condense overlapping notes
  - `6349d4d6` fix(blueprint): persist attribute-registered nodes
  - `815b6600` test(blueprint): expand attribute persistence coverage
  - `f2f6e2a4` fix(blueprint): harden duplicate identity handling
  - `e3538ae3` refactor(preview): unify preview source path
  - `d8ffb462` refactor(status): share blueprint status evaluation
  - `0a22802e` feat(summary): streamline zero-state sections
- Validation status:
  - setup complete: worktree created, root `.lake` copied, and `./script/lean-low-priority lake exe cache get` completed successfully
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/blueview-20260311/example-blueprints`
  - started shared `_out` preview server on `http://127.0.0.1:8155`
  - `./script/lean-low-priority lake build Tests.BlueprintAttribute`
  - `./script/lean-low-priority lake build Tests`
  - `./script/lean-low-priority lake build Tests.BlueprintInformal Tests.BlueprintImportedDuplicates.Direct Tests.BlueprintImportedDuplicates.Transitive`
  - `./script/lean-low-priority lake build Tests`
  - `./script/lean-low-priority lake build VersoBlueprint.Lib.PreviewSource VersoBlueprint.Widget VersoBlueprint.Informal.Block VersoBlueprint.PreviewRender`
  - `./script/lean-low-priority lake build Tests.BlueprintPreviewSource Tests.BlueprintTexMacros`
  - `./script/lean-low-priority lake build Tests`
  - `./script/lean-low-priority lake build VersoBlueprint.Graph VersoBlueprint.Informal.CodeSummary VersoBlueprint.Commands.Summary VersoBlueprint.Informal.Block`
  - `./script/lean-low-priority lake build Tests.BlueprintGraph Tests.BlueprintSummaryStatus Tests.BlueprintExternalHeadingStatus Tests.BlueprintMetadataPanel Tests.BlueprintSummaryLinks`
  - `./script/lean-low-priority lake build Tests`
  - `./script/lean-low-priority lake build Tests.BlueprintSummaryLinks Tests.BlueprintMetadataPanel Tests.BlueprintPreviewWiring`
  - `./script/lean-low-priority lake build Tests`
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/blueview-20260311/example-blueprints`
- Preview link:
  - `http://127.0.0.1:8155/blueview-20260311/example-blueprints/noperthedron/html-multi/`
  - `http://127.0.0.1:8155/blueview-20260311/example-blueprints/spherepackingblueprint/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/blueview-20260311`
  - inspect `src/verso-blueprint/VersoBlueprint`, `doc/`, and `test-projects/Noperthedron`
  - review findings already captured in chat; `doc/blueprint/` now contains `USER_MANUAL.md`, `DESIGN_RATIONALE.md`, and `ROADMAP.md`
  - `USER_MANUAL.md` is the operational entry point; `DESIGN_RATIONALE.md` absorbs the old preview/graph rationale docs; `ROADMAP.md` holds live cleanup sequencing
  - `@[blueprint]` export persistence is fixed and now covered by a broader `Tests.BlueprintAttribute` matrix:
  - direct + transitive import path, imported `data` vs `localData`, code origin/kind, and documented vs undocumented declarations
  - duplicate-identity hardening is now implemented:
  - local scope: nested/duplicate block rejection now happens before stack mutation
  - imported scope: cross-module collision detection now records and reports duplicate nodes, groups, and authors
  - regression coverage includes direct + transitive imported collisions plus local duplicate/nesting checks
  - preview-source duplication cleanup is now implemented:
  - persistent node payloads now store preview blocks, and `PreviewSource` renders from preview blocks first with syntax fallback only when needed
  - widget preview and imported preview regressions now cover the unified preview path
  - shared status evaluation is now implemented:
  - graph, summary, and local code-summary heading status all consume the same `Graph.CodeHealth` evaluation path
  - summary polish is now implemented on top of the centralized status logic:
  - zero-value warning/secondary cards are hidden by default
  - Lean blockers are consolidated under one blockers section with nested detail filters
  - theorem-by-parent is now a secondary nested view under the main theorem index
  - the next implementation target should come from the remaining roadmap items after this pass

## Recently Completed

- Merged `feat/style-review-20260311` into `bp` (`e3468db1 -> 21374533`, fast-forward).
- Feature branch key commits:
  - `4673b384` refactor(style): unify blueprint asset registration
  - `719713d9` refactor(style): promote bp selector surface
  - `5607dd0a` fix(html): use native blueprint controls
  - `fd04c5da` chore(style): remove dead blueprint placeholders
  - `96a5bcca` refactor(preview): share panel chrome
  - `aad8b535` refactor(style): add blueprint design tokens
  - `21374533` refactor(style): share asset bundles and semantic tokens
- Validation on merged feature head:
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/style-review-20260311/example-blueprints`
- Cleanup authorized and completed:
  - remove worktree `/home/egallego/lean/verso-blueprint/.worktrees/style-review-20260311`
  - delete branch `feat/style-review-20260311`
  - remove preview artifacts `/home/egallego/lean/verso-blueprint/_out/style-review-20260311`
  - shared `_out` server was already not running; no stop action needed

- Merged `feat/lean-code-link-preview-api-20260311` into `bp` (`4f0d4bb0 -> 6e7eabc3`, fast-forward).
- Feature branch key commits:
  - `c09e7475` feat(blueprint): add lean code link preview api
  - `953fe7e0` refactor(preview): instrument lean declaration links
  - `06afbe97` refactor(preview): dedupe lean declaration preview keys
  - `65b80ca5` fix(preview): keep manifest schema aligned after rebase
- Validation on merged feature head:
  - `./script/lean-low-priority lake build Tests.BlueprintPreviewWiring Tests.BlueprintSummaryLinks`
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/lean-code-link-preview-api-20260311/example-blueprints`
  - `uv run --project browser-tests --extra test python -m pytest browser-tests/test_preview_runtime_regressions.py -q --site-dir /home/egallego/lean/verso-blueprint/_out/lean-code-link-preview-api-20260311/example-blueprints/noperthedron/html-multi`
- Cleanup authorized and completed:
  - remove worktree `/home/egallego/lean/verso-blueprint/.worktrees/lean-code-link-preview-api-20260311`
  - delete branch `feat/lean-code-link-preview-api-20260311`
  - remove preview artifacts `/home/egallego/lean/verso-blueprint/_out/lean-code-link-preview-api-20260311`
  - keep shared server running for other active worktrees

- Merged `feat/preview-manifest-cli-20260311` into `bp` (`4997ab44 -> 98cc88d9`, fast-forward).
- Feature branch key commit:
  - `98cc88d9` feat(preview): add manifest dump cli
- Validation on merged feature head:
  - `./script/lean-low-priority lake build VersoBlueprint.PreviewManifest Tests.BlueprintPreviewSchema Main SpherePackingBlueprintMain`
  - `./script/lean-low-priority lake exe noperthedron --help`
  - `./script/lean-low-priority lake exe noperthedron --dump-schema`
  - `./script/lean-low-priority lake exe noperthedron --dump-manifest`
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/preview-manifest-cli-20260311/example-blueprints`
  - `uv run --project browser-tests --extra test python -m pytest browser-tests/test_preview_runtime_regressions.py -q --site-dir /home/egallego/lean/verso-blueprint/_out/preview-manifest-cli-20260311/example-blueprints/noperthedron/html-multi`
- Cleanup authorized and completed:
  - remove worktree `/home/egallego/lean/verso-blueprint/.worktrees/preview-manifest-cli-20260311`
  - delete branch `feat/preview-manifest-cli-20260311`
  - remove preview artifacts `/home/egallego/lean/verso-blueprint/_out/preview-manifest-cli-20260311`
  - keep shared server session `33154` running

- Merged `feat/preview-manifest-hardening-20260311` into `bp` (`c0e8b0d6 -> 5c2a34b8`, fast-forward).
- Feature branch key commits:
  - `256a933f` fix(preview): auto-emit and harden shared manifest
  - `8765166e` feat(preview): enrich manifest metadata schema
  - `5c2a34b8` docs(preview): remove implementation-detail label wording
- Validation on rebased feature branch:
  - `./script/lean-low-priority lake build VersoBlueprint.PreviewManifest Tests.BlueprintPreviewSchema Main SpherePackingBlueprintMain`
  - `./script/lean-low-priority lake env lean src/tests/Tests/BlueprintPreviewSchema.lean`
  - `./script/lean-low-priority lake env lean src/tests/Tests/BlueprintPreviewWiring.lean`
  - `./script/lean-low-priority lake exe noperthedron --dump-schema`
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/preview-manifest-hardening-20260311/example-blueprints`
  - `uv run --project browser-tests --extra test python -m pytest browser-tests/test_preview_runtime_regressions.py -q --site-dir /home/egallego/lean/verso-blueprint/_out/preview-manifest-hardening-20260311/example-blueprints/noperthedron/html-multi`
- Cleanup authorized and completed:
  - remove worktree `/home/egallego/lean/verso-blueprint/.worktrees/preview-manifest-hardening-20260311`
  - delete branch `feat/preview-manifest-hardening-20260311`
  - remove preview artifacts `/home/egallego/lean/verso-blueprint/_out/preview-manifest-hardening-20260311`
