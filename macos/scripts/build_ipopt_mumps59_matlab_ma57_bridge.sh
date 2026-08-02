#!/usr/bin/env bash
# Compatibility entry point for the current full, clean-runtime build.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/build_full_ipopt_mumps59_matlab_ma57_bridge.sh" "$@"
