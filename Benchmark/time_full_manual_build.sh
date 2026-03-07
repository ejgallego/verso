#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
coord_root=$(realpath "$repo_root/../..")
manual_source=${VERSO_MANUAL_SOURCE:-"$coord_root/tmp-manual-full"}
baseline_ref=${1:-HEAD}

if [[ ! -d "$manual_source" ]]; then
  echo "manual source tree not found: $manual_source" >&2
  exit 1
fi

tmp_root=$(mktemp -d /tmp/verso-full-manual.XXXXXX)
before_repo="$tmp_root/repo-before"
after_repo="$tmp_root/repo-after"
before_wrap="$tmp_root/wrapper-before"
after_wrap="$tmp_root/wrapper-after"

cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

copy_worktree_snapshot() {
  local src=$1
  local dst=$2
  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/
  rm -rf "$dst/.git" "$dst/.lake" "$dst/Manual"
}

archive_baseline_snapshot() {
  local ref=$1
  local dst=$2
  mkdir -p "$dst"
  git -C "$repo_root" archive "$ref" | tar -x -C "$dst"
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

time_build() {
  local label=$1
  local wrapper=$2
  local log_file="$tmp_root/${label}.log"
  (
    cd "$wrapper"
    /usr/bin/time -f "${label} wall=%E rss=%MKB" lake build ManualDocs
  ) 2>&1 | tee "$log_file"
}

archive_baseline_snapshot "$baseline_ref" "$before_repo"
copy_worktree_snapshot "$repo_root" "$after_repo"
link_dependency_cache "$before_repo"
link_dependency_cache "$after_repo"
make_wrapper "$before_wrap" "$before_repo"
make_wrapper "$after_wrap" "$after_repo"

time_build before "$before_wrap"
time_build after "$after_wrap"
