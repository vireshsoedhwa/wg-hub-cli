#!/usr/bin/env bats
#
# Tests for wg-reset-clients
#

setup() {
    load 'test_helper/common-setup'
    _common_setup

    source "$CONFIG_FILE"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "reports nothing to reset when no clients exist" {
    rm -f "$REGISTRY"

    source "${BATS_TEST_DIRNAME}/../bin/wg-reset-clients" --source-only 2>/dev/null || true
    run main
    assert_success
    assert_output --partial "Nothing to reset"
}

@test "aborts when user does not type yes" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY1\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    run bash -c "echo 'no' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-reset-clients'
    )"
    assert_failure
    assert_output --partial "Aborted"
}

@test "removes all peers from server config on confirmation" {
    cat > "${TEST_WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = YEJtMHh6N3NWWHV5TW1SWGE2Tkd6eWg0ZDRaZXJJVUE=

PostUp = iptables -A FORWARD -i wg0 -o wg0 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -o wg0 -j ACCEPT

[Peer]
# phone
PublicKey = PHONE_KEY
AllowedIPs = 10.50.0.10/32

[Peer]
# laptop
PublicKey = LAPTOP_KEY
AllowedIPs = 10.50.0.11/32
EOF

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tPHONE_KEY\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"
    echo -e "laptop\t10.50.0.11\tLAPTOP_KEY\tactive\t2024-01-02T00:00:00Z" >> "$REGISTRY"
    echo "fake" > "${CLIENT_DIR}/phone.conf"
    echo "fake" > "${CLIENT_DIR}/laptop.conf"

    run bash -c "echo 'yes' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-reset-clients'
    )"
    assert_success
    assert_output --partial "Clean state restored"

    # Server config should have no [Peer] blocks
    run cat "${TEST_WG_DIR}/wg0.conf"
    assert_output --partial "[Interface]"
    refute_output --partial "[Peer]"
    refute_output --partial "PHONE_KEY"
    refute_output --partial "LAPTOP_KEY"
}

@test "deletes all client config files" {
    cat > "${TEST_WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = YEJtMHh6N3NWWHV5TW1SWGE2Tkd6eWg0ZDRaZXJJVUE=

[Peer]
# device
PublicKey = DEV_KEY
AllowedIPs = 10.50.0.10/32
EOF

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "device\t10.50.0.10\tDEV_KEY\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"
    echo "fake" > "${CLIENT_DIR}/device.conf"

    run bash -c "echo 'yes' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-reset-clients'
    )"
    assert_success

    # No .conf files should remain
    run find "${CLIENT_DIR}" -name "*.conf" -type f
    assert_output ""
}

@test "deletes the registry file" {
    cat > "${TEST_WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = YEJtMHh6N3NWWHV5TW1SWGE2Tkd6eWg0ZDRaZXJJVUE=

[Peer]
# tablet
PublicKey = TAB_KEY
AllowedIPs = 10.50.0.10/32
EOF

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "tablet\t10.50.0.10\tTAB_KEY\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    run bash -c "echo 'yes' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-reset-clients'
    )"
    assert_success

    assert [ ! -f "$REGISTRY" ]
}

@test "creates backup before modifying server config" {
    cat > "${TEST_WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = YEJtMHh6N3NWWHV5TW1SWGE2Tkd6eWg0ZDRaZXJJVUE=

[Peer]
# bak-test
PublicKey = BAK_KEY
AllowedIPs = 10.50.0.10/32
EOF

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "bak-test\t10.50.0.10\tBAK_KEY\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    run bash -c "echo 'yes' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-reset-clients'
    )"
    assert_success
    assert_output --partial "Backup"

    run find "${TEST_WG_DIR}" -name "wg0.conf.bak.*" -type f
    assert_success
    assert [ -n "$output" ]
}
