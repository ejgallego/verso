#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: Benchmark/profile_manual_page.sh <manual-page>

Examples:
  Benchmark/profile_manual_page.sh Terms.lean
  Benchmark/profile_manual_page.sh /home/egallego/lean/verso/tmp-manual-full/Terms.lean
  Benchmark/profile_manual_page.sh Releases/v4_0_0-m1.lean

Environment:
  VERSO_MANUAL_PROFILE_DIR   Wrapper package cache directory
  VERSO_MANUAL_SOURCE        Manual source tree (defaults to tmp-manual-full)
  VERSO_MANUAL_PROFILE_FRESH Re-copy and re-patch the wrapper source tree if set to 1
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
coord_root=$(realpath "$repo_root/../..")
manual_source=${VERSO_MANUAL_SOURCE:-"$coord_root/tmp-manual-full"}
target_input=$1

if [[ ! -d "$manual_source" ]]; then
  echo "manual source tree not found: $manual_source" >&2
  exit 1
fi

normalize_relpath() {
  local input=$1
  local rel
  if [[ "$input" = "$manual_source/"* ]]; then
    rel=${input#"$manual_source"/}
  elif [[ "$input" = tmp-manual-full/* ]]; then
    rel=${input#tmp-manual-full/}
  else
    rel=$input
  fi
  rel=${rel#Manual/}
  rel=${rel#./}
  printf '%s\n' "$rel"
}

target_rel=$(normalize_relpath "$target_input")
target_file="$manual_source/$target_rel"
if [[ -n "${VERSO_MANUAL_PROFILE_DIR:-}" ]]; then
  wrapper_dir=$VERSO_MANUAL_PROFILE_DIR
else
  safe_name=$(printf '%s' "$target_rel" | tr '/.' '__' | tr -cd '[:alnum:]_-' )
  wrapper_dir="/tmp/verso-manual-profile-$safe_name"
fi

if [[ ! -f "$target_file" ]]; then
  echo "manual page not found: $target_file" >&2
  exit 1
fi

python_import_expr() {
  python3 - "$1" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
parts = ["Manual", *path.with_suffix("").parts]

def render(part: str) -> str:
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_']*", part):
        return part
    return f"«{part}»"

print(".".join(render(p) for p in parts))
PY
}

remove_target_artifacts() {
  local rel=$1
  local stem=${rel%.lean}
  local lib_root="$wrapper_dir/.lake/build/lib/lean"
  local ir_root="$wrapper_dir/.lake/build/ir"

  rm -f \
    "$lib_root/Manual/$stem.olean" \
    "$lib_root/Manual/$stem.ilean" \
    "$lib_root/Manual/$stem.trace" \
    "$lib_root/ProfileTarget.olean" \
    "$lib_root/ProfileTarget.ilean" \
    "$lib_root/ProfileTarget.trace" \
    "$ir_root/Manual/$stem.c" \
    "$ir_root/Manual/$stem.setup.json" \
    "$ir_root/ProfileTarget.c" \
    "$ir_root/ProfileTarget.setup.json"
}

setup_wrapper() {
  mkdir -p "$wrapper_dir/.lake/packages"

  if [[ "${VERSO_MANUAL_PROFILE_FRESH:-0}" = "1" || ! -d "$wrapper_dir/Manual" ]]; then
    rm -rf "$wrapper_dir/Manual"
    cp -a "$manual_source" "$wrapper_dir/Manual"
    python3 - "$wrapper_dir/Manual/Meta/Syntax.lean" <<'PY'
from pathlib import Path
import re
path = Path(__import__("sys").argv[1])
text = path.read_text()
text = text.replace(
    "  let (tagged, _) ← getBnf config isFirst stxs |>.run ⟨default, default, default, default⟩ {} {partContext := ⟨⟨default, default, default, default, default⟩, default⟩}\n",
    "  let (tagged, _) ← getBnf config isFirst stxs |>.run {\n    genreSyntax := default,\n    genre := default,\n    refsAllowed := default,\n    docReconstructionPlaceholder := default,\n    elabProfile? := default\n  } {} {partContext := ⟨⟨default, default, default, default, default⟩, default⟩}\n",
)
text = re.sub(r"\nnamespace Tests\n.*?\nend Tests\n", "\n", text, flags=re.S)
path.write_text(text)
PY
  fi

  ln -sfn "$repo_root" "$wrapper_dir/.lake/packages/verso"
  ln -sfn "$repo_root/.lake/packages/MD4Lean" "$wrapper_dir/.lake/packages/MD4Lean"
  ln -sfn "$repo_root/.lake/packages/plausible" "$wrapper_dir/.lake/packages/plausible"
  ln -sfn "$repo_root/.lake/packages/subverso" "$wrapper_dir/.lake/packages/subverso"

  cat >"$wrapper_dir/lakefile.lean" <<EOF
import Lake
open Lake DSL

package manualprofile where

require verso from "$repo_root"

lean_lib ManualDocs where
  srcDir := "."
  globs := #[.submodules \`Manual]
  leanOptions := #[⟨\`weak.verso.elab.profile, true⟩]

lean_lib ProfileTarget where
  srcDir := "."
  roots := #[\`ProfileTarget]
  leanOptions := #[⟨\`weak.verso.elab.profile, true⟩]
EOF

  cp "$repo_root/lean-toolchain" "$wrapper_dir/lean-toolchain"
}

setup_wrapper

import_expr=$(python_import_expr "$target_rel")
cat >"$wrapper_dir/ProfileTarget.lean" <<EOF
import $import_expr
EOF

remove_target_artifacts "$target_rel"

echo "wrapper: $wrapper_dir"
echo "page: $target_file"
echo "import: $import_expr"

(
  cd "$wrapper_dir"
  /usr/bin/time -f 'wall=%E rss=%MKB' lake build ProfileTarget
)
