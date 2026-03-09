#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

default_refs=(
  "82c57c81"
  "01a3e168"
  "797280fd"
  "61fda1db"
  "777f9db3"
  "faba8c1e"
  "04fb057d"
)

bench_root=${MANUAL_ELAB_BENCH_ROOT:-/tmp/verso-manual-elab-bench}
force=${MANUAL_ELAB_BENCH_FORCE:-0}
verify=${MANUAL_ELAB_BENCH_VERIFY:-1}

refs=("$@")
if [[ ${#refs[@]} -eq 0 ]]; then
  refs=("${default_refs[@]}")
fi

prepare_snapshot() {
  local ref=$1
  local root="$bench_root/$ref"
  local snapshot="$root/snapshot"
  local verify_log="$root/verify.log"

  mkdir -p "$root"

  if [[ "$force" == "1" || ! -f "$snapshot/lakefile.lean" ]]; then
    rm -rf "$snapshot"
    mkdir -p "$snapshot"
    git -C "$repo_root" archive "$ref" | tar -x -C "$snapshot"
    rm -rf "$snapshot/.git" "$snapshot/.lake"
    mkdir -p "$snapshot/.lake"
    ln -sfn "$repo_root/.lake/packages" "$snapshot/.lake/packages"
  fi

  echo "==> preparing dependency snapshot $ref"
  (
    cd "$snapshot"
    lake build VersoManual
  )

  local built_olean
  built_olean=$(find "$snapshot/.lake/build/lib/lean" -name 'VersoManual.olean' -print -quit || true)
  if [[ -z "$built_olean" ]]; then
    echo "missing VersoManual.olean after prepare for $ref" >&2
    exit 1
  fi

  if [[ "$verify" == "1" ]]; then
    echo "==> verifying warm dependency build $ref"
    (
      cd "$snapshot"
      /usr/bin/time -f "verify wall=%E rss=%MKB" lake build VersoManual
    ) 2>&1 | tee "$verify_log"
  fi
}

mkdir -p "$bench_root"
for ref in "${refs[@]}"; do
  prepare_snapshot "$ref"
done

echo "prepared manual elaboration snapshots under $bench_root"
