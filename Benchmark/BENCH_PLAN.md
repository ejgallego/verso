# Benchmark Plan

These scripts are meant to fix the earlier benchmark ambiguity.

## Goals

1. Measure manual elaboration per commit without rebuilding the Verso dependency snapshot during the timed run.
2. Measure the real downstream `reference-manual` build with the Verso dependency already built, so the timed run reflects the manual project rather than package compilation.

## Manual Elaboration Series

1. Run `Benchmark/prepare_manual_elab_series.sh`.
2. Verify the warm dependency reruns are quick.
3. Run `Benchmark/run_manual_elab_series.sh`.
4. Inspect `Benchmark/MANUAL_ELAB_SERIES.md`.

The timed `ManualDocs` builds should report no unexpected non-`Manual.*` rebuilt targets.

## Reference Manual Compare

1. Run `Benchmark/prepare_reference_manual_compare.sh`.
2. Verify the dependency preparation completes and the package snapshots are built.
3. Run `Benchmark/run_reference_manual_compare.sh`.
4. Inspect `Benchmark/REFERENCE_MANUAL_PREBUILT_COMPARE.md`.

The timed downstream builds should report no rebuilt `Verso*`, `MultiVerso*`, `SubVerso*`, or `VersoWeb*` dependency targets.
