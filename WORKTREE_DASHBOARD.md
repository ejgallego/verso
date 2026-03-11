# Worktree Dashboard

Last updated: 2026-03-11 (checkpointed staged cleanup plan for `feat/style-review-20260311`)

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

- Status: `active` (owner action: harden duplicate handling next, first within one module and then across imported Blueprint files)
- Summary: isolated review worktree for an audit of blueprint implementation quality. The review findings are now in hand, the repo-level Blueprint docs have been reshaped into a smaller three-document set under `doc/blueprint/`, and `@[blueprint]` export persistence is fixed. The next scheduled hardening pass is duplicate-identity handling: reject nested/duplicate local blocks earlier and detect imported collisions for labels, groups, and authors with explicit tests.
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
- Validation status:
  - setup complete: worktree created, root `.lake` copied, and `./script/lean-low-priority lake exe cache get` completed successfully
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/blueview-20260311/example-blueprints`
  - started shared `_out` preview server on `http://127.0.0.1:8155`
  - `./script/lean-low-priority lake build Tests.BlueprintAttribute`
  - `./script/lean-low-priority lake build Tests`
  - `./script/lean-low-priority lake build Tests.BlueprintInformal Tests.BlueprintImportedDuplicates.Direct Tests.BlueprintImportedDuplicates.Transitive`
  - `./script/lean-low-priority lake build Tests`
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
  - next implementation target remains preview-source duplication cleanup

### `feat/style-review-20260311`

- Status: `active` (owner action: execute the staged cleanup commits one slice at a time)
- Summary: isolated review worktree for blueprint styling organization. The audit is complete; next work is a staged cleanup preserving leanblueprint-compatible theorem wrapper/content classes while moving blueprint-owned styling toward a single Verso-aligned asset and component model.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/style-review-20260311`
- Branch: `feat/style-review-20260311`
- Base commit/branch:
  - branched from `bp` at `14e8157d`
- Key commits:
  - none yet
- Validation status:
  - setup complete: worktree created, root `.lake` copied, and `./script/lean-low-priority lake exe cache get` completed successfully
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/style-review-20260311/example-blueprints`
  - reused shared `_out` preview server on `http://127.0.0.1:8155`
  - review checkpoint: generated outputs inspected at the HTML level; duplicated inline asset injection, legacy-selector drift, weak interactive semantics, and dead selectors confirmed in the emitted site
  - asset-registration checkpoint validated after `698ceb47`:
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/style-review-20260311/example-blueprints`
  - emitted HTML now carries one copy of the style-switcher JS; summary/bibliography assets now load through the regular page asset block instead of inline block HTML
  - selector-boundary checkpoint validated after `6ddaf4ae`:
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/style-review-20260311/example-blueprints`
  - emitted HTML now carries `bp_style_*` / `bp_kind_*_*` selectors while preserving the legacy leanblueprint-compatible theorem/proof classes in parallel
  - semantic-controls checkpoint validated after `68073da2`:
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/style-review-20260311/example-blueprints`
  - emitted HTML now uses native `button` controls for multi-entry used-by/group panels and wires the graph “View” label to a real select id
  - dead-code checkpoint validated after `376b20bc`:
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/style-review-20260311/example-blueprints`
  - emitted HTML no longer contains the empty `bp_hiddenextras` placeholder or the dead `.bp_summary_preview` mobile rule; `Summary.lean` now carries a short note to force future `summary.css` edits through a module rebuild
  - shared-preview checkpoint validated after `b2979b45`:
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/style-review-20260311/example-blueprints`
  - graph and summary previews now share a common `bp_preview_panel*` chrome layer in both markup and CSS, while their existing graph/summary-specific hook classes remain in place for behavior and local sizing overrides
- Planned commit slices:
  - `1.` unify asset registration so each CSS/JS payload is added through one path only
  - `2.` preserve leanblueprint compatibility classes, but retarget blueprint-owned styling to primary `bp_*` selectors
  - `3.` tighten interactive HTML semantics (`button`, label/select wiring, keyboard behavior) without visual redesign
  - `4.` extract shared preview/panel primitives and remove dead selectors/placeholders
- Preview link:
  - `http://127.0.0.1:8155/style-review-20260311/example-blueprints/noperthedron/html-multi/`
  - `http://127.0.0.1:8155/style-review-20260311/example-blueprints/spherepackingblueprint/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/style-review-20260311`
  - inspect `src/verso-blueprint/VersoBlueprint/Informal/Block.lean`, `src/verso-blueprint/VersoBlueprint/StyleSwitcher.lean`, and `src/verso-blueprint/VersoBlueprint/Commands/{Graph,Summary,Bibliography}.lean`
  - compare generated HTML against Verso asset conventions and preserve leanblueprint-compatible wrapper/content class heritage where it still provides value
  - after each commit, rerun `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/style-review-20260311/example-blueprints` and compare:
  - `http://127.0.0.1:8155/style-review-20260311/example-blueprints/noperthedron/html-multi/`
  - `http://127.0.0.1:8155/style-review-20260311/example-blueprints/spherepackingblueprint/html-multi/`

## Recently Completed

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
