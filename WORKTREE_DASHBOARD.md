# Worktree Dashboard

Last updated: 2026-03-12 (validated split `Tests.BlueprintSummaryLinks` modules in `feat/blueprint-tests-consolidation-20260311`)

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

### `feat/blueprint-tests-consolidation-20260311`

- Status: `ready-for-review` (owner action: review whether this cleanup level is sufficient or whether we want one final conventions/documentation pass before merge prep)
- Summary: isolated cleanup worktree for the organically-grown blueprint tests. The major blueprint-specific monoliths now all follow the same pattern: shared harness helpers plus thin umbrella modules over smaller scenario-focused files.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/blueprint-tests-consolidation-20260311`
- Branch: `feat/blueprint-tests-consolidation-20260311`
- Base commit/branch:
  - branched from `bp` at `951d8fae`
- Key commits:
  - `853a52d7` refactor(tests): consolidate blueprint test support
  - `2cc0f73e` refactor(tests): split blueprint preview wiring scenarios
  - `862efb1c` refactor(tests): split blueprint graph and informal scenarios
  - `f4a79495` refactor(tests): split blueprint summary link scenarios
- Validation status:
  - setup complete: worktree created, root `.lake` copied, and `script/lean-low-priority lake exe cache get` completed successfully
  - `script/lean-low-priority lake build Tests.Blueprint.Support Tests.BlueprintLinkHover Tests.BlueprintMetadataPanel Tests.BlueprintSummaryLinks Tests.BlueprintPreviewWiring Tests.BlueprintExternalHeadingStatus Tests.BlueprintTexMacros Tests`
  - `script/lean-low-priority lake build Tests.Blueprint.Support Tests.Blueprint Tests`
  - `script/lean-low-priority lake build Tests.BlueprintPreviewWiring.Shared Tests.BlueprintPreviewWiring.Summary Tests.BlueprintPreviewWiring.Graph Tests.BlueprintPreviewWiring.UsedBy Tests.BlueprintPreviewWiring.LeanStatus Tests.BlueprintPreviewWiring Tests.Blueprint Tests`
  - `script/lean-low-priority lake build Tests.BlueprintInformal.Shared Tests.BlueprintInformal.LeanRefs Tests.BlueprintInformal.Structure Tests.BlueprintInformal Tests.BlueprintGraph.Shared Tests.BlueprintGraph.Basics Tests.BlueprintGraph.NodeStatus Tests.BlueprintGraph.Legend Tests.BlueprintGraph.Groups Tests.BlueprintGraph Tests.Blueprint Tests`
  - `script/lean-low-priority lake build Tests.BlueprintSummaryLinks.Shared Tests.BlueprintSummaryLinks.External Tests.BlueprintSummaryLinks.Blockers Tests.BlueprintSummaryLinks.Triage Tests.BlueprintSummaryLinks Tests.Blueprint Tests`
  - `script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/blueprint-tests-consolidation-20260311/example-blueprints`
  - reran `script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/blueprint-tests-consolidation-20260311/example-blueprints` after the preview-wiring split
  - reran `script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/blueprint-tests-consolidation-20260311/example-blueprints` after the graph/informal split
  - reran `script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/blueprint-tests-consolidation-20260311/example-blueprints` after the summary-links split
  - started shared `_out` preview server on `http://127.0.0.1:8155`
- Preview link:
  - `http://127.0.0.1:8155/blueprint-tests-consolidation-20260311/example-blueprints/noperthedron/html-multi/`
  - `http://127.0.0.1:8155/blueprint-tests-consolidation-20260311/example-blueprints/spherepackingblueprint/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/blueprint-tests-consolidation-20260311`
  - inspect `src/tests/Tests/Blueprint.lean` and `src/tests/Tests/Blueprint/Support.lean` first; that is now the suite entry point and shared renderer harness
  - `src/tests/Tests/BlueprintPreviewWiring.lean`, `src/tests/Tests/BlueprintGraph.lean`, `src/tests/Tests/BlueprintInformal.lean`, and `src/tests/Tests/BlueprintSummaryLinks.lean` are now umbrella imports; inspect their sibling directories for the scenario files
  - `git show --stat f4a79495`

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

## Recently Completed

- Merged `feat/blueview-20260311` into `bp` (`7eb36503 -> 8226ab97`, fast-forward).
- Feature branch key commits:
  - `45fb17bc` docs(blueprint): adopt manual rationale roadmap layout
  - `9e3017b3` fix(blueprint): persist attribute-registered nodes
  - `294df5b2` test(blueprint): expand attribute persistence coverage
  - `0ba1b5d0` fix(blueprint): harden duplicate identity handling
  - `629ae567` refactor(preview): unify preview source path
  - `28469aa0` refactor(status): share blueprint status evaluation
  - `378b2c1f` feat(summary): streamline zero-state sections
  - `1d8ec63f` test(preview): relax preview wiring invariants after shared runtime cleanup
- Validation on rebased feature branch:
  - `./script/lean-low-priority lake build Tests`
  - `./script/lean-low-priority ./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/blueview-20260311/example-blueprints`
- Cleanup authorized and completed:
  - remove worktree `/home/egallego/lean/verso-blueprint/.worktrees/blueview-20260311`
  - delete branch `feat/blueview-20260311`
  - remove preview artifacts `/home/egallego/lean/verso-blueprint/_out/blueview-20260311`
  - shared `_out` server was already not running; no stop action needed

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
