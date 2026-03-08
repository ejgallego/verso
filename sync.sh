#!/usr/bin/env bash

set -euo pipefail

remote_host="x80"
noperthedron_src="_out/example-blueprints/noperthedron/html-multi/"
sphere_packing_src="_out/example-blueprints/spherepackingblueprint/html-multi/"
noperthedron_dst="/srv/www/Noperthedron/"
sphere_packing_dst="/srv/www/SpherePackingBlueprint/"

for path in "$noperthedron_src" "$sphere_packing_src"; do
  if [[ ! -d "$path" ]]; then
    echo "missing artifact directory: $path" >&2
    echo "run ./generate-example-blueprints.sh before syncing" >&2
    exit 1
  fi
done

rsync -avzp "$noperthedron_src" "${remote_host}:${noperthedron_dst}"
rsync -avzp "$sphere_packing_src" "${remote_host}:${sphere_packing_dst}"
