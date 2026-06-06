#!/usr/bin/env bash
#
# shellcheck.sh — Run ShellCheck on all project scripts.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v shellcheck &>/dev/null; then
    echo "ERROR: shellcheck not installed."
    echo "Install with: brew install shellcheck  (macOS)"
    echo "              sudo apt install shellcheck  (Debian/Ubuntu)"
    exit 1
fi

echo "Running ShellCheck..."
echo ""

shellcheck -x "${SCRIPT_DIR}/bin/wg-add-client"
shellcheck -x "${SCRIPT_DIR}/bin/wg-list-clients"
shellcheck -x "${SCRIPT_DIR}/bin/wg-show-client"
shellcheck -x "${SCRIPT_DIR}/bin/wg-remove-client"
shellcheck -x "${SCRIPT_DIR}/install.sh"

echo ""
echo "All scripts passed ShellCheck."
