# PR Title

perf: reduce manual elaboration overhead

# PR Body

## Summary

- add a sparse opt-in Verso elaboration profiler plus reusable manual benchmark scripts
- reduce hidden inline-Lean overhead by skipping unnecessary highlighting, info-tree, and stream-capture work
- speed up docstring Markdown heuristics with tactic-aware caching and hashed tactic lookup
- record benchmark results and follow-up findings for review

## Benchmarks

- Full copied manual, current branch vs `82c57c81`: `3:35.08 -> 3:22.40` (`-5.9%`)
- `Terms.lean`: hidden inline-Lean cuts reduced the representative page from roughly `24.44s` to `19.45s` in the early pass
- `Tactics/Reference.lean`: docstring heuristic work dropped from `30.36s` to `15.19s`
- `BuildTools/Lake/Config.lean`: docstring heuristic work dropped from `9.65s` to `5.35s`

More detail is in [PR_SUMMARY.md](/home/egallego/lean/verso/.worktrees/manual-genre-scaling/Benchmark/PR_SUMMARY.md).

## Reviewer Focus

- [Docstring.lean](/home/egallego/lean/verso/.worktrees/manual-genre-scaling/src/verso-manual/VersoManual/Docstring.lean)
  The main safe speedups are here: avoid repeated heuristic setup, cache tactic metadata, and replace repeated tactic-name scans with hashed lookup.
- [InlineLean.lean](/home/egallego/lean/verso/.worktrees/manual-genre-scaling/src/verso-manual/VersoManual/InlineLean.lean)
  Hidden inline-Lean blocks now skip work that was only needed for visible rendering or captured outputs; profiling breakdowns were added to justify the remaining tradeoffs.
- [Concrete.lean](/home/egallego/lean/verso/.worktrees/manual-genre-scaling/src/verso/Verso/Doc/Concrete.lean) and [Profile.lean](/home/egallego/lean/verso/.worktrees/manual-genre-scaling/src/verso/Verso/Doc/Elab/Profile.lean)
  The new profiler hooks are coarse-grained and opt-in, intended for build-time investigation rather than always-on instrumentation.

## Validation

- `lake build VersoManual`
- `bash Benchmark/profile_manual_page.sh Terms.lean`
- `bash Benchmark/profile_manual_page.sh Tactics/Reference.lean`
- `bash Benchmark/profile_manual_page.sh BuildTools/Lake/Config.lean`
- `bash Benchmark/time_full_manual_build.sh 82c57c81`

## Validation Notes

- `lake build` does not complete cleanly in this environment because `clang` crashes while compiling `VersoBlog.Generate.c.o`.
- `lake test` reaches the final native link step and then fails with an undefined `initialize_verso_VersoBlog_LiterateModuleDocs` symbol in `verso-tests`.
- The performance work in this branch was validated primarily with `lake build VersoManual` and the copied-manual benchmark scripts above.
