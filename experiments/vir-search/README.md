# Experimental VIR search backend

This isolated Lake project packages Verso's pure domain-mapping and
candidate-ranking functions for the browser without making `lean_vir`
a mandatory dependency of Verso itself.

The experiment is frozen on Verso commit `22f6fe34`, the last upstream
commit before the Lean 4.34 bump, and follows its Lean `v4.33.0`
toolchain. It pins `lean_vir` at commit
`2ddbfad021eddce634a9ea74ba315492d7b96708`. Keeping VIR isolated here
makes the experiment reproducible without adding it to Verso's normal
dependency graph.

Build the package set and install the commit-pinned browser SDK with:

```console
lake build +VersoSearchVir.Runtime:vir
VIR_SDK_COMMIT=2ddbfad021eddce634a9ea74ba315492d7b96708 lake build :virSdk
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

There is still a narrower compatibility caveat: the SDK artifact
published at the pinned `lean_vir` commit was built with Lean
`v4.33.0-rc2`, while Verso and the generated package use the final
`v4.33.0` release. This experiment deliberately freezes both sides on
the 4.33 line; enforcing an exact producer/interpreter Lean revision
is follow-up work. The real Node and browser tests cover the current
pair, but it should not be treated as a general cross-revision
compatibility contract.

The current uncompressed experiment consists of 20 IR package members
(about 406 KiB), the production interpreter Wasm (about 720 KiB), and
about 404 KiB of SDK JavaScript. These assets are requested only when
the opt-in configuration is present. The staging helper deliberately
omits the unused 3.7 MiB development Wasm.

The dependency refresh to `lean_vir` `2ddbfad` was verified against its
clean published SDK artifact. It adds artifact packaging and browser
catalog support, but no interpreter change. On the same AMD Ryzen AI 9
HX 370, a representative refreshed run measured warm VIR ranking at
0.97 ms for 16 candidates, 9.52 ms for 64, and 98.26 ms for 256, or
427x, 489x, and 665x the JavaScript medians. Correctness and the
zero-host-import package report still pass.

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
