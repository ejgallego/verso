#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
coord_root=$(realpath "$repo_root/../..")
manual_source=${VERSO_MANUAL_SOURCE:-"$coord_root/tmp-manual-full"}

default_refs=(
  "82c57c81"
  "01a3e168"
  "004792a2"
  "965f654a"
  "efc3ae65"
  "e79f0b58"
  "422b5243"
  "394e8231"
)

if [[ ! -d "$manual_source" ]]; then
  echo "manual source tree not found: $manual_source" >&2
  exit 1
fi

refs=("$@")
if [[ ${#refs[@]} -eq 0 ]]; then
  refs=("${default_refs[@]}")
fi

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
results_dir="$repo_root/Benchmark/ManualGenreScaling"
mkdir -p "$results_dir"
results_file="$results_dir/full_manual_series_${timestamp}.md"
tmp_root=$(mktemp -d /tmp/verso-full-manual-series.XXXXXX)

cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

copy_snapshot() {
  local ref=$1
  local dst=$2
  mkdir -p "$dst"
  git -C "$repo_root" archive "$ref" | tar -x -C "$dst"
  rm -rf "$dst/.git" "$dst/.lake" "$dst/Manual"
}

link_dependency_cache() {
  local dst=$1
  mkdir -p "$dst/.lake"
  ln -sfn "$repo_root/.lake/packages" "$dst/.lake/packages"
}

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
  local wrapper=$1
  local snapshot=$2

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
  local snapshot="$tmp_root/repo-${idx}"
  local wrapper="$tmp_root/wrapper-${idx}"
  local log_file="$tmp_root/${label}.log"

  copy_snapshot "$ref" "$snapshot"
  link_dependency_cache "$snapshot"
  make_wrapper "$wrapper" "$snapshot"

  echo "==> [$label] $ref" | tee -a "$tmp_root/series.log"
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
lines.append("# Full Manual Benchmark Series")
lines.append("")
lines.append("This file was generated by `Benchmark/benchmark_full_manual_series.sh`.")
lines.append("")
lines.append("| Step | Ref | Subject | Wall | Delta vs prev | Delta vs baseline | RSS |")
lines.append("| --- | --- | --- | --- | --- | --- | --- |")
for row in rows:
    if row["index"] == 1:
        delta_prev = "baseline"
    else:
        delta_prev = f"{row['delta_prev_secs']:+.2f}s ({row['delta_prev_pct']:+.2f}%)"
    delta_base = f"{row['delta_base_secs']:+.2f}s ({row['delta_base_pct']:+.2f}%)"
    lines.append(
        f"| {row['index']} | `{row['ref']}` | {row['subject']} | `{row['wall']}` | {delta_prev} | {delta_base} | `{row['rss_kb']}KB` |"
    )
lines.append("")
lines.append("## Notes")
lines.append("")
lines.append("- All runs use the copied-manual wrapper with the same compatibility patching as the other benchmark helpers.")
lines.append("- `965f654a` and `394e8231` are primarily profiling changes; any runtime change there should be treated as noise unless it repeats.")
lines.append("- `36a05a85`, `7180fc4b`, `d8f4852c`, and `b3dc9798` are doc-only commits and are intentionally excluded from this runtime series.")

results_file.write_text("\n".join(lines) + "\n")
print(results_file)
PY

echo "results written to $results_file"
