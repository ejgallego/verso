# Manual Performance Infra

This branch contains benchmark infrastructure and benchmark notes only.

It is intentionally separate from the perf-change branches so review of code changes is not mixed
with profiling hooks or benchmark harness evolution.

## Branch Roles

- `perf/manual-bench-infra`
  - benchmark scripts
  - benchmark plans
  - benchmark result snapshots
- `perf/manual-elab-review`
  - perf-impacting code changes only
  - no benchmark harness required for code review
- `perf/manual-genre-scaling`
  - research / instrumentation branch
  - extra profiling hooks and exploratory benchmark history

## Current Benchmarks

- `MANUAL_ELAB_SERIES.md`
  - isolated manual elaboration benchmark
  - Verso dependency snapshots are prebuilt before timing
  - timed runs should rebuild only `Manual.*`
- `REFERENCE_MANUAL_PREBUILT_COMPARE.md`
  - downstream `reference-manual` benchmark
  - dependency packages are prebuilt before timing
  - timed runs should not rebuild `Verso*` / `MultiVerso*` / `VersoWeb*`

## Important Caveat

Earlier benchmark files from the research branch mixed dependency compilation with manual builds.
Those are useful historical notes, but they should not be used as the main evidence for isolated
manual elaboration performance.
