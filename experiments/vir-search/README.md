# Experimental VIR search foundation

This isolated Lean 4.33 project packages Verso's shared domain mapper and candidate ranker for VIR.
It deliberately keeps `lean_vir` out of Verso's normal dependency graph so browser-integration and
full-Lean UI approaches can be reviewed as independent child branches.

Build the package set and run the real-runtime smoke test with:

```console
lake build +VersoSearchVir.Runtime:vir
VIR_SDK_COMMIT=40f2e3d02b6f7b5ca8026bd44e65bd99283c6c57 lake build :virSdk
node smoke.mjs
```

The isolated experiment uses the merged runtime-only VIR PR #152 commit rather than the separate
application-level `virWebAssets` dependency. Because this is an untagged revision, select its
commit-addressed CI SDK artifact explicitly with `VIR_SDK_COMMIT`; the facet verifies the archive's
revision before installation.

`VersoSearch.ExperimentalRanking` owns JSON-free candidate scoring, normalization, merging, and
stable ordering. `Verso.Search.ExperimentalVIR` owns built-in xref-domain mapping and the JSON
boundary used by the optional JavaScript-provider lane.

## JavaScript-provider approach

This branch keeps candidate collection, the search UI, and rendering in the existing JavaScript.
The optional provider maps built-in xref domains and ranks expanded candidates through VIR, while
unsupported domains and initialization failures retain the production JavaScript fallback.

Stage the SDK and package set into an existing generated site with:

```console
node stage-assets.mjs ../../_out/html-multi
```

Enable it through `Verso.Search.VirSearchConfig`; the generated configuration contains only runtime,
Wasm, package-set, and exported-entry locations.
