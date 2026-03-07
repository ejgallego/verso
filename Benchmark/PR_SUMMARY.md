# Manual Elaboration Performance Summary

This branch measures copied-manual builds with the helper scripts in `Benchmark/`.
Use the numbers as local wall-clock signals, not additive percentages: different runs saw
different background load, wrapper cache state, and OS cache warmth.

## Commits And Measurements

### `7cc6fc56` `perf: speed up manual elaboration and add profiling harness`

- Full copied manual, no profiling: `7:36.31 -> 5:03.65` (`-33.4%`)
- Main changes:
  - docstring Markdown fast paths
  - hidden Lean highlighting fast path
  - sparse opt-in profiler and manual-page wrapper scripts

### `d9504d29` `perf: skip inline Lean info trees for hidden setup blocks`

- `Terms.lean` with profiling: `19.45s -> 18.47s` (`-5.0%`)
- Main change:
  - stop generating/pushing inline-Lean info trees for hidden unnamed setup blocks

### `fe21bd68` `perf: skip unnecessary inline Lean stream capture`

- `Terms.lean` with profiling:
  - patched average `27.14s`
  - baseline average `27.81s`
  - delta `-2.4%`
- Full copied manual, no profiling: `5:13.85 -> 4:25.56` (`-15.4%`)
- Main change:
  - skip per-command isolated stdout/stderr capture for hidden unnamed non-error inline Lean commands unless they contain `#eval`/`#eval!`

### `09e7db4d` `perf: speed up docstring markdown heuristics`

- `Tactics/Reference.lean` with profiling:
  - `30.36s -> 15.19s` (`-49.9%`)
  - `blockFromMarkdownWithLean`: `11.67s -> 5.69s`
  - `docstring`: `3.93s -> 1.91s`
- `BuildTools/Lake/Config.lean` with profiling:
  - `9.65s -> 5.35s` (`-44.6%`)
  - `blockFromMarkdownWithLean`: `212ms -> 122ms`
  - `docstring`: `253ms -> 139ms`
- Main changes:
  - cache tactic metadata across docstring Markdown elaboration using a tactic-aware environment fingerprint
  - replace repeated tactic-name linear scans with hashed lookup
  - reject non-keyword inline code before rebuilding keyword parser state

### `73849ddc` `perf: profile inline Lean command kinds`

- No runtime claim; profiling-only change when `-Dverso.elab.profile=true`
- Main findings:
  - `Terms.lean`: shown `#eval` commands dominate remaining inline-Lean time
  - `BasicTypes/Range.lean`: shown `#eval` commands and shown declarations dominate
  - hidden setup commands are small on both pages

## Current Total

- Full copied manual, no profiling, `82c57c81 -> 73849ddc`: `3:35.08 -> 3:22.40` (`-5.9%`)

## Reviewer Notes

- The strongest remaining named hotspot on tactic-heavy chapters was the docstring Markdown heuristic path, and `09e7db4d` addresses that directly.
- The command-kind profiling suggests the next inline-Lean win is not another hidden-setup cut: the remaining cost is mostly visible `#eval` work.
- `saveRefsInEnv` stayed negligible after the earlier work; it is no longer a priority target.

## Validation

- `lake build VersoManual` passes on the branch.
- `lake build` does not currently complete in this environment because `clang` crashes while compiling `VersoBlog.Generate.c.o`.
- `lake test` reaches the final native link step and then fails with an undefined `initialize_verso_VersoBlog_LiterateModuleDocs` symbol in `verso-tests`.
