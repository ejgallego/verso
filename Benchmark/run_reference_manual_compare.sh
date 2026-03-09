#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

bench_root=${REFERENCE_MANUAL_BENCH_ROOT:-/tmp/reference-manual-bench}
baseline_repo="$bench_root/reference-manual-baseline"
perf_repo="$bench_root/reference-manual-perf-branch"
baseline_label=${BASELINE_LABEL:-baseline}
perf_label=${PERF_LABEL:-perf-branch}
summary_file="$repo_root/Benchmark/REFERENCE_MANUAL_PREBUILT_COMPARE.md"

for repo in "$baseline_repo" "$perf_repo"; do
  if [[ ! -f "$repo/.lake/packages/verso/.lake/build/lib/lean/VersoManual.olean" ]]; then
    echo "prepared dependency build missing for $repo; run Benchmark/prepare_reference_manual_compare.sh first" >&2
    exit 1
  fi
done

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
tmp_root=$(mktemp -d /tmp/reference-manual-prebuilt.${timestamp}.XXXXXX)

cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

reset_project_outputs() {
  local repo=$1
  rm -rf "$repo/.lake/build" "$repo/_out" "$repo/_tutorial-out"
  rm -f "$repo/multi.json" "$repo/tutorials.json" "$repo/words.txt"
}

time_build() {
  local label=$1
  local repo=$2
  local output=$3
  local log_file="$tmp_root/${label}.log"
  (
    cd "$repo"
    chmod +x generate-html.sh
    export TEXMFVAR="$repo/.texlive-var"
    export TEXMFCACHE="$repo/.texlive-cache"
    mkdir -p "$TEXMFVAR" "$TEXMFCACHE"
    /usr/bin/time -f "${label} wall=%E rss=%MKB" ./generate-html.sh --mode preview --output "$output"
  ) 2>&1 | tee "$log_file"
}

reset_project_outputs "$baseline_repo"
reset_project_outputs "$perf_repo"

baseline_site="$tmp_root/site-$baseline_label"
perf_site="$tmp_root/site-$perf_label"
time_build "$baseline_label" "$baseline_repo" "$baseline_site"
time_build "$perf_label" "$perf_repo" "$perf_site"

python3 - "$tmp_root" "$summary_file" "$baseline_label" "$perf_label" "$baseline_site/reference" "$perf_site/reference" "$baseline_repo" "$perf_repo" <<'PY'
from pathlib import Path
import hashlib
import html
import re
import subprocess
import sys

tmp_root = Path(sys.argv[1])
summary_file = Path(sys.argv[2])
baseline_label = sys.argv[3]
perf_label = sys.argv[4]
baseline_ref = Path(sys.argv[5])
perf_ref = Path(sys.argv[6])
baseline_repo = Path(sys.argv[7])
perf_repo = Path(sys.argv[8])

comment_re = re.compile(r"<!--.*?-->", re.S)
script_style_re = re.compile(r"<(script|style)\b.*?</\1>", re.I | re.S)
tag_re = re.compile(r"<[^>]+>")
built_re = re.compile(r"Built ([^(\n]+)")

def parse_duration(s: str) -> float:
    parts = s.split(":")
    if len(parts) == 2:
        return int(parts[0]) * 60 + float(parts[1])
    if len(parts) == 3:
        return int(parts[0]) * 3600 + int(parts[1]) * 60 + float(parts[2])
    raise ValueError(s)

def extract_time(log_path: Path, label: str):
    text = log_path.read_text()
    m = re.search(rf"{re.escape(label)} wall=([0-9:.]+) rss=([0-9]+)KB", text)
    if not m:
        raise SystemExit(f"missing timing line for {label}")
    wall = m.group(1)
    rss = int(m.group(2))
    secs = parse_duration(wall)
    return wall, rss, secs, text

def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1 << 20)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()

def collect_files(root: Path):
    out = {}
    for p in sorted(root.rglob("*")):
        if p.is_file():
            out[str(p.relative_to(root))] = p
    return out

def compare_sets(base_root: Path, perf_root: Path, predicate):
    base = {k: v for k, v in collect_files(base_root).items() if predicate(k)}
    perf = {k: v for k, v in collect_files(perf_root).items() if predicate(k)}
    only_base = sorted(set(base) - set(perf))
    only_perf = sorted(set(perf) - set(base))
    differing = sorted(k for k in set(base) & set(perf) if sha(base[k]) != sha(perf[k]))
    return only_base, only_perf, differing

def visible_text(path: Path) -> str:
    text = path.read_text(errors="ignore")
    text = script_style_re.sub(" ", text)
    text = comment_re.sub(" ", text)
    text = tag_re.sub(" ", text)
    text = html.unescape(text)
    return re.sub(r"\s+", " ", text).strip()

def is_public_html(path: str) -> bool:
    return path.endswith(".html")

def is_public_asset(path: str) -> bool:
    if path.startswith("-verso-"):
        return False
    return Path(path).suffix in {".css", ".js", ".svg", ".png", ".jpg", ".woff", ".woff2", ".ttf"}

def is_internal(path: str) -> bool:
    return path.startswith("-verso-") or path.endswith(".json") or path.endswith(".txt")

base_wall, base_rss, base_secs, base_log = extract_time(tmp_root / f"{baseline_label}.log", baseline_label)
perf_wall, perf_rss, perf_secs, perf_log = extract_time(tmp_root / f"{perf_label}.log", perf_label)

html_base_only, html_perf_only, html_diff = compare_sets(baseline_ref, perf_ref, is_public_html)
asset_base_only, asset_perf_only, asset_diff = compare_sets(baseline_ref, perf_ref, is_public_asset)
internal_base_only, internal_perf_only, internal_diff = compare_sets(baseline_ref, perf_ref, is_internal)

base_files = collect_files(baseline_ref)
perf_files = collect_files(perf_ref)
html_visible_text_diff = sorted(
    rel for rel in html_diff
    if visible_text(base_files[rel]) != visible_text(perf_files[rel])
)
html_visible_text_ws_only = sorted(
    rel for rel in html_visible_text_diff
    if re.sub(r"\s+", "", visible_text(base_files[rel])) == re.sub(r"\s+", "", visible_text(perf_files[rel]))
)
html_visible_text_non_ws = sorted(rel for rel in html_visible_text_diff if rel not in html_visible_text_ws_only)

def built_deps(log_text: str):
    deps = []
    for m in built_re.finditer(log_text):
        name = m.group(1).strip()
        if name.startswith(("Verso", "MultiVerso", "SubVerso", "VersoWeb")):
            deps.append(name)
    return sorted(set(deps))

base_dep_builds = built_deps(base_log)
perf_dep_builds = built_deps(perf_log)

def pin_desc(repo: Path) -> str:
    text = (repo / "lakefile.lean").read_text()
    m = re.search(r'require verso from git "([^"]+)"@"([^"]+)"', text)
    if not m:
        return "unknown"
    return f"`{m.group(1)}` @ `{m.group(2)}`"

delta_secs = perf_secs - base_secs
delta_pct = 100.0 * (base_secs - perf_secs) / base_secs

lines = []
lines.append("# Reference Manual Prebuilt-Dependency Comparison")
lines.append("")
lines.append(f"- Baseline build: `{base_wall}` (`{base_rss}KB` RSS)")
lines.append(f"- Branch build: `{perf_wall}` (`{perf_rss}KB` RSS)")
lines.append(f"- Delta: `{delta_secs:+.2f}s` (`{delta_pct:+.2f}%`)")
lines.append(f"- Baseline Verso pin: {pin_desc(baseline_repo)}")
lines.append(f"- Branch Verso pin: {pin_desc(perf_repo)}")
lines.append("")
lines.append("## Dependency Audit")
lines.append("")
lines.append(f"- Baseline built dependency targets during timed run: `{len(base_dep_builds)}`")
lines.append(f"- Branch built dependency targets during timed run: `{len(perf_dep_builds)}`")
if base_dep_builds:
    lines.extend(f"- Baseline unexpected rebuild: `{x}`" for x in base_dep_builds[:20])
if perf_dep_builds:
    lines.extend(f"- Branch unexpected rebuild: `{x}`" for x in perf_dep_builds[:20])
lines.append("")
lines.append("## Artifact Comparison")
lines.append("")
lines.append(f"- Public HTML files differing: `{len(html_diff)}`")
lines.append(f"- Public HTML files with differing visible text: `{len(html_visible_text_diff)}`")
lines.append(f"- Public HTML files with whitespace-only visible-text changes: `{len(html_visible_text_ws_only)}`")
lines.append(f"- Public HTML files with non-whitespace visible-text changes: `{len(html_visible_text_non_ws)}`")
lines.append(f"- Public HTML files only in baseline: `{len(html_base_only)}`")
lines.append(f"- Public HTML files only in branch: `{len(html_perf_only)}`")
lines.append(f"- Public asset files differing: `{len(asset_diff)}`")
lines.append(f"- Internal/generated files differing: `{len(internal_diff)}`")
if html_visible_text_non_ws:
    lines.append("")
    lines.append("### HTML Files With Non-Whitespace Visible Text Changes")
    lines.extend(f"- `{p}`" for p in html_visible_text_non_ws[:40])
lines.append("")
lines.append("## Paths")
lines.append("")
lines.append(f"- Baseline artifact root: `{baseline_ref}`")
lines.append(f"- Branch artifact root: `{perf_ref}`")
lines.append(f"- Raw baseline log: `{tmp_root / (baseline_label + '.log')}`")
lines.append(f"- Raw branch log: `{tmp_root / (perf_label + '.log')}`")

summary_file.write_text("\n".join(lines) + "\n")
print(summary_file)
PY

echo "summary written to $summary_file"
echo "tmp outputs preserved under $tmp_root"
