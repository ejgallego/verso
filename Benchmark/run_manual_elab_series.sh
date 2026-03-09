#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
coord_root=$(realpath "$repo_root/../..")
manual_source=${VERSO_MANUAL_SOURCE:-"$coord_root/tmp-manual-full"}
bench_root=${MANUAL_ELAB_BENCH_ROOT:-/tmp/verso-manual-elab-bench}

default_refs=(
  "82c57c81"
  "01a3e168"
  "797280fd"
  "61fda1db"
  "777f9db3"
  "faba8c1e"
  "04fb057d"
)

if [[ ! -d "$manual_source" ]]; then
  echo "manual source tree not found: $manual_source" >&2
  exit 1
fi

refs=("$@")
if [[ ${#refs[@]} -eq 0 ]]; then
  refs=("${default_refs[@]}")
fi

for ref in "${refs[@]}"; do
  if [[ ! -f "$bench_root/$ref/snapshot/.lake/build/lib/lean/VersoManual.olean" ]]; then
    echo "snapshot for $ref is not prepared; run Benchmark/prepare_manual_elab_series.sh first" >&2
    exit 1
  fi
done

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
tmp_root=$(mktemp -d /tmp/verso-manual-elab-run.${timestamp}.XXXXXX)
results_file="$repo_root/Benchmark/MANUAL_ELAB_SERIES.md"

cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

patch_manual_copy() {
  local manual_dir=$1
  local verso_dir=$2
  cat >"$manual_dir/BasicTypes/String/ValidPos.lean" <<'EOF'
import VersoManual
import Manual.Meta

open Verso.Genre Manual
open Verso.Genre.Manual.InlineLean

set_option pp.rawOnError true

#doc (Manual) "Positions" =>
This compatibility wrapper omits the legacy `String.ValidPos` API page because the copied manual
source targets an older Lean string-position API than the current toolchain.
EOF
  python3 - "$manual_dir/Meta/Syntax.lean" "$verso_dir/src/verso/Verso/Doc/Elab/Monad.lean" <<'PY'
from pathlib import Path
import re, sys
syntax_path = Path(sys.argv[1])
monad_path = Path(sys.argv[2])
text = syntax_path.read_text()
monad_text = monad_path.read_text()
if "elabProfile?" in monad_text:
    replacement = "  let (tagged, _) ← getBnf config isFirst stxs |>.run {\n    genreSyntax := default,\n    genre := default,\n    refsAllowed := default,\n    docReconstructionPlaceholder := default,\n    elabProfile? := default\n  } {} {partContext := ⟨⟨default, default, default, default, default⟩, default⟩}\n"
else:
    replacement = "  let (tagged, _) ← getBnf config isFirst stxs |>.run {\n    genreSyntax := default,\n    genre := default,\n    refsAllowed := default,\n    docReconstructionPlaceholder := default\n  } {} {partContext := ⟨⟨default, default, default, default, default⟩, default⟩}\n"
text = text.replace(
    "  let (tagged, _) ← getBnf config isFirst stxs |>.run ⟨default, default, default, default⟩ {} {partContext := ⟨⟨default, default, default, default, default⟩, default⟩}\n",
    replacement,
)
text = re.sub(r"\nnamespace Tests\n.*?\nend Tests\n", "\n", text, flags=re.S)
syntax_path.write_text(text)
PY
}

make_wrapper() {
  local ref=$1
  local wrapper=$2
  local snapshot="$bench_root/$ref/snapshot"

  mkdir -p "$wrapper/.lake/packages"
  cp -a "$manual_source" "$wrapper/Manual"
  patch_manual_copy "$wrapper/Manual" "$snapshot"

  ln -sfn "$snapshot" "$wrapper/.lake/packages/verso"
  ln -sfn "$repo_root/.lake/packages/MD4Lean" "$wrapper/.lake/packages/MD4Lean"
  ln -sfn "$repo_root/.lake/packages/plausible" "$wrapper/.lake/packages/plausible"
  ln -sfn "$repo_root/.lake/packages/subverso" "$wrapper/.lake/packages/subverso"

  cat >"$wrapper/lakefile.lean" <<EOF
import Lake
open Lake DSL

package manualprofile where

require verso from "$snapshot"

lean_lib ManualDocs where
  srcDir := "."
  globs := #[.submodules \`Manual]
EOF

  cp "$repo_root/lean-toolchain" "$wrapper/lean-toolchain"
}

bench_ref() {
  local ref=$1
  local idx=$2
  local label="step${idx}"
  local wrapper="$tmp_root/wrapper-${idx}"
  local log_file="$tmp_root/${label}.log"

  make_wrapper "$ref" "$wrapper"
  echo "==> [$label] $ref"
  (
    cd "$wrapper"
    /usr/bin/time -f "${label} wall=%E rss=%MKB" lake build ManualDocs
  ) 2>&1 | tee "$log_file"
}

for i in "${!refs[@]}"; do
  bench_ref "${refs[$i]}" "$((i + 1))"
done

python3 - "$tmp_root" "$results_file" "${refs[@]}" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

tmp_root = Path(sys.argv[1])
results_file = Path(sys.argv[2])
refs = sys.argv[3:]

time_re = re.compile(r"step(\d+) wall=([0-9:.]+) rss=([0-9]+)KB")
built_re = re.compile(r"Built ([^(\n]+)")

def parse_duration(s: str) -> float:
    parts = s.split(":")
    if len(parts) == 2:
        m, sec = parts
        return int(m) * 60 + float(sec)
    if len(parts) == 3:
        h, m, sec = parts
        return int(h) * 3600 + int(m) * 60 + float(sec)
    raise ValueError(f"unexpected duration format: {s}")

rows = []
for i, ref in enumerate(refs, start=1):
    log = (tmp_root / f"step{i}.log").read_text()
    m = time_re.search(log)
    if not m:
        raise SystemExit(f"missing timing line for step {i}")
    wall = m.group(2)
    rss_kb = int(m.group(3))
    secs = parse_duration(wall)
    built = [m.group(1).strip() for m in built_re.finditer(log)]
    unexpected = sorted({x for x in built if not (x == "ManualDocs" or x.startswith("Manual."))})
    subject = subprocess.check_output(
        ["git", "show", "--no-patch", "--format=%s", ref],
        text=True,
    ).strip()
    rows.append({
        "index": i,
        "ref": ref,
        "subject": subject,
        "wall": wall,
        "secs": secs,
        "rss_kb": rss_kb,
        "unexpected": unexpected,
    })

baseline = rows[0]["secs"]
prev = None
for row in rows:
    if prev is None:
        row["delta_prev_secs"] = 0.0
        row["delta_prev_pct"] = 0.0
    else:
        row["delta_prev_secs"] = row["secs"] - prev["secs"]
        row["delta_prev_pct"] = 100.0 * (prev["secs"] - row["secs"]) / prev["secs"]
    row["delta_base_secs"] = row["secs"] - baseline
    row["delta_base_pct"] = 100.0 * (baseline - row["secs"]) / baseline
    prev = row

lines = []
lines.append("# Manual Elaboration Series")
lines.append("")
lines.append("This file was generated by `Benchmark/run_manual_elab_series.sh`.")
lines.append("")
lines.append("Each timed run uses a fresh wrapper package while reusing a prebuilt Verso snapshot dependency.")
lines.append("")
lines.append("| Step | Ref | Subject | Wall | Delta vs prev | Delta vs baseline | RSS | Dependency rebuilds |")
lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
for row in rows:
    if row["index"] == 1:
        delta_prev = "baseline"
    else:
        delta_prev = f"{row['delta_prev_secs']:+.2f}s ({row['delta_prev_pct']:+.2f}%)"
    delta_base = f"{row['delta_base_secs']:+.2f}s ({row['delta_base_pct']:+.2f}%)"
    dep_note = "none" if not row["unexpected"] else ", ".join(f"`{x}`" for x in row["unexpected"][:4])
    lines.append(
        f"| {row['index']} | `{row['ref']}` | {row['subject']} | `{row['wall']}` | {delta_prev} | {delta_base} | `{row['rss_kb']}KB` | {dep_note} |"
    )

lines.append("")
lines.append("## Notes")
lines.append("")
lines.append("- Any non-`Manual.*` built targets in the last column indicate the dependency prebuild was incomplete and the timing is not a pure manual-elaboration run.")
lines.append("- This benchmark intentionally excludes rebuilding the Verso dependency snapshot itself.")

results_file.write_text("\n".join(lines) + "\n")
print(results_file)
PY

echo "results written to $results_file"
