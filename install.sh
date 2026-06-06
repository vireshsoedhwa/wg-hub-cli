#!/usr/bin/env bash
#
# install.sh — Install wg-hub-cli on a Linux WireGuard hub server.
#
# Usage: sudo ./install.sh
#

set -euo pipefail

CONFIG_DIR="/etc/wg-hub-cli"
CONFIG_FILE="${CONFIG_DIR}/config.env"
TEMPLATE_DEST="${CONFIG_DIR}/client.conf.template"
BIN_DEST="/usr/local/sbin/wg-add-client"
CLIENT_DIR="/etc/wireguard/clients"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
    echo "ERROR: $*" >&2
    exit 1
}

info() {
    echo ":: $*"
}

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

check_root() {
    [[ $EUID -eq 0 ]] || die "This installer must be run as root (use sudo)."
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        case "$ID" in
            debian|ubuntu)
                info "Detected OS: $PRETTY_NAME"
                ;;
            *)
                echo "WARNING: Unsupported OS '$ID'. This tool is tested on Debian/Ubuntu."
                read -r -p "Continue anyway? [y/N]: " response
                case "$response" in
                    [yY][eE][sS]|[yY]) ;;
                    *) die "Installation aborted." ;;
                esac
                ;;
        esac
    else
        echo "WARNING: Cannot detect OS (no /etc/os-release)."
        read -r -p "Continue anyway? [y/N]: " response
        case "$response" in
            [yY][eE][sS]|[yY]) ;;
            *) die "Installation aborted." ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
# Install dependencies
# ---------------------------------------------------------------------------

install_dependencies() {
    local to_install=()

    if ! command -v wg &>/dev/null; then
        to_install+=(wireguard wireguard-tools)
    fi

    if ! command -v qrencode &>/dev/null; then
        to_install+=(qrencode)
    fi

    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installing missing packages: ${to_install[*]}"
        apt-get update -qq
        apt-get install -y -qq "${to_install[@]}"
    else
        info "All dependencies already installed."
    fi
}

# ---------------------------------------------------------------------------
# Install files
# ---------------------------------------------------------------------------

install_config() {
    mkdir -p "$CONFIG_DIR"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        cp "${SCRIPT_DIR}/config/wg-hub-cli.example.env" "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        info "Installed example config: $CONFIG_FILE"
        info ">>> You MUST edit this file before using wg-add-client. <<<"
    else
        info "Config already exists: $CONFIG_FILE (not overwritten)"
    fi
}

install_template() {
    cp "${SCRIPT_DIR}/templates/client.conf.template" "$TEMPLATE_DEST"
    chmod 644 "$TEMPLATE_DEST"
    info "Installed template: $TEMPLATE_DEST"
}

install_bin() {
    cp "${SCRIPT_DIR}/bin/wg-add-client" "$BIN_DEST"
    chmod 755 "$BIN_DEST"
    info "Installed command: $BIN_DEST"
}

create_client_dir() {
    mkdir -p "$CLIENT_DIR"
    chmod 700 "$CLIENT_DIR"
    info "Client directory ready: $CLIENT_DIR"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    echo ""
    echo "=== wg-hub-cli installer ==="
    echo ""

    check_root
    detect_os
    install_dependencies
    install_config
    install_template
    install_bin
    create_client_dir

    echo ""
    echo "=== Installation complete ==="
    echo ""
    echo "Next steps:"
    echo "  1. Edit the config:  sudo nano $CONFIG_FILE"
    echo "  2. Set SERVER_ENDPOINT to your server's public IP or DNS name."
    echo "  3. Adjust VPN_SUBNET_PREFIX, CLIENT_ALLOWED_IPS, and RESERVED_IPS as needed."
    echo "  4. Add a client:     sudo wg-add-client <client-name>"
    echo ""
}

main "$@"
