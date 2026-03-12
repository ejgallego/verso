# DASHBOARD

## Operating Notes

- This dashboard is the shared coordination surface for the manager agent and human.
- Keep one entry per worktree and one worktree per active local branch.
- Branch/worktree coverage is complete right now: all local branches have a worktree.
- Task order is a strict queue: execute from top to bottom.
- Default policy: always attack the first task in `Tasks Ongoing`.
- Exception: start from `Tasks Planned` only when the user/manager explicitly directs it.
- For `Tasks Planned`, omit validation details unless non-standard validation is needed.
- `Decision:` is a special user-controlled field that sets next step for a task.
- `Decision: pending` means the task is blocked and not a candidate for action.
- When an agent starts a task, it removes that task's `Decision:` field.
- Special status `locked` means an agent is actively working on that task.
- Commit and PR messages must follow `COMMIT_CONVENTION.md`.
- If a branch has one commit, PR title/body are derived from the commit message.
- If a branch has multiple commits, the corresponding task entry must include explicit `PR Title` and `PR Body` before PR submission.
- Status tags:
  - `needs: rebase`: branch has an open PR and should be rebased/synced with `upstream/main`.
  - `needs: progress`: no open PR yet; work is still local/draft.
  - `needs: decision`: non-standard state (coordination branch, detached worktree, or baseline mirror).
  - `needs review from human`: branch work is ready for human review/approval.
  - `pending on human action`: task is paused until explicit human follow-up.
  - `special`: management/baseline worktree entry (not an implementation task).
  - `locked`: task is currently being executed by an agent.
- PR mapping below uses the last successful GitHub query from this session. Re-run `gh api repos/leanprover/verso/pulls --paginate` when network is available.

## Task Entry Format

- Planned task format:
```markdown
- [ ] `<task title>`
  - Scope: `<where change applies>`
  - Observation: `<what we saw>`
  - Impact: `<why it matters>`
  - Proposed fix: `<intended change>`
  - Expected effort: `<small|medium|large + note>`
  - Status: `<needs: ...>`
  - Decision: `<user-provided next step>`
```

- Ongoing task format:
```markdown
- [ ] `<branch or task>`
  - Path: `<absolute worktree path>`
  - Status: `keep (<needs: ...>)` or `keep (pending on human action)` or `special` or `locked`
  - Decision: `<user-provided next step>`   # `pending` blocks action; removed by agent when task is being executed
  - PR Title: `<required before PR submission when branch has >1 commit>`
  - PR Body: `<required before PR submission when branch has >1 commit>`
  - PR: `<#id + url>` or `none` or `n/a`
  - Ahead/Behind vs `upstream/main`: `+X/-Y`   # optional
  - Summary: `<one-line branch summary>`
  - Notes: `<state and special context>`
```

## Tasks Planned (Not Started)

- [ ] `Concrete.lean` task A: remove duplicate genre resolution in `verso` term elaboration.
  - Scope: `/home/egallego/lean/verso/src/verso/Verso/Doc/Concrete.lean` around the `elab_rules : term` for `verso`.
  - Observation: `findGenreTm` is called twice on the same explicit genre path.
  - Impact: redundant resolution/info work and avoidable noise in elaboration traces.
  - Proposed fix: keep a single `findGenreTm` call in the `some g` branch and remove the extra pre-pass.
  - Expected effort: small (about 5 lines, low risk).
  - Status: `needs: progress`.
  - Decision: pending (set by user)

- [ ] `Concrete.lean` task B: make incremental `#doc` ref-info emission linear.
  - Scope: `/home/egallego/lean/verso/src/verso/Verso/Doc/Concrete.lean` in `runVersoBlock`/`saveRefsInEnv` and environment threading.
  - Observation: incremental mode re-pushes all ref custom info each block; current behavior trends quadratic in top-level block count.
  - Impact: unnecessary elaboration overhead for larger docs and noisier info trees.
  - Proposed fix: track emitted ref progress in `DocElabEnvironment` and push only newly added def/use syntax per ref key.
  - Expected effort: medium (state extension + delta computation + regression checks).
  - Status: `needs: progress`.
  - Decision: pending (set by user)

## Tasks Ongoing (Branch + Worktree)

### Local experiments

- [ ] `review/vir-a-dependency`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-a-dependency`
  - Status: `keep (needs review from human)`
  - PR: none
  - Ahead/Behind vs frozen Verso base `22f6fe34`: `+1/-0`
  - Summary: add only the isolated Lean 4.33 VIR dependency shared by every review lane.
  - Notes: final reconciliation `SLIDES-VERSO-20260827-006` classifies A-F as runtime-only because these lanes build `+VersoSearchVir.Runtime:vir` and `:virSdk`, not `@:virWebAssets`. The accidental A-F `a5e6d2f...` claim in `VERSO-SLIDES-20260827-013/-014` is superseded by canonical reconciliation `VERSO-SLIDES-20260827-015`; final exact-head clarification restores the newer corrected graph and supersedes the temporary historical-head restoration in `VERSO-SLIDES-20260827-027`. Lane A is repinned, rebuilt, and force-published as `6b14a7f7` at merged VIR PR #152 commit `40f2e3d02b6f7b5ca8026bd44e65bd99283c6c57`; rejected `a6be232...` and application-level `a5e6d2f...` are absent from the complete graph. Root `lake build` and `lake test`, the isolated package build, and the five-job commit-addressed SDK installation all pass. Lane B documents `VIR_SDK_COMMIT=40f2e3d...`. Do not repin A-F when PR #161 merges unless these lanes are explicitly converted to `virWebAssets`; the separate Slides application owns that shared-assets transition. Review only this common base at <https://github.com/ejgallego/verso/compare/22f6fe34...review/vir-a-dependency>.

- [ ] `review/vir-b-core`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-b-core`
  - Status: `keep (needs review from human)`
  - PR: none
  - Ahead/Behind vs `review/vir-a-dependency`: `+1/-0`
  - Summary: add the host-independent Lean xref mapping and ranking core plus the narrow VIR runtime exports.
  - Notes: rebased and force-published as `8d7684ca`. Root `lake build` and `lake test`, the 75-job/21-member VIR package build, exact commit-addressed `40f2e3d...` SDK installation, Node smoke, and differential benchmark all pass. Lane B remains the smallest existing Verso contribution for the joint one-runtime pilot, but Slides consumes only its normal-package source: pin normal package `verso` to exact `8d7684ca846d94e40d8a307abc015949e3b977a0` and import `VersoSearch.ExperimentalRanking`. Do not depend on `experiments/vir-search`, so its runtime-only `40f2e3d...` dependency never enters the application graph. Final narrowed-scope consumer acceptance `VERSO-SLIDES-20260827-033` supersedes the pending-rerun status in `-032`: exact public PR #161 head `a1dab8b404280289a720374b59de5873f405294d` with published Slides head `17dfdb6447a5aed7ed609d47af42e8d52a1fb649` is now the current accepted pair, with matching local/fork refs. Incremental TypeScript, 24 configuration tests, seven pretty tests, demo/facet generation, and all 286 Chromium/Firefox tests pass. A fresh detached in-workspace empty-`.lake` run explicitly unset every SDK override, cloned exact dependencies, built the source SDK, named `@/«vir-prettym»:virWebAssets`, and demo, then passed typed prettyM styling/reload smoke in a fresh browser. The manifest records `a1dab8b...`; the full composed app closure is 1.4 MB/39 files, containing combined `vir-host-bindings.js` while excluding split `vir-browser-host-bindings.js`, debug Wasm, `vir-runtime-node.js`, and the external browser-React entrypoint, with statically reached React internals retained. `a5e6d2f...` remains the first historical acceptance, `f373461...` plus `361f91e` the later pre-polish accepted predecessor, and scope-retired `c20162f...` historical non-consumable evidence. The exact PR #161 merge commit is now the sole remaining application repin and bounded compatibility check. The earlier narrow Slides review head is `361f91e` on `feat/vir-prettym-integration`; `ccc50be` and `4648163` are superseded branch heads; `a5e6d2f...` remains the historical first clean-consumer revision, while `f373461...` plus `361f91e` is the later accepted pair. PR #161 exact proof head `85b2e19bcf659b9c7945001a39294df6fbd0db28` additionally completes the committed cross-package mechanism proof: one explicit `App.Root`, descriptor members `Dep.Contribution` plus `App.Root`, root-only export/startup promotion, one `createRuntime`, both contribution results, idempotent root-owned startup, and one disposal. Its docs record the wrapper/non-promotion contract; no runtime primitive was added. CI run `33023516149` is green across `build-demo`, `runtime`, `fixtures`, and `runtime-lean`, with explicit `PASS cross-package-one-runtime`; the Chromium launch issue did not recur. The browser-visible two-package/one-live-runtime acceptance is now replayed and closed on the narrowed PR #161 API by `VERSO-SLIDES-20260827-036`. Published Slides branch `feat/vir-verso-single-runtime` has production commit `6b1643d` and test/docs head `badac3745ac235ef740925ca32904b561f0bf669`, based on `feat/vir-prettym-integration` `17dfdb6447a5aed7ed609d47af42e8d52a1fb649`; local and fork refs match. Exact pins are VIR `a1dab8b404280289a720374b59de5873f405294d` and normal Verso lane B `8d7684ca846d94e40d8a307abc015949e3b977a0`. The sole `VersoSlides.VirPrettyM` root exports `formatSegments` and `rankSearchCandidates`; its descriptor has eight members, 135 declarations, and two exports, including both `VersoSearch.ExperimentalRanking` and `VersoSlides.Pretty`. Bootstrap uses `createVirWebAssetsRuntime`, with no legacy `runtime.js` or static-JSON tests. TypeScript, 24 configuration tests, seven pretty tests, and all 286 Chromium/Firefox browser tests pass. A fresh empty-`.lake` run with every VIR SDK override unset cloned exact pins, built the source SDK, facet, and demo, then displayed the Verso ranking and styled Slides proof panel through the same `window.versoVir`; lifecycle instrumentation records `create,startup` followed by `dispose,create,startup` across reload. The full composed application bundle is 1.4 MB across 40 files. Historical pilot head `1ea2d7f3...` is superseded by `badac374...`. No CI, composition, VIR API, or consumer blocker remains. The sole dependency transition left is to PR #161's exact merge commit after it lands. The 135-line host-independent module has no VIR, JSON, DOM, or startup dependency. A thin root-owned `@[vir_export]` wrapper calls `Verso.Search.ExperimentalVIR.rankCandidates`, compiling that Verso code into the Slides root's sole package set; Slides remains the sole `virWebAssets` program and lifecycle owner. Lane F remains the visible full-Lean follow-up. Review the shared semantic core once at <https://github.com/ejgallego/verso/compare/review/vir-a-dependency...review/vir-b-core>.

- [ ] `review/vir-c-js-provider`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-c-js-provider`
  - Status: `keep (needs review from human)`
  - PR: none
  - Ahead/Behind vs `review/vir-b-core`: `+1/-0`
  - Summary: keep Verso's existing JavaScript control flow and rendering while optionally delegating mapping and ranking to VIR.
  - Notes: rebased and force-published as `05835479`. Root `lake build` and `lake test`, the 75-job/21-member VIR package build, exact commit-addressed `40f2e3d...` SDK installation, Node smoke, and all six freshly restaged provider tests in Chromium and Firefox pass. Review this conservative integration independently at <https://github.com/ejgallego/verso/compare/review/vir-b-core...review/vir-c-js-provider>.

- [ ] `review/vir-d-full-lean-dom`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-d-full-lean-dom`
  - Status: `keep (needs review from human)`
  - PR: none
  - Ahead/Behind vs `review/vir-b-core`: `+1/-0`
  - Summary: provide the faithful full-Lean reference that clears and rebuilds result DOM nodes for every query.
  - Notes: rebased and force-published as `f0f3c848`. Root `lake build` and `lake test`, the 76-job/42-member VIR package build, exact commit-addressed `40f2e3d...` SDK installation, Node smoke, and the freshly restaged 295-entry generated-site browser differential pass. One current Chromium run completed 18 queries at an 8.7 ms median and 23.4 ms maximum; treat these timings as bounded evidence, not a cross-machine claim. Review the uncached full-Lean reference at <https://github.com/ejgallego/verso/compare/review/vir-b-core...review/vir-d-full-lean-dom>.

- [ ] `review/vir-e-innerhtml-cache`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-e-innerhtml-cache`
  - Status: `keep (needs review from human)`
  - PR: none
  - Ahead/Behind vs `review/vir-d-full-lean-dom`: `+1/-0`
  - Summary: cache safely escaped result HTML and replace the result subtree with one `innerHTML` host operation.
  - Notes: rebased and force-published as `606f788b`. Root `lake build` and `lake test`, the 76-job/43-member VIR package build, exact commit-addressed `40f2e3d...` SDK installation, Node smoke, and the freshly restaged 295-entry generated-site browser differential pass. One current Chromium run completed 21 queries at a 1.0 ms median and 17.5 ms maximum; retain the earlier balanced profiling only as historical design evidence. Review only the escaped-HTML alternative at <https://github.com/ejgallego/verso/compare/review/vir-d-full-lean-dom...review/vir-e-innerhtml-cache>.

- [ ] `review/vir-f-subtree-cache`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-f-subtree-cache`
  - Status: `keep (needs review from human)`
  - PR: none
  - Ahead/Behind vs `review/vir-d-full-lean-dom`: `+1/-0`
  - Summary: cache completed Lean-built DOM subtrees so revisits avoid both HTML encoding/parsing and result reconstruction.
  - Notes: rebased and force-published as `e85d8f1f`. Root `lake build` and `lake test`, the 76-job/43-member VIR package build, exact commit-addressed `40f2e3d...` SDK installation, Node smoke, the freshly restaged 295-entry generated-site browser differential, and the 24-query/48-dispatch retained-subtree cache stress pass. One current Chromium run completed 21 differential queries at a 0.5 ms median and 19.4 ms maximum; retain the earlier balanced profiling only as historical design evidence. F remains the strongest later visible full-Lean search candidate, but its nested runtime-only package boundary and DOM/startup surface keep B materially smaller for the first cross-package one-runtime pilot. Review only the retained-subtree alternative at <https://github.com/ejgallego/verso/compare/review/vir-d-full-lean-dom...review/vir-f-subtree-cache>.

- [ ] `feat/vir-search-experiment`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-search-experiment`
  - Status: `keep (needs review from human)`
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+3/-1`
  - Summary: add opt-in VIR domain mapping/ranking and an independently selectable FIR-native ranking lane, both with JavaScript fallback.
  - Notes: completed locally as `3dfd44d4`, `e465741e`, and `0814cda2` on frozen upstream Verso `22f6fe34`, the last commit before the Lean 4.34 bump, using final Lean `v4.33.0`. The third lane preserves the original ranking formula and ordering, uses direct structured values rather than JSON, and composes as VIR mapping + FIR ranking when both are configured. The exact post-rebase FIR package passes Node differential/smoke checks and generated-site provider-selection, missing-artifact fallback, 100-call frontier-rewind, and disposal tests in Chromium and Firefox. Full `lake build`, `lake test`, TypeScript, Prettier, and `git diff --check` passed. On representative 256-candidate runs FIR took 5.66-9.78 ms versus VIR 18.39-31.08 ms and JavaScript 0.029-0.050 ms; retain JavaScript as the production fallback and treat algorithm changes as follow-up work.

- [ ] `FIR feat/verso-search-lane`
  - Path: `/home/egallego/lean/verso/.worktrees/fir-verso-search`
  - Status: `keep (needs review from human)`
  - PR: none
  - Ahead/Behind vs `upgrade/lean-4.33`: `+1/-0`
  - Summary: compile the unchanged Verso ranking core to FIR-native Wasm and expose it as a third experimental browser lane.
  - Notes: rebased cleanly as `d5648cf8` onto current FIR Lean 4.33 head `82efc70a`, replaying only the experiment commit rather than superseded 4.33-upgrade history. The change adds resident `USize.ofNat`, `USize.decEq`, `Float.decLt`, and `Float.ofBits` support plus a pinned integration, direct structured browser adapter, scratch-arena ownership, and immutable packaging. The rebuilt artifact remains byte-identical at 21,173 bytes with 138 functions, zero imports, and zero runtime operations; Wasm SHA-256 is `7cc123d6e4f25fe1fb17507778fb5bbee704f0e6a40902cb7c23bdd1f5a0973e`, while the provenance-sensitive package identity is now `815723ece8c4dcf07f8bc30f6b00bee4cd4dd854052c7920eb1a6decc038e71d`. `make check` passed 653 native/LCNF/V8 cases and 1,968 equal comparisons with zero findings; the 3,143-job `make talos-check`, package smoke, exact-package differential benchmark, browser checks, and `git diff --check` also passed.

- [ ] `perf/vir-search-qsort`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-search-qsort`
  - Status: `keep (needs review from human)`
  - PR: none
  - PR Title: `perf: keep experimental search ranking on the JavaScript hot path`
  - PR Body: `Retain Verso's candidate construction, full-text normalization, multiplication, and stable Array.sort in JavaScript while exposing a cacheable scalar priority factor for FIR. Record the rejected structured-array and indexed-qsort designs, benchmark the three lanes, and normalize refreshed VIR Nat indices at the browser boundary.`
  - Ahead/Behind vs `feat/vir-search-experiment`: `+3/-0`
  - Summary: replace the slow whole-ranker port with a cacheable scalar FIR factor while retaining the original JavaScript-shaped ranking hot path.
  - Notes: completed locally as `adc0368f`, `88f71dc9`, and `9359f9b0`. The structured scorer plus JavaScript sort improved a same-session 256-candidate FIR median from 8.32 ms to 1.80 ms, but profiling showed persistent-array encoding/execution remained the bottleneck and made an `Array.swap` qsort unattractive. The final scalar lane caches each integral priority deviation, uses the original `Math.pow` path for fractional/out-of-range deviations, and measured 0.87-0.99x JavaScript at 256 candidates across three fresh runs (development data). A clean VIR rebuild exposed string-decoded `Nat` indices; the adapter now restores the numeric provider contract. `lake build` completed 703 jobs, `lake test` passed, VIR smoke and three-way differential checks passed, and the generated-site FIR/VIR browser suite passed 8 tests with 2 expected skips because the generated UsersGuide does not enable VIR configuration.

- [ ] `feat/vir-search-full-lean`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-search-full-lean`
  - Status: `keep (needs review from human)`
  - PR: none
  - PR Title: `perf: retain full-Lean VIR search DOM subtrees`
  - PR Body: `Implement a Lean-owned semantic quick-jump component through generic VIR startup and browser bindings. Preserve the JavaScript-shaped scorer, restore per-element DOM construction, and retain a bounded set of completed result lists so revisits avoid HTML encoding and parsing. Add order-balanced browser profiling, exact artifact identities, resource-lifetime and cache-eviction regressions, and refresh only the isolated VIR dependency while keeping Verso frozen on Lean 4.33.`
  - Ahead/Behind vs `perf/vir-search-qsort`: `+7/-0`
  - Summary: prove and profile a Lean-owned semantic quick-jump component through a VIR startup hook, with no Verso-specific JavaScript runtime API.
  - Notes: completed locally as `0916e15f`, `d22dfce2`, `8d733971`, `94ea3fcf`, `da8a45a5`, `5555919c`, and `c52c55ee`. Current VIR improves warm work for both compact and ByteArray representations, while four-pass AB/BA totals make the ByteArray lane promising but still inconclusive rather than rejected. Direct, nested, and array-held `RuntimeRef (Js String)` values survive 64 retained reads; the failure was the `browser.element.setInnerHTML` binding explicitly consuming its borrowed-looking string argument, not a `RuntimeRef`, interpreter, or Wasm ownership defect. VIR repair `025e1bd` resolves rather than releases the supplied resource and is published in draft VIR PR #147; its full CI run passed, Verso's commit-addressed `:virSdk` facet downloaded the CI-produced SDK, and that Wasm is byte-identical to the local repair build. The repaired cached-`Js String` prototype is ownership-correct but rejected because it leaves DOM replacement unchanged. Commit `c52c55ee` instead restores the original per-element Lean renderer, retains six static tag resources, and caches completed `<ul>` subtrees using only existing generic VIR bindings. The final six-pass AB/BA medians are +0.5% for seven cold queries, +2.0% for forward typing, -67.9% for 28 exact repeats, and -55.8% for backspace/retype revisits versus the escaped-`innerHTML` control. A 24-query/48-dispatch churn and reverse-revisit check exceeds the sixteen-entry cache while retaining exactly one live results list. The final 142,810-byte application package, all 12 retained-read/DOM-use paths for 64 rounds, Node smoke, browser differential, clean 76-job experiment build, repository-wide 703-job build, and `lake test` pass. `experiments/vir-search/FULL_LEAN.md` records exact hashes, sizes, reports, reproduction, and conclusions.

- [ ] `feat/vir-search-full-lean-review`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-search-full-lean-review`
  - Status: `keep (needs review from human)`
  - PR: none
  - PR Title: `feat: add full-Lean VIR quick-jump experiment`
  - PR Body: `This PR adds an opt-in semantic quick-jump whose xref decoding, fuzzy matching, bounded result selection, DOM construction, cache, and input callback are implemented in Lean. It uses only generic VIR startup/browser surfaces, keeps production JavaScript as the reference and fallback, and retains completed result-list subtrees so revisits avoid reconstruction. The branch also adds browser differential/cache checks, artifact-aware profiling, and a concise record of the accepted result and production gaps. The experiment remains isolated on the final Lean 4.33 Verso base and pins the VIR repair published by draft VIR PR #147.`
  - Ahead/Behind vs shared frozen base `e465741e`: `+3/-0`
  - Summary: curate the accepted full-Lean quick-jump implementation into a small maintainer-facing branch independent of the FIR and qsort experiments.
  - Notes: completed locally as `5c537248`, `b2a71137`, and `05b6eb78` from `e465741e`; preserve `feat/vir-search-full-lean` unchanged at `c52c55ee` as the research archive. Superseded for maintainer review by the one-commit A-F graph rooted at `review/vir-a-dependency`; retain this published branch as the pre-split snapshot. The accepted 438-line `FullLean.lean` is byte-identical to the archive at SHA-256 `8882e4db7a82fd3db1f7c87e6659568b561ee2abe04f91abcea9a506a1b5dfc7`. The curated branch normalizes VIR-exported `Nat` indices at the JavaScript boundary, records archived six-pass timings separately from the clean rebuild identity, and retains only the final subtree-cache design. Final `lake build` completed 703 jobs and `lake test` passed; the clean 76-job VIR package build, exact pinned SDK download, Node smoke, 295-entry Chromium differential plus 48-dispatch cache churn, one-pass provenance harness, and six staged-provider tests across Chromium and Firefox also passed. The rebuilt application package is 142,817 bytes with SHA-256 `de8c68441db6ba67e0e526258605348e4cd1b0684a24ebdfee54e4f48330564d`. Published as `ejgallego/feat/vir-search-full-lean-review` for review at `https://github.com/ejgallego/verso/compare/e465741e...feat/vir-search-full-lean-review`; no PR opened.

- [ ] `FIR perf/verso-search-qsort`
  - Path: `/home/egallego/lean/verso/.worktrees/fir-verso-search-qsort`
  - Status: `keep (needs review from human)`
  - PR: none
  - PR Title: `perf(wasm): cache scalar Verso search priority factors`
  - PR Body: `First retain native JavaScript stable sorting around a source-ordered FIR scorer, then reduce the final Wasm boundary to one cacheable scalar priority factor. Remove structured Lean object marshalling from the hot path, add cold/warm phase profiling, and preserve immutable package provenance.`
  - Ahead/Behind vs `feat/verso-search-lane`: `+2/-0`
  - Summary: compile a scalar priority-factor entry and cache results so warm ranking stays in the original JavaScript data flow.
  - Notes: completed locally as `d4f54f3f` and `834aa522`. The final 10,254-byte module has 68 functions, zero imports, and zero runtime operations; Wasm SHA-256 is `081a930a0e0031867c91bd2384c703fb5165996d46077c8af6c11a4724a4f8ef`. The clean immutable package is `e3f914cf07ef964ab004eb789d103223eeaa6150f779a5689e030490e09c6cc2`, pinned to Verso `88f71dc9`. The scalar adapter is 243 lines/8,159 bytes versus 551 lines/18,143 bytes for the structured scorer, removing 308 lines and 9,984 bytes. Cache misses clear and rewind the FIR arena immediately; warm calls do not enter Wasm. `make check` passed 662 covered cases and 1,968 equal comparisons, all 3,149 `make talos-check` jobs passed, and the clean package smoke/browser/differential checks passed.

- [ ] `FIR perf/verso-search-bulk`
  - Path: `/home/egallego/lean/verso/.worktrees/fir-verso-search-bulk`
  - Status: `keep (needs review from human)`
  - Decision: pending
  - Summary: measure the source-ordered structured scorer with one PrettyM-style bulk input allocation before attempting the W7-backed packed ByteArray lane.
  - Notes: completed locally as `2ffc5c21`, branched from FIR `d4f54f3f` before the scalar-factor reduction. The adapter measures the complete input graph, reserves one resident block, and directly writes the unchanged Lean object layout; scoring, decoding, stable JavaScript sorting, and rewind are unchanged. At 256 candidates, aggregate encoding fell from 0.793 ms to 0.146 ms in the phase experiment; a time-calibrated AB/BA run measured 1.560 ms to 0.925 ms end to end. The clean immutable package is `5a145e5a355c26984c8afc5383dffc0bd957a3b0003d8644ce75625a31c42f9c`, with the same 19,222-byte Wasm SHA-256 `1e2eb2a656d2694b354e9e7fed16e3364c627a9f170d2d37de804890d16a7cf0` as the baseline. Exact-output, heap-number, empty-input, and scratch-frontier checks passed; `make check` and all 3,149 `make talos-check` jobs passed. Native sampling was unavailable on this host, so no native hotspot claim is made. FIR execution now dominates large structured workloads; the packed ByteArray experiment remains ordered after W7 integration and mailbox request `ROOT-FIR-20260812-001`.

- [ ] `control/vir-search-bulk-source`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-search-bulk-source`
  - Status: `keep (read-only source pin; cleanup after review)`
  - Decision: pending
  - Summary: provide the exact clean Verso `scoreCandidates` source revision for the FIR bulk-allocation control.
  - Notes: clean supporting worktree at `adc0368f`; it remained unmodified throughout the FIR adapter experiment.

- [ ] `FIR perf/verso-search-packed`
  - Path: `/home/egallego/lean/verso/.worktrees/fir-verso-search-packed`
  - Status: `keep (blocked on generic W7 resident operations)`
  - Decision: pending
  - Ahead/Behind vs `main`: `+1/-1`
  - Summary: evaluate the source-ordered packed ByteArray score-plan lane against the completed structured bulk control and native JavaScript.
  - Notes: admission scaffold completed locally as `5db70cf6`, branched from FIR `main` at `1cfcb9b8` after the W7 generation handoff `3178f37c` integrated. Ordinary final-LCNF capture and lowering succeed with zero runtime operations. After source refinements removed incidental `Nat.mul`, `Nat.div`, and `Float.decLt`, the permissive frontier retains exactly seven representation-bound imports: `ByteArray.get!`, `ByteArray.set!`, `Float.ofBits`, `Float.toBits`, `UInt32.shiftLeft`, `UInt32.lor`, and `UInt64.lor`. Zero-import emission fails closed at `UInt32.shiftLeft`, so no Wasm package or browser adapter is claimed. Root `lake build` and the documented `make check` suite passed: 666 unique cases, 1,980 equal backend comparisons, and zero findings. Resume after mailbox request `ROOT-FIR-20260812-001` lands the generic packed-ByteArray surface; then package, differential-test, and benchmark AB/BA against bulk control `5a145e5a355c26984c8afc5383dffc0bd957a3b0003d8644ce75625a31c42f9c`.

- [ ] `feat/vir-search-packed-source`
  - Path: `/home/egallego/lean/verso/.worktrees/vir-search-packed-source`
  - Status: `keep (needs review from human)`
  - Decision: pending
  - Ahead/Behind vs frozen source base `adc0368f`: `+1/-0`
  - Summary: add the experimental packed ByteArray score-plan entry on the exact frozen Verso 4.33 source base.
  - Notes: completed locally as `0f46ae0b`, one file and one commit ahead of clean frozen revision `adc0368f`. The new `scorePackedCandidates : ByteArray → ByteArray` entry owns a versioned 16-byte header and 24-byte source-ordered rows, performs unchanged normalization and priority scoring, and overwrites only each row's binary64 score; JavaScript retains candidate objects, rehydration, and native stable sorting. Semantic rows take one pass and full-text rows two, with bounds validated during traversal and invalid inputs returning an empty buffer. A native harness matched `scoreCandidates` bit for bit and rejected bad magic and truncation. Lean Beam reported zero diagnostics, full `lake build` completed 703 jobs, and `lake test` passed. Source SHA-256 is `ef969706779c962d3b44ebb041e05954695f67c47fd9309994b2818a1707889f`.

- [ ] `perf/flt-generator-combined`
  - Path: `/home/egallego/lean/verso/.worktrees/flt-generator-combined`
  - Status: `locked`
  - PR: n/a
  - Summary: combine one-pass HTML escaping with single-owner compact xref emission and measure the native FLT Blueprint generator.
  - Notes: local experiment completed on 2026-08-09 with the three changes preserved as separate commits. Full `lake build`/`lake test` and exact FLT output validation passed; combined medians reduced instructions 44.27% and cycles 38.14%. The temporary baseline worktree was retired after its executable and raw evidence were frozen.

### Open PRs (`needs: rebase`)

- [ ] `review/pr-902`
  - Path: `/home/egallego/lean/verso/.worktrees/pr-902-review`
  - Status: `needs: discussion`
  - Decision: pending (discuss the local findings before any GitHub action; set by user)
  - PR: #902 <https://github.com/leanprover/verso/pull/902>
  - Ahead/Behind vs `upstream/main`: `+26/-26`
  - Summary: review `feat: proper test framework`
  - Notes: local review completed at PR head `6029b673`; `lake build` and `lake test` pass (340 tests). Findings are awaiting discussion and nothing was written to GitHub. The PR currently diverges from `upstream/main` and does not merge cleanly.
    Local findings to carry into the split PRs:
    1. `.github/workflows/ci.yml:103`: the always-run `dorny/test-reporter` needs `checks: write`, so normal fork PRs cannot publish the check and can fail after their tests pass; use an artifact plus `workflow_run`, or skip check publication for forks.
    2. `src/errata/Errata/CompileTime.lean:49`: `#test_msgs` captures a nested linter warning but lets the outer linter emit it again; the local unused-variable probe passed while still printing the warning.
    3. `src/errata/Errata/Result.lean:168`: reported `package/module` values are documented as rerun selectors, but `lake test -- verso/VersoTests.Basic` exits with `no library matches` because the driver accepts libraries rather than modules.
    4. `src/errata/Errata/CompileTime.lean:8`: importing `Errata.CompileTime` directly and using `#test_guard` fails with `Unknown attribute [test]`; the feature module does not import the attribute registration it generates.
    5. `src/errata/Errata/Widget.lean:196`: the widget runner inherits stderr, does not check the process exit status, and treats stdout EOF without an outcome as normal completion, leaving the JavaScript widget blank on early runner crashes.
    6. `lakefile.lean:363`: tests selected from dependency libraries are generated with `ws.root.prettyName`, so their package identity, rerun identifier, and report grouping incorrectly name the root package.
    Incrementality review:
    - Lake correctly caches module compilation and the generated runner. Changing the selected library set rebuilt `ErrataDiscovered`, `ErrataRunnerMain`, and `errata-runner` in about 2 seconds; repeating `lake test -- ErrataTests` produced no build jobs and completed in about 0.6 seconds.
    - Runtime outcomes are not cached: the warm invocation still executed all 30 entries, and two direct single-test invocations both executed the test. `#test_msgs`/`#test_guard` are the exception—their verdicts are computed while compiling and stored in the `.olean`, so the runtime action only reports the stored verdict.
    - There is no batch module/test/failed-test filter. Selection stops at libraries, despite reports documenting modules as rerun units.
    - Duplicate selectors are not deduplicated: `lake test -- ErrataTests ErrataTests` generated a duplicate module selection and reported 60 passes rather than 30.
    - `src/errata/Errata/Discovery.lean:151` hashes only the test declaration's source for the widget cache key. An unchanged test can therefore continue displaying an old result after an imported helper, an earlier same-module helper, a golden file, an environment variable, or another runtime input changes.
    - Recommended split-PR direction: keep Lake's artifact cache; add stable test IDs and runner-side module/test filters so changing the filter does not relink the runner; persist prior results only to implement `--failed`/history. Do not skip arbitrary runtime tests from cached outcomes by default, because tests may perform undeclared IO. Any reusable pass cache should be opt-in and keyed by declared inputs plus the compiled dependency/runner fingerprint and runner options.

- [ ] `fix/external-decl-labeled-groups`
  - Path: `/home/egallego/lean/verso/.worktrees/external-decl-labeled-groups`
  - Status: keep (`PR open; full CI pending`)
  - PR: #880 <https://github.com/leanprover/verso/pull/880>
  - Ahead/Behind vs `upstream/main`: `+1/-0`
  - Summary: `fix: label external declaration sections without h1`
  - Notes: refreshed PR #880 on 2026-06-29 by rebasing the single fix commit onto GitHub `main` `3a224bb3` and force-pushing `fix/external-decl-labeled-groups` as `08f10450`. Review comments from `david-christiansen` were addressed by changing the HTML-compaction test helper to `String.foldl`, using `withLogger` for the render logger lifecycle, and applying the blank suggestion at EOF; a thread-aware GraphQL refetch found three unresolved outdated threads and zero unresolved current threads. Local validation on `08f10450` passed with `lake build Tests.VersoManual.Html`, `lake build`, `lake test`, and `git diff --check`; generated manifest churn from `lake test` was reverted. Existing upstream warnings replayed in `SubVerso.Compat`, `VersoManual.Docstring`, `UsersGuide.Literate`, and `DemoSite.Blog.Conditionals`. Follow-up on 2026-06-30 added an inductive fixture so the regression now covers both `Fields` and `Constructors`, factored the repeated section-shape assertions, amended the PR commit to `b8416941`, and force-pushed with lease. Focused validation passed with `lake build Tests.VersoManual.Html` and `git diff --check`; PR is open, no longer draft, and mergeable. Lightweight GitHub checks passed on `b8416941`; `Build and test` is pending.

- [ ] `feat/folding-doc-start-range`
  - Path: `/home/egallego/lean/verso/.worktrees/folding-doc-start-range`
  - Status: keep (`PR open; checks passed`)
  - PR: #771 <https://github.com/leanprover/verso/pull/771>
  - Ahead/Behind vs `upstream/main`: `+2/-0`
  - Summary: `fix: preserve Verso document ranges for LSP`
  - Notes: rebased onto `upstream/main` `4c6b02ee`; force-pushed `feat/folding-doc-start-range` as `fbf14977`. Deep review split TOC range syntax from selection syntax so root document symbols keep full ranges while selecting the visible title literals; follow-up implemented reviewer suggestion to read the root range anchor with `getRef` inside `elabDoc`/`startDoc` after verifying term and command LSP fixtures pass with the aggregate import path rebuilt. Moved the changelog entry from `v4_29_0` to the current unreleased `v4_31_0`, and made public `PointOfInterest` document-symbol handling share the same strict `selectionRange` containment assertion as TOC symbols. Final cleanup made the containment helper private, restored `mergeResponses` in document-symbol handling, renamed the TOC helper to `requireRecoverableTOCRange`, and documented that it only checks Lean-recoverable ranges via `getRange?` rather than rewriting or normalizing syntax. Restored point-free `mapCostly` style to avoid diff noise, fixed folding fixtures to `sync` before document-wide requests with markers before EOF-consuming `#doc` bodies, and made `PartElabM.State.init` require explicit range and selection anchors at call sites. Follow-up after interactive testing fixed a hidden term-`#doc` elaborator bug where `elabDoc` produced `VersoDoc` but the term elaborator still expected `Part`, then added `Tests.DocTerm` so standard tests catch direct `#doc` term diagnostics. Latest cleanup reworded the LSP containment comment, updated the PR title/body to match current scope without claiming syntax normalization, and expanded `symbols_verso` to cover the explicit `PointOfInterest` selection override used by `leanOutput`. Local validation passed with direct elaboration of changed LSP fixtures, targeted LSP regressions, full interactive LSP suite, focused touched-module/test build, full `lake build`, `lake test`, `lake build Verso.Doc.Lsp`, and `git diff --check`; generated fixture manifest churn from `lake test` was reverted. GitHub checks passed on the latest push.
- [ ] `feat/ci-userguide-deploy`
  - Path: `/home/egallego/lean/verso/.worktrees/ci-userguide-deploy`
  - Status: keep (`PR open; needs deployment-path validation`)
  - PR: #765 <https://github.com/leanprover/verso/pull/765>
  - Ahead/Behind vs `upstream/main`: `+1/-0`
  - Summary: `chore: expose PR preview as GitHub deployment`
  - Notes: rebased onto `upstream/main` `8e3468a2`; force-pushed `feat/ci-userguide-deploy` as `18ec578b`, amended and force-pushed as `27f54340` to quote the deployment environment, validate PR metadata before Netlify deploy, and log both candidate PR SHAs, amended and force-pushed as `82639349` to replace archived/third-party metadata and artifact actions with first-party GitHub actions, remove `GITHUB_TOKEN` from the Netlify action, and pin the Netlify action to commit `4cbaf4c0`, amended and force-pushed as `b698b6f2` to document the secret-bearing `workflow_run` model in YAML comments and expand the PR body with security/provenance notes, amended and force-pushed as `48c54d3f` to keep posting a temporary PR preview comment via first-party `actions/github-script@v9` while the deployment UI path is validated, then rebased onto `upstream/main` `5b9f85b4` and force-pushed as `b584d9a3`, resolving the upstream Netlify v4 update by pinning `nwtgck/actions-netlify` to the v4.0.0 commit `d22a32a2`. Updated PR title and adapted PR body to terse upstream-style prose with `Prepared with Codex (GPT-5.5)` footer. New workflow keeps previews for all PRs, disables the Netlify action's implicit GitHub deployment/status reporting under `workflow_run`, records an explicit GitHub deployment with the Netlify URL, and posts the rollout-era PR preview comment. Local validation passed with `actionlint .github/workflows/pr-deploy.yml .github/workflows/ci.yml` and `git diff --check upstream/main..HEAD`; actionlint printed only the existing local `LD_PRELOAD` warning. After `b584d9a3`, GitHub lightweight checks passed and `Build and test` was pending. The post-CI `Deploy PR Preview` run at `2026-06-06T15:29:12Z` used the workflow from default branch `main`, not the PR branch, so it still ran `marocchino/sticky-pull-request-comment@v3`, posted issue comment `4639434360`, and created deployment `4958282955` on `8e3468a2`; do not count that as validation of this PR's new deployment-recording path. Worktree clean.
- [ ] `ci-win`
  - Path: `/home/egallego/lean/verso/.worktrees/ci-win`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #724 <https://github.com/leanprover/verso/pull/724>
  - Ahead/Behind vs `upstream/main`: `+6/-7`
  - Summary: `wip`
  - Notes: clean worktree.
- [ ] `feature/dark-mode-support`
  - Path: `/home/egallego/lean/verso/.worktrees/dark-mode-support`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #676 <https://github.com/leanprover/verso/pull/676>
  - Ahead/Behind vs `upstream/main`: `+2/-71`
  - Summary: `style: apply prettier formatting to theme-toggle.js`
  - Notes: clean worktree.
- [ ] `codex/issue-762-inline-role`
  - Path: `/home/egallego/lean/verso/.worktrees/issue-762-inline-role`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #766 <https://github.com/leanprover/verso/pull/766>
  - Ahead/Behind vs `upstream/main`: `+1/-0`
  - Summary: `fix: align inline Lean role names with Manual`
  - Notes: clean worktree.
- [ ] `parse_start`
  - Path: `/home/egallego/lean/verso/.worktrees/parse_start`
  - Status: keep (`needs review from human; upstream Lean parser API follow-up pending`)
  - Decision: upstream Lean API first (set by user)
  - PR: #750 <https://github.com/leanprover/verso/pull/750>
  - Ahead/Behind vs `upstream/main`: `+4/-0`
  - Summary: `refactor: use parser restarting API instead of whitespace padding`
  - Notes: bad reduced rebase push was restored to the old PR head `c32416ea`, then PR #750 was redone on a temporary detached worktree and force-pushed to `ejgallego/verso:parse_start` as `65913540`. The corrected range preserves all four original PR commits on `upstream/main` `a9c31d52`, while resolving conflicts against current Verso's `strLitInputContext`/`parseStrLitWith`/`parseStrLitAsCategory` helpers instead of skipping the parser-restart work. Local `parse_start` now matches the pushed PR head; temporary redo worktree removed. Worktree is clean except for pre-existing untracked local `AGENTS.md`. Local validation passed with `lake build` and `lake test`; both replayed existing warnings in doc/manual/demo modules, and generated `test-projects/literate-multi-root/lake-manifest.json` churn from `lake test` was restored. GitHub checks started on `65913540`. Upstream Lean API follow-up remains relevant, especially improving parser APIs such as `Parser.parseHeader`/parser restarting so Verso can remove the remaining `leanInit` whitespace-padding workaround rather than carrying local compatibility helpers long-term.
- [ ] `remove_warns`
  - Path: `/home/egallego/lean/verso/.worktrees/remove-warns`
  - Status: keep (`needs: rebase`)
  - Decision: pending (set by user)
  - PR: #749 <https://github.com/leanprover/verso/pull/749>
  - Ahead/Behind vs `upstream/main`: `+1/-7`
  - Summary: `chore: remove unused variables warning showing up in build`
  - Notes: clean worktree.
- [ ] `research/role-fallback`
  - Path: `/home/egallego/lean/verso/.worktrees/role-fallback-research`
  - Status: keep (`PR open; CI in progress`)
  - PR: #763 <https://github.com/leanprover/verso/pull/763>
  - Ahead/Behind vs `upstream/main`: `+13/-0`
  - Summary: `feat: improve role resolution error diagnostics`
  - Notes: rebased onto `upstream/main` `8e3468a2`; force-pushed `research/role-fallback` as `eafc3b09`. Current review state before fixes had one old resolved thread and ten unresolved inline threads plus one top-level question. Review fixes addressed preferred `@[role]` wording, declaration-not-function wording, unstable broad closest-role tests, safe registered-name lookup, shadowing-aware display via `unresolveNameGlobal`, and shared suggestions for roles/code blocks/directives/block commands while preserving block-command declaration fallback. Follow-up pass renamed `Tests.RoleResolution` to `Tests.ExtensionResolution`, removed unnecessary `VersoManual`/`VersoBlog` imports, expanded local cases for registered/unregistered/wrong/unknown extension names, extracted suggestion/resolution helpers to `Verso.Doc.Elab.ExtensionResolution`, factored repeated expander retry handling in `Elab.lean`, added explicit edit-distance close-match/no-match cutoff diagnostics, tightened `VersoManual.Index` to the needed public meta inline elaboration import, further shared role/block expander execution through one helper path in `Elab.lean`, added an informative shadowing-test comment plus an unqualified shadowed-role typo case that must suggest the qualified registered role name, fixed suggestion cutoff enforcement by checking returned edit distances against the threshold, added a deterministic multi-suggestion case that exercises forced list rendering, expanded cutoff tests to cover match/no-match behavior at the relevant input-length boundaries, and merged the inline/block/registered-block extension result helpers into one shape-parameterized `extensionResult` helper. PR body updated to match current scope. No GitHub comments posted per user request. Import audit confirmed `public meta import Verso.Doc.Elab.Monad` alone is not a replacement for the two-line `public import`/`meta import` form where ordinary downstream `import` must still see `DocElabM`/`FromArgs`/`RoleExpanderOf`; `VersoManual.Index` ordinary import still exposes its public role declarations. Local validation on the latest head passed with `lake build Verso.Doc.Elab Tests.ExtensionResolution`, `lake build Tests`, `lake test`, and `git diff --check`; generated fixture manifest formatting churn from `lake test` was reverted. A read-only thread-aware PR query found no unresolved current inline review threads. GitHub checks restarted on `eafc3b09`.

### No Open PR Yet (`needs: progress`)

- [ ] `fix/semantic-inline-tokens`
  - Path: `/home/egallego/lean/verso/.worktrees/semantic-inline-tokens`
  - Status: locked
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+4/-0`
  - Summary: `fix: restore complete semantic tokens for embedded Lean inline roles and :::multilean`
  - Notes: user-directed focused follow-up split from `feat/issue-135-multilean`; rebased onto that feature head so the active worktree can carry the LSP semantic-token fix plus a targeted regression test.

- [ ] `feat/issue-135-multilean`
  - Path: `/home/egallego/lean/verso/.worktrees/issue-135-multilean`
  - Status: keep (`needs review from human`)
  - Decision: human review (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+4/-0`
  - Summary: `add :::multilean with synthetic combined elaboration and interleaved explanation rendering`
  - Notes: branch pushed to `ejgallego/verso:feat/issue-135-multilean`; local implementation includes the shared inline-lean elaboration refactor, multilean block renderer/splitting helpers, explanation styling, and the follow-up fix preserving indentation for split proof steps. Validation passed with `lake build` and `lake test`.

- [ ] `feat/doc-elab-build-mode`
  - Path: `/home/egallego/lean/verso/.worktrees/doc-elab-build-mode`
  - Status: keep (`needs review from human`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+1/-0`
  - Summary: `thread batch vs interactive document elaboration mode into DocElabContext`
  - Notes: user-directed task completed locally with build-mode plumbing for `#doc`/`#docs`, batch and LSP regression coverage, and successful `lake build` plus `lake test`.
- [ ] `perf/manual-patch-test`
  - Path: `/home/egallego/lean/verso/.worktrees/manual-patch-test`
  - Status: keep (`PR open; CI in progress`)
  - PR: #854 <https://github.com/leanprover/verso/pull/854>
  - Ahead/Behind vs `upstream/main`: `+1/-0`
  - Summary: `avoid re-exporting imported manual doc expanders`
  - Notes: branch rebased onto `upstream/main` `62e75467`; PR #854 force-pushed as `ff52d547`. Review-comment pass addressed requested author tags, module comments for the regression chain, removal of trailing namespace endings, removal of root `public import Verso.EnvExtension`, a non-public `Verso.EnvExtension` import from `Monad.lean`, private `ExpanderExtension`, and documentation for the eager imported-state initialization rationale. Patch now stages `LocalPersistentEnvExtension` in `Verso.EnvExtension` as a narrowed Verso-side helper with one state type used for complete imported lookup state and local export delta, and uses it for doc expander/signature registries. API review: raw constructor/field are private outside the module; export still receives only the local delta; no async/replay surface is exposed; module comment states the same-state, local-delta, eager-import, and main-only/direct-raw-extension contract. The API owns the generic fold over imported module entry arrays via `addImportedEntryFn`; extension call sites only provide one-entry merge semantics. Dead helper surface was trimmed: removed unused `getDelta`, unused descriptor `statsFn`, and trivial `addSignatureEntry`; kept the `Nonempty` instance because `initialize` needs it and kept `addExpanderEntry` as the shared append-under-key policy. Regressions cover role, code-block, directive, block-command expanders, plus a direct three-module local-persistent-extension check. PR message reviewed by user: apply typo cleanup, keep the Codex-query wording, and do not add a validation section; PR body updated to mention the helper. Measurement data retained: UsersGuide timing effectively flat with about 432 KiB `.olean` reduction; latest reference-manual on Lean `v4.30.0-rc2` showed `lake --no-cache build Manual` baseline runs of 157.13s and 155.61s vs patched 144.25s, with total compared artifacts dropping by about 35.8 MiB; synthetic `Manual.PerfImportPair` dropped from 375,456 B to 17,072 B `.olean`. Validation on rebased head passed with `lake build Tests.DocElabExtensions.Use`, `git diff --check`, `lake build`, and `lake test`; full build replayed existing warnings in `VersoManual.Docstring`, `UsersGuide.Literate`, and `DemoSite.Blog.Conditionals`. Current GitHub checks on `ff52d547`: quick checks green; `Build and test` in progress.
- [ ] `perf/manual-bench-infra`
  - Path: `/home/egallego/lean/verso/.worktrees/manual-bench-infra`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+12/-0`
  - Summary: `benchmark harness, downstream result snapshot, and manual-harness repair work`
  - Notes: downstream `reference-manual` benchmark is valid and shows a median speedup; manual benchmark is being reworked around fresh snapshots plus baseline-vs-single-commit comparisons and is still blocked on `subverso` helper compatibility in the workload path.
- [ ] `perf/manual-elab-review`
  - Path: `/home/egallego/lean/verso/.worktrees/manual-elab-review`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+7/-0`
  - Summary: `perf-only stack for manual elaboration changes plus local cleanup commit`
  - Notes: rebased cleanly onto latest `upstream/main`; still the code branch we are measuring, with benchmark/docs kept on the infra branch.
- [ ] `perf/manual-genre-scaling`
  - Path: `/home/egallego/lean/verso/.worktrees/manual-genre-scaling`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+12/-0`
  - Summary: `research branch with profiling hooks and exploratory manual perf history`
  - Notes: instrumentation-heavy branch for profiling Verso/VersoManual behavior; attempted rebase hit a real conflict in `src/verso-manual/VersoManual/InlineLean.lean`, so it was left unrebased rather than merged ad hoc.
- [ ] `perf/latest-refman-profile`
  - Path: `/home/egallego/lean/verso/.worktrees/latest-refman-profile`
  - Status: special
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+0/-0`
  - Summary: `latest Verso plus latest reference-manual perf profiling workspace`
  - Notes: branch tracks `upstream/main` at `62e75467`; profiling artifacts live under `.bench/reference-manual/latest/20260604T174138Z`. The extracted benchmark copy only was patched for local `elan --help` wording drift (`package` -> `crate`) before profiling.
- [ ] `perf/latest-refman-findings`
  - Path: `/home/egallego/lean/verso/.worktrees/latest-refman-findings`
  - Status: keep (`needs review from human`)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+2/-0`
  - Summary: `record latest reference-manual profiling findings and optimization candidates`
  - Notes: branch commit `86487cf8` stores the review note at `perf-notes/reference-manual-latest-2026-06-04.md`; raw `perf.data` artifacts remain in `perf/latest-refman-profile`.
- [ ] `feat/doc-html-preview`
  - Path: `/home/egallego/lean/verso/.worktrees/doc-html-preview`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+10/-3`
  - Summary: `feat(doc-preview): add inline hover docs support in preview widget`
  - Notes: dirty worktree.
- [ ] `refactor_syntaxutils`
  - Path: `/home/egallego/lean/verso/.worktrees/refactor-syntaxutils`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+1/-9`
  - Summary: `refactor: use Verso's runParserCategory function for string parsing`
  - Notes: clean worktree.
- [ ] `tex-widget`
  - Path: `/home/egallego/lean/verso/.worktrees/tex-widget`
  - Status: keep (`needs: progress`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+5/-49`
  - Summary: `wip`
  - Notes: clean worktree.
- [ ] `docs/open-issues-triage`
  - Path: `/home/egallego/lean/verso/.worktrees/open-issues-triage`
  - Status: keep (`pending on human action`)
  - Decision: pending (set by user)
  - PR: none
  - Ahead/Behind vs `upstream/main`: `+4/-3`
  - Summary: `doc: add open issues triage snapshot report`
  - Notes: clean worktree; report updated with a prioritized queue, waiting for human follow-up on resolved/closed issue cleanup.

### Special Trees, for Management / Metadata

- [ ] `agents.md`
  - Path: `/home/egallego/lean/verso`
  - Status: `special`
  - Decision: pending (set by user)
  - Ahead/Behind vs `upstream/main`: `+1/-0`
  - Summary: `Add AGENTS and dashboard overlay files`
  - Notes: special retained metadata/coordination tree.
- [ ] `main`
  - Path: `/home/egallego/lean/verso/.worktrees/main`
  - Status: `special`
  - Decision: pending (set by user)
  - PR: n/a
  - Ahead/Behind vs `upstream/main`: `+0/-0`
  - Summary: `chore: adapt to SubVerso's client-side pretty print support (#767)`
  - Notes: special retained baseline mirror; local refs currently up to date with `upstream/main`.

## Tasks Finished (PR Submitted / Cleanup Pending)

- [x] `bp` cleanup complete.
  - Outcome: removed worktree `.worktrees/bp` and deleted local branch `bp`.
- [x] `bp+refactor` cleanup complete.
  - Outcome: removed worktree `.worktrees/bp-plus-refactor` and deleted local branch `bp+refactor`.
- [x] `feat/folding-outline-doc-dup` merge check + cleanup complete.
  - Outcome: confirmed merged into `upstream/main`, removed worktree `.worktrees/folding-outline-doc-dup`, deleted local branch `feat/folding-outline-doc-dup`.
- [x] `codex/pr-768-assets` cleanup complete.
  - Outcome: removed worktree `.worktrees/pr-768-assets` and deleted local branch `codex/pr-768-assets`.
- [x] `tmp/component-hygiene-log` cleanup complete.
  - Outcome: removed worktree `.worktrees/tmp-component-hygiene-log`, deleted local branch `tmp/component-hygiene-log`, and deleted remote branch `ejgallego/tmp/component-hygiene-log`.
- [x] Detached cleanup complete: `.worktrees/pr768-before`.
  - Outcome: removed detached historical worktree.
- [x] Detached cleanup complete: `/tmp/verso-reg-bisect`.
  - Outcome: removed external detached bisect worktree.
- [x] `main` upkeep check executed.
  - Outcome: `main` is `+0/-0` vs local `upstream/main`; remote fetch attempted but temporary DNS/network prevented refresh.
- [x] `feat/folding-doc-start-range` queue-priority action complete.
  - Outcome: moved to first actionable position in `Tasks Ongoing`; currently `+1/-0` vs local `upstream/main`.
- [x] `feat/folding-ranges-lsp` review + cleanup complete.
  - Outcome: branch commit was patch-equivalent (`git cherry -`) to changes already in `upstream/main`; removed worktree `.worktrees/folding-ranges-lsp` and deleted local branch `feat/folding-ranges-lsp`.
- [x] `chore/bump-toolchain-v4.29.0-rc2` cleanup/state sync complete.
  - Outcome: local branch/worktree no longer exist, remote branch `ejgallego/chore/bump-toolchain-v4.29.0-rc2` already absent, and stale entry removed from `Tasks Ongoing`.
