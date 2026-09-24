#!/bin/bash
# Resolve relative to this skill, independently of the invoking working directory.
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
root=${RELEASE_MANAGEMENT_REPO:-$root}
if [ ! -f "$root/scripts/fbc-onboard.py" ]; then
  echo "Set RELEASE_MANAGEMENT_REPO to a submariner-release-management checkout" >&2
  exit 1
fi
exec "$root/scripts/add-fbc-ocp-version.sh" "$@"
