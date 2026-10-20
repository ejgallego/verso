# Shared Lean linking on Linux

By default, Verso's Linux executables embed Lean, Lake, and their imported
Verso code. `supportInterpreter := true` exports symbols with `-rdynamic`;
it does not select dynamic linking on Linux.

To share the installed toolchain's Lean and Lake libraries across the
executables built in this repository, use:

```sh
lake -R -KsharedLean=true build
lake -KsharedLean=true exe verso-serve --help
lake -KsharedLean=true test
```

The package-level setting covers the CLI tools, example generators, and Errata
runners; new executable targets inherit it automatically. A small runtime-library
target remains because this Lake version does not expose a configurable shared
Lean runtime for Linux executables.
Verso and other package object files remain embedded in each executable.
The option applies only to Linux; other platforms retain Lake's existing
linking behavior. Lake caches the options used to elaborate its lakefile:
`-R` reconfigures it when switching modes. To return to the default, use
`lake -R -KsharedLean=false build`, without cleaning. Subsequent Lake commands
reuse the selected configuration until the next reconfiguration.

## Runtime requirements

Use `lake -KsharedLean=true exe <target>` or `lake env <binary>` so that
the dynamic loader can find the matching toolchain's shared libraries.
For direct execution outside Lake, include that toolchain's `lib/lean`
directory in `LD_LIBRARY_PATH`, or package its required shared libraries
with a suitable loader search path. The build does not embed an absolute
toolchain path in the executable.

Shared builds require the matching Lean toolchain at runtime. Copying a
binary alone is insufficient. Shared linking is most useful when Lean is
already installed or several executables share one runtime. If a complete
runtime is bundled for a single executable, total disk usage can be similar
to or larger than a static build. Runtime `.olean` and source files needed
by elaboration are additional to these native-library requirements.

## Why this is optional

Smaller executable files do not establish faster execution. In the historical
[Lean shared-library discussion](https://github.com/leanprover/lean4/pull/555#issuecomment-877332222),
the maintainer kept ordinary Lean programs statically linked because frequent
calls across shared-library boundaries, including allocator calls, could add
runtime overhead. Those experiments date from 2021 and do not establish the
cost for current Lean or for Verso. The current measurements below also show a
startup cost, so static linking remains the default.

## Size comparison

The following unstripped file sizes were measured on Linux x86_64 with
Lean 4.36.0-rc1, starting from Verso `d0a5f92e`. Both builds use the same
package object files; the shared build still embeds Verso code.
One MiB is 1,048,576 bytes.

| Executable | Static Lean (MiB) | Shared Lean (MiB) |
| --- | ---: | ---: |
| `verso` | 228.35 | 1.07 |
| `verso-serve` | 119.89 | 0.64 |
| `verso-html` | 246.21 | 18.35 |
| `verso-literate` | 245.83 | 17.97 |
| `verso-literate-html` | 246.36 | 18.50 |
| `verso-literate-plan` | 245.45 | 17.59 |
| `simplepage` | 242.40 | 15.30 |
| `usersguide` | 273.22 | 45.45 |

The required Lean/Lake shared libraries occupy another 240.89 MiB, stored
once. For the six CLI tools, total native-artifact size falls from
1,332.09 MiB to 315.02 MiB including those libraries, a 76.35% reduction.
Bundling only `usersguide` with those libraries instead takes 286.35 MiB,
compared with its 273.22 MiB static executable. These totals exclude system
libraries, Lean source and `.olean` files, and generated sites.

## Runtime comparison

These measurements use Linux x86_64 on an AMD Ryzen AI 9 HX 370 with Lean
4.36.0-rc1, `LEAN_NUM_THREADS=8`, and Lake's runtime environment. Execution is
directly through the native binaries, without fixed CPU affinity or frequency.
Builds and Lake startup are excluded. Each workload has one explicit warmup per
mode followed by 12 pairs, alternating static/shared and shared/static order,
with a warm filesystem and a fresh output directory for each generation run.
The binaries use the same compiled package objects. Every run exits successfully
and produces identical output hashes across modes.

| Workload | Static median | Shared median | Observed change |
| --- | ---: | ---: | ---: |
| UsersGuide single-page HTML generation | 323.9 ms | 335.7 ms | +3.6% |
| Elaborate/highlight `Verso.Doc.Concrete` | 2,167.9 ms | 2,236.9 ms | +3.2% |
| `verso-serve --help` startup | 33.9 ms | 42.2 ms | +24.5% (+8.3 ms) |

The startup regression is consistent across all 12 pairs. The two larger
workloads are noisier: exploratory 95% paired-bootstrap intervals for their
median relative changes span zero (UsersGuide: -4.5% to +8.8%; highlighting:
-0.4% to +14.9%). These runs establish a startup penalty, but do not resolve a
small steady-execution penalty. They do not establish the mechanism of any
slowdown or measure a cold filesystem, a clean build, or a larger manual.

The native commands, run from the repository root in Lake's environment, are:

```sh
.lake/build/bin/usersguide --output <fresh-directory> --without-tex --without-html-multi --with-html-single
.lake/build/bin/verso-literate Verso.Doc.Concrete <fresh-file.json>
.lake/build/bin/verso-serve --help
```

Repeat these with separately preserved static and shared executables; switch
linking modes using `lake -R -KsharedLean=<false-or-true> build` outside the timed
region. The table reports the change in the two medians; the uncertainty ranges
use paired per-run ratios, so they have a different aggregation rule.

## Validation

On Linux, run:

```sh
python3 scripts/test_shared_linking.py
```

The check builds eight representative executables in both modes, inspects
their ELF dependencies, and checks that switching back to static linking
relinks them. It compares elaboration of a new command elaborator and
`#eval`, a custom-genre HTML page, and the UsersGuide's single-page HTML
output. It saves executable byte sizes in `_out/shared-linking/sizes.json`.
It also checks startup of Errata's generated shared runner. The check
leaves the eight measured targets in their default static configuration.
