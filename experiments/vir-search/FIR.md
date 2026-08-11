# FIR native-Wasm follow-up

FIR is a promising second execution experiment for the Lean ranking core,
but it is not yet a dependency candidate for this Verso branch. VIR ships
Lean IR to a general browser interpreter; FIR specializes final LCNF into a
native Wasm module. That removes the interpreter dispatch which dominates
the current warm VIR measurements, at the cost of a less mature compiler,
runtime-closure, and browser ABI surface.

This note records exploratory results from 2026-08-11. The Verso source is
still frozen at `22f6fe34` on final Lean `v4.33.0`. FIR's `main` is pinned to
Lean 4.32, while the clean local `upgrade/lean-4.33` worktree used for the
compatibility probe was at `aa21731c9b9193154cfae1750710d5b1735977a5`.
That branch is research state, not a published or stable dependency.

## Relevant precedent

FIR already contains two integrations which make the route credible:

- `integration/verso-flat` closes the real Verso Slides
  `Std.Format.prettyM` workload into a zero-import module.
- `integration/illuminate-hit-scene` closes a substantially more demanding
  array-, structure-, and Float-heavy query into zero-import native Wasm.
  Its adapter keeps an encoded scene in module-owned memory and copies only
  query inputs and results across the boundary.

The second example is the closer architectural template for search ranking:
retain the candidate arrays in a module instance for one query, invoke a
small typed export, copy the ordered source references and scores out, and
rewind the arena.

## Probe results

The probes used the same priority formula, normalization, merge order, and
stable descending ordering as `ExperimentalVIR.rankCandidates`. They did not
change Verso source. The progressively reshaped versions below are compiler
diagnostics, not proposed replacements.

| Source shape | Result | Remaining boundary |
| --- | --- | --- |
| Existing higher-order ranker on FIR/Lean 4.32 | Capture reaches the specialized ranking closure, but resident lowering does not close the tagged/higher-order result path. | No runnable artifact. |
| First-order equivalent with the existing `UInt32`, `Float.ofBits`, and list-to-array choices on FIR/Lean 4.32 | 19,851-byte frontier, 127 functions. | Five imports: two packed-`UInt32` scalar projections, `Float.ofBits`, `Float.decLt`, and `Array.mk`; two runtime operations remain. |
| Boundary-shaped diagnostic using `Nat` source indices, a `priorityStep : Float` argument, and an array-only stable insertion | 20,254-byte Wasm module, 129 functions. | Only standard `Float.ofScientific` and `Float.decLt` imports; zero FIR runtime operations. |
| The same first-order algorithm on the FIR Lean 4.33 branch | The upstream `leanir` producer fails before FIR capture. | Private `Init` bodies such as `Init.While.repeatM` and `Array.forIn'Unsafe.loop` cannot be resolved. Replacing the `while` with tail recursion merely advances to the array-loop failure; the existing generic source similarly stops at `Array.foldlMUnsafe.fold`. |

The 20,254-byte number is evidence about closure shape, not a deployable-size
claim. It excludes the two imported Float operations, the JavaScript adapter,
and any shared runtime selected for the final package. Its input types also
differ deliberately from Verso's current boundary, so it is not suitable for
a performance comparison.

## What a FIR lane would replace

A FIR ranker would execute the same pure Lean definition already exercised by
the VIR lane. It would replace only the VIR interpreter and its ranking-call
codec for that export. JavaScript would still own fuzzysort, elasticlunr,
extension-domain fallback, result-object rehydration, and rendering. The
existing JavaScript ranker should remain the correctness oracle and failure
fallback; the VIR lane remains useful for portable IR experiments and the
JSON-heavy mapper.

The likely integration is therefore a third, separately selected experimental
provider rather than a transparent change to the current VIR provider:

1. Move the pure ranking types and definition into a small JSON-free Lean
   module without changing the algorithm.
2. Capture that entry with a final-Lean-4.33 FIR producer and link its exact
   resident frontier plus the standard Float boundary.
3. Add an instance-owned structured adapter for arrays of hits and arrays of
   ranked source references. JSON should remain available for the mapper, but
   it is not the efficient boundary for this hot loop.
4. Differential-test exact candidate order and the existing `1e-12` score
   tolerance against JavaScript and VIR, then reuse `benchmark.mjs` inputs to
   measure initialization, marshalling, and warm calls separately.

## Gates, in order

1. **Lean 4.33 producer:** make source-view compilation retain or resolve the
   private `Init` helpers generated for `while`, `for`, and `Array.foldl`.
   Source rewrites are not an acceptable long-term workaround.
2. **Exact runtime closure:** support the current packed `UInt32` projections,
   `Float.ofBits`, and `Array.mk`, or establish an equally faithful stable ABI.
   `Float.decLt` already belongs to FIR's standard external math runtime.
3. **Owned browser ABI:** implement allocation, decoding, result copying,
   rewind, malformed-input rejection, and repeated-call tests without exposing
   raw Wasm addresses.
4. **Performance gate:** compare the unchanged algorithm at 16, 64, and 256
   candidates. Native execution is the reason to pursue FIR, but structured
   marshalling may still dominate small calls, so no speedup should be assumed
   before this measurement.

The recommended next FIR action is gate 1 in FIR itself. Once the unchanged
Lean 4.33 ranker reaches resident linking, gates 2 and 3 are narrow enough to
justify a real third-lane benchmark in this experiment.
