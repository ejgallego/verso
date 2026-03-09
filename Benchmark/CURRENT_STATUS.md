# Current Status

This file is the shortest reliable summary of the current manual-performance investigation.

## Branch Roles

- `perf/manual-elab-review`
  - perf-impacting code changes only
- `perf/manual-bench-infra`
  - benchmark scripts, benchmark plans, and benchmark result snapshots
- `perf/manual-genre-scaling`
  - exploratory profiling / instrumentation history

## Reliable Results

### Isolated manual elaboration

Source: [MANUAL_ELAB_SERIES.md](/home/egallego/lean/verso/.worktrees/manual-bench-infra/Benchmark/MANUAL_ELAB_SERIES.md)

- Baseline `82c57c81`: `3:33.39`
- Branch `04fb057d`: `2:48.03`
- Total improvement: `+21.26%`

Important sub-result:

- `01a3e168` alone improves this isolated benchmark only slightly:
  - `3:33.39 -> 3:30.45`
  - `+1.38%`

That means the earlier larger apparent gain for `01a3e168` came from a mixed benchmark setup and
should not be reused.

### Downstream `reference-manual` build with prebuilt dependencies

Source: [REFERENCE_MANUAL_PREBUILT_COMPARE.md](/home/egallego/lean/verso/.worktrees/manual-bench-infra/Benchmark/REFERENCE_MANUAL_PREBUILT_COMPARE.md)

- Baseline `82c57c81`: `4:13.20`
- Branch `04fb057d`: `5:46.22`
- Total change: `-36.74%` relative to baseline, i.e. slower

Important validation point:

- both timed runs rebuilt `0` dependency targets during timing

So this is a real downstream regression under the current harness, not an artifact of rebuilding
Verso during the timed run.

## Current Conclusion

- The perf stack improves isolated manual elaboration.
- The same stack regresses the prebuilt downstream full build.
- Therefore we cannot currently claim an end-to-end performance win for the branch.

## What To Do Next

1. Investigate where the downstream regression comes from.
2. Keep perf code review separate from benchmark/tooling review.
3. Avoid citing older mixed benchmark files as primary evidence.
