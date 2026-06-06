#!/usr/bin/env bash
#
# common-setup.bash — Shared setup for all BATS tests.
#

_common_setup() {
    # Load BATS helpers
    load "${BATS_TEST_DIRNAME}/test_helper/bats-support/load"
    load "${BATS_TEST_DIRNAME}/test_helper/bats-assert/load"

    # Project root
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

    # Create isolated temp environment for each test
    export TEST_CONFIG_DIR="${BATS_TEST_TMPDIR}/etc/wg-hub-cli"
    export TEST_WG_DIR="${BATS_TEST_TMPDIR}/etc/wireguard"
    export TEST_CLIENT_DIR="${TEST_WG_DIR}/clients"
    export TEST_BIN_DIR="${BATS_TEST_TMPDIR}/bin"

    mkdir -p "$TEST_CONFIG_DIR" "$TEST_CLIENT_DIR" "$TEST_BIN_DIR"

    # Config file paths
    export CONFIG_FILE="${TEST_CONFIG_DIR}/config.env"
    export TEMPLATE_FILE="${TEST_CONFIG_DIR}/client.conf.template"

    # Install the template
    cp "${PROJECT_ROOT}/templates/client.conf.template" "$TEMPLATE_FILE"

    # Create a default test config
    cat > "$CONFIG_FILE" <<EOF
WG_INTERFACE="wg0"
WG_CONF="${TEST_WG_DIR}/wg0.conf"
CLIENT_DIR="${TEST_CLIENT_DIR}"
REGISTRY="${TEST_CLIENT_DIR}/registry.tsv"
VPN_SUBNET_PREFIX="10.50.0"
CLIENT_START="10"
CLIENT_END="250"
SERVER_ENDPOINT="203.0.113.1:51820"
CLIENT_ALLOWED_IPS="10.50.0.0/24"
CLIENT_DNS=""
RESERVED_IPS="10.50.0.1 10.50.0.2"
APPLY_MODE="restart"
EOF

    # Create a minimal wg0.conf
    cat > "${TEST_WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = YEJtMHh6N3NWWHV5TW1SWGE2Tkd6eWg0ZDRaZXJJVUE=
EOF

    # Install mock commands
    _install_mocks

    # Prepend mocks to PATH
    export PATH="${TEST_BIN_DIR}:${PATH}"

    # Override paths and enable test mode for scripts under test
    export WG_HUB_CLI_CONFIG="$CONFIG_FILE"
    export WG_HUB_CLI_TEMPLATE="$TEMPLATE_FILE"
    export WG_HUB_CLI_TESTING="1"
}

_install_mocks() {
    # Mock: wg
    cat > "${TEST_BIN_DIR}/wg" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    genkey)
        echo "bW9ja19wcml2YXRlX2tleV9iYXNlNjRfZW5jb2RlZA=="
        ;;
    pubkey)
        echo "bW9ja19wdWJsaWNfa2V5X2Jhc2U2NF9lbmNvZGVkXw=="
        ;;
    syncconf)
        exit 0
        ;;
    show)
        # Return mock wg show output
        cat <<'EOF'
interface: wg0
  public key: c2VydmVyX3B1YmxpY19rZXk=
  private key: (hidden)
  listening port: 51820

peer: bW9ja19wdWJsaWNfa2V5X2Jhc2U2NF9lbmNvZGVkXw==
  endpoint: 192.168.1.100:43210
  allowed ips: 10.50.0.10/32
  latest handshake: 1 minute, 30 seconds ago
  transfer: 1.23 MiB received, 4.56 MiB sent
  persistent keepalive: every 25 seconds
EOF
        ;;
    *)
        exit 0
        ;;
esac
MOCK
    chmod +x "${TEST_BIN_DIR}/wg"

    # Mock: wg-quick
    cat > "${TEST_BIN_DIR}/wg-quick" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    strip)
        # Output stripped config (no wg-quick extensions)
        grep -E '^\[|^PrivateKey|^ListenPort|^PublicKey|^AllowedIPs|^Endpoint|^PersistentKeepalive' \
            "/etc/wireguard/${2}.conf" 2>/dev/null || true
        ;;
    *)
        exit 0
        ;;
esac
MOCK
    chmod +x "${TEST_BIN_DIR}/wg-quick"

    # Mock: systemctl
    cat > "${TEST_BIN_DIR}/systemctl" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    is-active)
        exit 0
        ;;
    restart|enable)
        exit 0
        ;;
    *)
        exit 0
        ;;
esac
MOCK
    chmod +x "${TEST_BIN_DIR}/systemctl"

    # Mock: qrencode
    cat > "${TEST_BIN_DIR}/qrencode" <<'MOCK'
#!/usr/bin/env bash
echo "[QR CODE PLACEHOLDER]"
MOCK
    chmod +x "${TEST_BIN_DIR}/qrencode"
}
