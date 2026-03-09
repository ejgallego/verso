#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

refman_source=${REFMAN_SOURCE:-/tmp/reference-manual}
bench_root=${REFERENCE_MANUAL_BENCH_ROOT:-/tmp/reference-manual-bench}
baseline_verso_git_url=${BASELINE_VERSO_GIT_URL:-https://github.com/leanprover/verso.git}
baseline_verso_git_rev=${BASELINE_VERSO_GIT_REV:-82c57c81}
perf_verso_git_url=${VERSO_GIT_URL:-https://github.com/ejgallego/verso.git}
perf_verso_git_rev=${VERSO_GIT_REV:-$(git -C "$repo_root" rev-parse HEAD)}
force=${REFERENCE_MANUAL_BENCH_FORCE:-0}

baseline_repo="$bench_root/reference-manual-baseline"
perf_repo="$bench_root/reference-manual-perf-branch"

if [[ ! -d "$refman_source" ]]; then
  echo "reference manual source not found: $refman_source" >&2
  exit 1
fi

copy_repo() {
  local src=$1
  local dst=$2
  if [[ "$force" == "1" ]]; then
    rm -rf "$dst"
  fi
  if [[ ! -d "$dst" ]]; then
    mkdir -p "$dst"
    cp -a "$src"/. "$dst"/
    rm -rf "$dst/.git" "$dst/.lake" "$dst/_out" "$dst/_build" "$dst/_tutorial-out"
    rm -f "$dst"/multi.json "$dst"/tutorials.json "$dst"/words.txt
  fi
}

patch_repo_verso_dep() {
  local dst=$1
  local dep_git_url=$2
  local dep_git_rev=$3
  python3 - "$dst/lakefile.lean" "$dep_git_url" "$dep_git_rev" <<'PY'
from pathlib import Path
import re
import sys
lakefile = Path(sys.argv[1])
dep_git_url = sys.argv[2]
dep_git_rev = sys.argv[3]
text = lakefile.read_text()
new = f'require verso from git "{dep_git_url}"@"{dep_git_rev}"'
text2, n = re.subn(r'require verso from git "[^"]+"@"[^"]+"', new, text, count=1)
if n != 1:
    raise SystemExit("failed to rewrite verso git dependency in lakefile.lean")
lakefile.write_text(text2)
PY
  rm -f "$dst/lake-manifest.json"
}

patch_font_compat() {
  local dst=$1
  python3 - "$dst/figures/coe-chain.tex" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
old = r"\setmathfont{TeX Gyre Schola Math}"
new = r"\setmathfont{Latin Modern Math}"
if old in text:
    path.write_text(text.replace(old, new, 1))
PY
}

patch_tutorial_theme_compat() {
  local dst=$1
  python3 - "$dst/Tutorial/Meta/Theme.lean" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
old = """  let menuItems := #[navFroItem path] ++ froPathItems path

  return {
    leftItems := leftItems
    rightItems := rightItems
    menuItems := menuItems
    externalLinks := externalLinks
    subNavBar := if isFro path then some (SubNavBarConfig.mk (froPathItems path)) else none
  }
"""
new = """  let menuItems := #[navFroItem path] ++ froPathItems path
  let items : Array NavBarEntry :=
    leftItems.map NavBarEntry.item ++
    #[.divider] ++
    externalLinks.map NavBarEntry.item ++
    #[.divider .right] ++
    (rightItems.map fun item => .item { item with align := .right, display := .desktop }) ++
    #[.group {
      label := "FRO"
      url := some "/fro"
      display := .mobile
      items := menuItems
    }]

  return {
    items := items
    subNavBar := if isFro path then some (SubNavBarConfig.mk (froPathItems path)) else none
  }
"""
if old in text:
    path.write_text(text.replace(old, new, 1))
PY
}

prepare_one() {
  local repo=$1
  local url=$2
  local rev=$3
  echo "==> preparing $(basename "$repo") against $rev"
  patch_repo_verso_dep "$repo" "$url" "$rev"
  patch_font_compat "$repo"
  patch_tutorial_theme_compat "$repo"
  (
    cd "$repo"
    lake update
    (cd .lake/packages/verso && lake build VersoManual)
    (cd .lake/packages/versowebcomponents && lake build)
  )
}

mkdir -p "$bench_root"
copy_repo "$refman_source" "$baseline_repo"
copy_repo "$refman_source" "$perf_repo"
prepare_one "$baseline_repo" "$baseline_verso_git_url" "$baseline_verso_git_rev"
prepare_one "$perf_repo" "$perf_verso_git_url" "$perf_verso_git_rev"

echo "prepared reference manual benchmark repos under $bench_root"
