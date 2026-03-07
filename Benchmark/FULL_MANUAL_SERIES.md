# Full Manual Benchmark Series

This file was generated from the quiet sequential run using `Benchmark/benchmark_full_manual_series.sh`.

| Step | Ref | Subject | Wall | Delta vs prev | Delta vs baseline | RSS |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `82c57c81` | fix: article citation formatting (double period, spacing, number/pages) (#784) | `5:18.29` | baseline | +0.00s (+0.00%) | `2467276KB` |
| 2 | `01a3e168` | perf: remove quadratic manual traversal updates | `5:15.77` | -2.52s (+0.79%) | -2.52s (+0.79%) | `2530180KB` |
| 3 | `004792a2` | perf: prune manual elaboration overhead and add benchmark harness | `5:11.91` | -3.86s (+1.22%) | -6.38s (+2.00%) | `2421120KB` |
| 4 | `0de5f7fa` | perf: split inline Lean profiling by phase | `4:50.88` | -21.03s (+6.74%) | -27.41s (+8.61%) | `2458360KB` |
| 5 | `0abaecd7` | perf: skip hidden inline Lean info-tree generation | `3:22.90` | -87.98s (+30.25%) | -115.39s (+36.25%) | `2463280KB` |
| 6 | `3ff97965` | perf: skip hidden inline Lean stream capture | `3:22.82` | -0.08s (+0.04%) | -115.47s (+36.28%) | `2427120KB` |
| 7 | `17f5fc6a` | perf: cache docstring markdown tactic heuristics | `3:18.90` | -3.92s (+1.93%) | -119.39s (+37.51%) | `2451328KB` |
| 8 | `8a77e2cf` | perf: add inline Lean command-kind profiling | `3:19.60` | +0.70s (-0.35%) | -118.69s (+37.29%) | `2454876KB` |

## Notes

- All runs use the copied-manual wrapper with the same compatibility patching as the other benchmark helpers.
- `0de5f7fa` and `8a77e2cf` are primarily profiling changes; any runtime change there should be treated as noise unless it repeats.
- `7b726e94`, `ffd3ceef`, and `33a3064d` are doc-only commits and are intentionally excluded from this runtime series.
