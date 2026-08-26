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

## Direct-DOM full-Lean reference

This branch adds the simplest full-Lean semantic quick-jump. A generic startup module mounts the
component, after which Lean decodes and maps xref data, prepares and scores targets, selects the best
thirty matches, constructs each DOM element, and handles input callbacks. It performs no result
cache and serves as the common behavioral and code-review parent for renderer alternatives.

Given an existing generated multi-page site, stage an independent demo with:

```console
npm run stage-full-lean-demo -- ../../_out/html-multi ../../_out/full-lean-demo
python3 -m http.server 8769 --bind 127.0.0.1 --directory ../../_out/full-lean-demo
```

Run `full-lean-browser-test.py` against the served URL for the JavaScript differential. The shared
performance harness can compare any two staged descendants without placing instrumentation in the
timing pages.

## Escaped-HTML cache alternative

This child branch replaces per-result DOM construction with safely escaped HTML strings and a
bounded sixteen-query Lean cache. Each update crosses the host boundary once through `innerHTML`;
cached queries avoid rescoring and re-encoding, but the browser still parses and replaces the list
subtree on every revisit.
