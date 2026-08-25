# Full-Lean VIR quick-jump experiment

## Scope

This is an opt-in research component, not a replacement for Verso's production search box. It asks
whether a useful browser feature can be owned by Lean without maintaining a Verso-specific
JavaScript interface. The experiment is deliberately frozen on Verso's final Lean 4.33 base.

A generic VIR startup hook finds an opt-in mount point. From that point, Lean owns the semantic
quick-jump path:

| Stage | Owner |
| --- | --- |
| Decode and map built-in `xref.json` domains | Lean |
| Prepare targets and queries | Lean |
| Fuzzy-match and apply the `0.25` threshold | Lean |
| Select the best 30 results | Lean |
| Build labels, highlights, domain badges, and links | Lean `DomM` |
| Handle input events and update results | Lean callback |
| Load VIR artifacts and invoke startup entries | Generic 28-line bootstrap |

The generated page's stock search remains an independent reference and fallback. The bootstrap
knows only the VIR artifact URLs and `runStartupEntries()`; it contains no search operation.

## Implementation

`VersoSearchVir/FullLean.lean` is 438 lines. It follows the bundled fuzzysort 3.1.0 scorer closely:
target/query preparation, the 32-bit character-mask prefilter, greedy subsequence matching,
word-start search with bounded backtracking, contiguous bonuses, gap/position/length penalties,
multi-word aggregation, and the existing threshold converted back into fuzzysort's raw-score lane.

Targets are prepared once when the component mounts. A cache miss constructs a detached `<ul>`
subtree with VIR's generic `createElement`, attribute, class, text-content, and append operations.
The six static tag names are converted to retained JavaScript strings once. A bounded sixteen-entry
FIFO cache owns completed nonblank result lists:

- the active query repeated exactly performs no DOM operation;
- a cached revisit removes the active list and appends the retained list;
- an uncached query scores and constructs a new detached list;
- the blank rendering is retained separately.

This design keeps the original per-element construction model and removes HTML encoding and parsing
from the accepted lane. It adds neither a Verso-specific host function nor a new VIR binding.

## Correctness envelope

The Chromium differential maps the same 295 semantic items in Lean and JavaScript. For seven
representative queries, including an apostrophe-bearing key, it requires the same first four results
and at least 29/30 overlap in the display window. It also dispatches 24 distinct queries and then
revisits them in reverse order, exceeding the cache capacity while requiring exactly one live
results list.

The admitted-set tolerance is intentional. Fuzzysort's bounded heap can permute exact-score ties;
the Lean top-30 insertion instead preserves source order. The current fixture has neutral global,
domain, and item priorities, so it does not validate priority-adjusted ordering.

## Performance result

The accepted comparison used Chromium 141, the generated manual's 295-item xref, six order-balanced
AB/BA passes, seven queries, four exact repeats per query, and the same VIR runtime on both sides.
The control retained safely escaped HTML strings and updated the DOM through `innerHTML`; the
candidate retained Lean-built DOM subtrees. Values below are medians of complete per-pass totals,
not medians of individual callbacks:

| Phase | Escaped `innerHTML` cache | Retained DOM subtrees | Change |
| --- | ---: | ---: | ---: |
| Seven cold queries | 60.20 ms | 60.50 ms | +0.5% |
| Twenty-eight exact repeats | 23.20 ms | 7.45 ms | -67.9% |
| Forward typing | 243.30 ms | 248.15 ms | +2.0% |
| Backspace/retype revisits | 8.15 ms | 3.60 ms | -55.8% |

Cold work is neutral and forward typing is slightly slower. The meaningful win is the normal
backspace/retype revisit path; exact repeated input events are useful diagnostics but less common in
ordinary interaction. Instrumented cold construction still performs 28, 379, and 724 DOM operations
for 1, 10, and 30 results respectively, while an active-query repeat performs none.

The bundled JavaScript `fuzzysort.go` call alone measured roughly 0.02–0.04 ms on the same prepared
keys. That excludes mapping and rendering, so it is not an end-to-end comparison, but it does show
that this VIR lane is an interactive experiment rather than a performance-based production
replacement.

### Provenance

- archived accepted source commit: `c52c55eeb458b3e9a874a33d7b3294e59ae395f0`;
- accepted `FullLean.lean` SHA-256:
  `8882e4db7a82fd3db1f7c87e6659568b561ee2abe04f91abcea9a506a1b5dfc7`;
- VIR commit: `025e1bdd753b9077bced07be3cb36536f501ee40`;
- CI-produced VIR Wasm SHA-256:
  `000c0fe150c5a1a7ff8b66e11ff9b8388e4a260af665c039c500b4d94b0f10bc`;
- escaped-HTML control package: 135,846 bytes,
  `9f687c8f133b2f5445adcf903bc848ab943dd5610196645b1680209b39a4112f`;
- retained-subtree package: 142,810 bytes,
  `311c4c51f1f5ef1f03160aa6181e1a8de95d8dc5fbcc8c58cf6ee6277a58efa0`;
- archived raw report SHA-256:
  `da5c670ffe8fda508123ee812d47771d8d33ff590e47ed74fe056c545b6f6c6f`.

`FULL_LEAN_RESULTS.json` retains the package identities and all per-pass phase totals needed to
recompute the table without the ignored diagnostic profiles. The browser harness additionally
fingerprints its own source, `FullLean.lean`, the xref, package descriptor, application package,
Wasm runtime, and Chromium version in newly generated reports.

The curated review branch was clean-built and browser-checked again on 2026-08-25. It preserves the
accepted source hash, Wasm hash, and package-set descriptor hash above. Its rebuilt
`VersoSearchVir.FullLean` package is 142,817 bytes with SHA-256
`de8c68441db6ba67e0e526258605348e4cd1b0684a24ebdfee54e4f48330564d`; the generated xref has
SHA-256 `2907a80a2472eca2a5bdc8f774591c12dc2b4cac4d5820beb87b905b96961e46`. These current identities are
recorded separately in `FULL_LEAN_RESULTS.json`: the seven-byte package difference is not evidence
for replacing the archived six-pass timings with a new performance claim.

The host-resource failure encountered during the rejected retained-string prototype was a consuming
`Element.innerHTML` binding, not a nested `RuntimeRef` defect. The repair and its lifecycle tests
belong to [VIR PR #147](https://github.com/ejgallego/lean-vir/pull/147); this curated Verso branch
keeps only the accepted renderer.

## Size

The archived accepted package set contained 43 IR members totaling 683,602 bytes, or 111,571 bytes
gzip. The retained-subtree renderer added 6,729 raw bytes and 2,050 gzip bytes over the escaped-HTML
control. The principal runtime, SDK, and application IR totaled 1,839,333 bytes raw or 368,278 bytes
gzip before small descriptors and bootstrap files. These opt-in development figures should be
refreshed before any production proposal.

## Reproduce

Build the package and exact published SDK:

```console
cd experiments/vir-search
lake build +VersoSearchVir.Runtime:vir
VIR_SDK_COMMIT=025e1bdd753b9077bced07be3cb36536f501ee40 lake build :virSdk
```

Given an existing generated multi-page site, stage and serve a separate demo:

```console
npm run stage-full-lean-demo -- ../../_out/html-multi ../../_out/full-lean-demo
python3 -m http.server 8769 --bind 127.0.0.1 --directory ../../_out/full-lean-demo
```

Run the browser differential and cache-churn check from the repository root:

```console
UV_CACHE_DIR=/tmp/verso-uv-cache \
  uv run --project browser-tests --extra test python \
  experiments/vir-search/full-lean-browser-test.py http://127.0.0.1:8769/
```

Run an order-balanced comparison from `experiments/vir-search`:

```console
npm run benchmark:full-lean -- \
  baseline=http://127.0.0.1:8770/ candidate=http://127.0.0.1:8771/ \
  --passes 6 --warm-repetitions 4 --cold-profile-repetitions 0 \
  --profile-dir ../../_out/full-lean-perf/profiles \
  --json-out ../../_out/full-lean-perf/report.json
```

Timing pages are uninstrumented. DOM counters and CPU sampling run on separate diagnostic pages.

## Production gaps

1. Add a generic fetch/text resource so the staging helper need not embed `xref.json` in a script.
2. Apply semantic, domain, and item priorities after an efficient public-score transform.
3. Complete multi-term overlap fidelity and broaden differential coverage beyond one mostly-ASCII
   fixture; decide whether exact-score ties should retain Lean's stable order.
4. Replace the built-in-domain and display-name switches with a typed mapping/presentation registry
   supporting extension domains, domain classes, titles, and custom renderers.
5. Resolve xref addresses against the document base URL as production JavaScript does, and test a
   manual served from a nested deployment prefix.
6. Add ArrowUp/ArrowDown, active-descendant, Escape, and Enter behavior before claiming accessibility
   equivalence with the production combobox.
7. Add full-text index ingestion, snippets, highlighting, priority normalization, and semantic/text
   result merging.
8. Measure retained DOM and host-resource memory on larger sites, and decide whether production needs
   stable `<ul>` identity rather than swapping equivalent cached lists.

## Alternatives considered

- Safely escaped `innerHTML` reduced cold boundary crossings but retained browser parsing.
- Caching retained JavaScript HTML strings was ownership-correct after VIR #147 but did not reduce
  DOM replacement and regressed repeat latency.
- A previous-prefix candidate cache did not shrink the fixture's candidate sets enough to help.
- The archived ASCII `ByteArray` representation is promising under the repaired runtime but remains
  too noisy to accept; it is independent follow-up work rather than part of this review branch.
