#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./generate-example-blueprints.sh [OUTPUT_ROOT]

Build the Verso blueprint example artifacts.

The shared Lake build runs once up front. The generated executables are
then run in parallel so the artifact render phase does not race on
`.lake/`.

Defaults:
  OUTPUT_ROOT = _out/example-blueprints

Artifacts:
  - noperthedron
  - spherepackingblueprint
EOF
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if (( $# > 1 )); then
  usage >&2
  exit 1
fi

out_root="${1:-_out/example-blueprints}"
mkdir -p "$out_root"

declare -a pids=()
declare -a names=()

cleanup() {
  local status=$?
  if (( status != 0 )); then
    for pid in "${pids[@]:-}"; do
      kill "$pid" 2>/dev/null || true
    done
  fi
}

trap cleanup EXIT INT TERM

launch_build() {
  local exe="$1"
  local output_dir="$2"
  echo "[example-blueprints] building ${exe} -> ${output_dir}"
  ".lake/build/bin/${exe}" --output "$output_dir" &
  pids+=("$!")
  names+=("$exe")
}

echo "[example-blueprints] prebuilding executables"
lake build noperthedron spherepackingblueprint

launch_build noperthedron "$out_root/noperthedron"
launch_build spherepackingblueprint "$out_root/spherepackingblueprint"

status=0
for i in "${!pids[@]}"; do
  if wait "${pids[$i]}"; then
    echo "[example-blueprints] finished ${names[$i]}"
  else
    echo "[example-blueprints] failed ${names[$i]}" >&2
    status=1
  fi
done

if (( status != 0 )); then
  exit "$status"
fi

echo "[example-blueprints] outputs:"
readlink -f "$out_root/noperthedron"
readlink -f "$out_root/spherepackingblueprint"
