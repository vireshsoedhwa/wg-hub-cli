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

prompt_value() {
    local prompt="$1"
    local default="$2"
    local result
    read -r -p "  ${prompt} [${default}]: " result
    echo "${result:-$default}"
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

    if [[ -f "$CONFIG_FILE" ]]; then
        info "Config already exists: $CONFIG_FILE"
        read -r -p "  Overwrite with new values? [y/N]: " overwrite
        case "$overwrite" in
            [yY][eE][sS]|[yY]) ;;
            *)
                info "Keeping existing config."
                return
                ;;
        esac
    fi

    echo ""
    echo "--- Configuration ---"
    echo "Press Enter to accept the default shown in brackets."
    echo ""

    local wg_interface wg_conf vpn_subnet_prefix client_start client_end
    local server_endpoint client_allowed_ips client_dns reserved_ips apply_mode

    wg_interface=$(prompt_value "WireGuard interface" "wg0")
    wg_conf=$(prompt_value "WireGuard config path" "/etc/wireguard/${wg_interface}.conf")
    vpn_subnet_prefix=$(prompt_value "VPN subnet prefix (first 3 octets)" "10.50.0")
    client_start=$(prompt_value "Client IP range start (last octet)" "10")
    client_end=$(prompt_value "Client IP range end (last octet)" "250")
    server_endpoint=$(prompt_value "Server endpoint (public IP/DNS:port)" "localhost:51820")
    client_allowed_ips=$(prompt_value "Client AllowedIPs (split-tunnel routes)" "${vpn_subnet_prefix}.0/24")
    client_dns=$(prompt_value "Client DNS (leave empty for none)" "")
    reserved_ips=$(prompt_value "Reserved VPN IPs (space-separated)" "${vpn_subnet_prefix}.1 ${vpn_subnet_prefix}.2")
    apply_mode=$(prompt_value "Apply mode (restart or syncconf)" "restart")

    cat > "$CONFIG_FILE" <<EOF
# WireGuard interface and config
WG_INTERFACE="${wg_interface}"
WG_CONF="${wg_conf}"

# Generated client configs and registry
CLIENT_DIR="/etc/wireguard/clients"
REGISTRY="/etc/wireguard/clients/registry.tsv"

# VPN addressing
VPN_SUBNET_PREFIX="${vpn_subnet_prefix}"
CLIENT_START="${client_start}"
CLIENT_END="${client_end}"

# Server endpoint reachable by clients
SERVER_ENDPOINT="${server_endpoint}"

# Client routes
CLIENT_ALLOWED_IPS="${client_allowed_ips}"

# Optional DNS pushed to clients
CLIENT_DNS="${client_dns}"

# Reserved VPN IPs
RESERVED_IPS="${reserved_ips}"

# WireGuard restart mode
APPLY_MODE="${apply_mode}"
EOF

    chmod 600 "$CONFIG_FILE"
    echo ""
    info "Config written: $CONFIG_FILE"
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
    echo "  1. Review config if needed:  sudo nano $CONFIG_FILE"
    echo "  2. Add a client:             sudo wg-add-client <client-name>"
    echo ""
}

main "$@"
