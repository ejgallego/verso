# Experimental VIR search backend

[FULL_LEAN.md](FULL_LEAN.md) documents the end-to-end Lean-owned semantic quick-jump lane. It uses a
VIR startup hook, generic DOM/event bindings, and a generic runtime bootstrap instead of exposing a
Verso-specific JavaScript API.

This isolated Lake project packages Verso's pure domain-mapping and
candidate-ranking functions for the browser without making `lean_vir`
a mandatory dependency of Verso itself.

The experiment is frozen on Verso commit `22f6fe34`, the last upstream
commit before the Lean 4.34 bump, and follows its Lean `v4.33.0`
toolchain. It pins `lean_vir` at commit
`025e1bdd753b9077bced07be3cb36536f501ee40`. Keeping VIR isolated here
avoids adding it to Verso's normal dependency graph. The exact commit and its
CI-produced SDK artifact are published by
[VIR draft PR #147](https://github.com/ejgallego/lean-vir/pull/147).

Build the package set and install the commit-pinned browser SDK with:

```console
lake build +VersoSearchVir.Runtime:vir
VIR_SDK_COMMIT=025e1bdd753b9077bced07be3cb36536f501ee40 lake build :virSdk
```

For local VIR development,
`VIR_SDK_ARCHIVE=/path/to/lean-vir-sdk.tar.gz` avoids downloading the
SDK. Run the real-runtime smoke test after both build steps:

```console
node smoke.mjs
```

The ranking export is host-independent. Lean owns priority
aggregation, the integer-exponent implementation of
`2^(deviation / 50)`, full-text normalization, stream merging, Float
comparison, and the stable sort. The browser adapter only installs
VIR's standard host bindings.

The mapper export also contains a narrowly scoped order correction for
object-member traversal in the current VIR interpreter. The native
mapper does not apply it. The real-`xref.json` browser test verifies
that the VIR output remains identical to JavaScript's `Object.entries`
order, including stable ties.

The repaired SDK and Verso package are both built with final Lean `v4.33.0`. The
commit-addressed facet above has downloaded the published artifact from the exact
`025e1bd` workflow successfully; `VIR_SDK_ARCHIVE` remains useful for unpublished
local VIR development.

The full-Lean experiment adds a 438-line semantic-search component and a 28-line
generic startup bootstrap. Its browser assets remain opt-in, and the staging helper
omits the unused development Wasm. [FULL_LEAN.md](FULL_LEAN.md) records exact package
sizes, artifact identities, the retained-DOM result, and the production gaps.

[FIR.md](FIR.md) evaluates FIR's native-Wasm route as a possible third
lane. A 20 KiB boundary-shaped probe nearly closes on FIR 4.32, but the
current FIR Lean 4.33 branch cannot yet capture the unchanged ranker
because the producer loses private `Init` loop helpers. The note records
the exact gaps and the staged integration plan without adding FIR as a
dependency.

To compare warm ranking calls against the production JavaScript
algorithm, run the deterministic Node microbenchmark after building
the package and SDK:

```console
npm run benchmark
```

It checks candidate order and scores before timing an empty-call
baseline and three synthetic working-set sizes. SDK import and
runtime/package initialization are reported separately from per-call
latency. This isolates the ranking boundary; it does not measure
fuzzysort, elasticlunr, DOM rendering, network transfer, or browser
startup. Use `node benchmark.mjs --json` to capture machine-readable
results.

To copy the package descriptor, all package members, and the browser
SDK into a generated site:

```console
node stage-assets.mjs ../../_out/html-multi
```

Enable the provider in a Manual configuration by setting:

```lean
experimentalSearchVir := some {
  runtimeModule := "-verso-search/vir/js/vir-runtime.js"
  wasmUrl := "-verso-search/vir/wasm/vir-upstream.wasm"
  packageSetUrl := "-verso-search/vir/VersoSearchVir/Runtime.irpkg-set.json"
}
```

Failure to load VIR, an unsupported extension domain, or a VIR call
error keeps the existing JavaScript implementation active as the
fallback.
