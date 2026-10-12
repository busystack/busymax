#!/usr/bin/env bash
# The supported production entry point. Never installs or uploads a package.
set -euo pipefail
exec python3 "$(dirname "$(readlink -f "$0")")/build_snap_local.py" "$@"
