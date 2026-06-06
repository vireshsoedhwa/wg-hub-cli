#!/usr/bin/env bash
#
# run-tests.sh — Run all BATS tests.
#
# Usage: ./test/run-tests.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BATS="${SCRIPT_DIR}/bats/bin/bats"

if [[ ! -x "$BATS" ]]; then
    echo "ERROR: BATS not found. Run: git submodule update --init --recursive"
    exit 1
fi

echo "=== Running wg-hub-cli tests ==="
echo ""

"$BATS" "${SCRIPT_DIR}"/*.bats "$@"
