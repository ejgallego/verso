# Worktree Dashboard

Last updated: 2026-03-11 (merged and cleaned up `feat/preview-manifest-cli-20260311`)

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
  - none yet
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

### `feat/lean-code-link-preview-api-20260311`

- Status: `active` (owner action: introduce a canonical Lean-code link API, switch existing Lean-link call sites onto it, then add hover preview through that single path)
- Summary: new feature worktree for unifying Lean-code linking across code summary surfaces and blueprint summary views behind one API, with shared hover preview behavior layered on top.
- Path: `/home/egallego/lean/verso-blueprint/.worktrees/lean-code-link-preview-api-20260311`
- Branch: `feat/lean-code-link-preview-api-20260311`
- Base commit/branch:
  - branched from `bp` at `c45986f8`
- Key commits:
  - none yet
- Validation status:
  - setup complete: worktree created, root `.lake` copied, and `lake exe cache get` run
  - `./generate-example-blueprints.sh /home/egallego/lean/verso-blueprint/_out/lean-code-link-preview-api-20260311/example-blueprints`
  - `lake exe noperthedron --output /home/egallego/lean/verso-blueprint/_out/lean-code-link-preview-api-20260311/noperthedron`
- Preview link:
  - `http://127.0.0.1:8156/lean-code-link-preview-api-20260311/noperthedron/html-multi/`
  - `http://127.0.0.1:8156/lean-code-link-preview-api-20260311/example-blueprints/noperthedron/html-multi/`
- Resume commands/notes:
  - `cd /home/egallego/lean/verso-blueprint/.worktrees/lean-code-link-preview-api-20260311`
  - `git status --short`
  - inspect `src/verso-blueprint/VersoBlueprint/Resolve.lean`, `src/verso-blueprint/VersoBlueprint/Informal/CodeSummary.lean`, `src/verso-blueprint/VersoBlueprint/Commands/Summary.lean`, `src/verso-blueprint/VersoBlueprint/Informal/Block.lean`

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
