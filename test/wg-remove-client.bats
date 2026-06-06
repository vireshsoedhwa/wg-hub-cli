#!/usr/bin/env bats
#
# Tests for wg-remove-client
#

setup() {
    load 'test_helper/common-setup'
    _common_setup

    source "$CONFIG_FILE"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "fails with no client name argument" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-remove-client" --source-only 2>/dev/null || true

    run main ""
    assert_failure
    assert_output --partial "Usage"
}

@test "fails when client not found in registry" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"

    source "${BATS_TEST_DIRNAME}/../bin/wg-remove-client" --source-only 2>/dev/null || true
    run main "ghost"
    assert_failure
    assert_output --partial "not found"
}

@test "fails when client already removed" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY1\tremoved\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    source "${BATS_TEST_DIRNAME}/../bin/wg-remove-client" --source-only 2>/dev/null || true
    run main "phone"
    assert_failure
    assert_output --partial "already removed"
}

@test "aborts when user says no to confirmation" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY1\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    run bash -c "echo 'n' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-remove-client' phone
    )"
    assert_failure
    assert_output --partial "Aborted"
}

@test "removes peer from server config on confirmation" {
    cat > "${TEST_WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = YEJtMHh6N3NWWHV5TW1SWGE2Tkd6eWg0ZDRaZXJJVUE=

[Peer]
# phone
PublicKey = PHONE_PUBLIC_KEY
AllowedIPs = 10.50.0.10/32

[Peer]
# laptop
PublicKey = LAPTOP_PUBLIC_KEY
AllowedIPs = 10.50.0.11/32
EOF

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tPHONE_PUBLIC_KEY\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"
    echo -e "laptop\t10.50.0.11\tLAPTOP_PUBLIC_KEY\tactive\t2024-01-02T00:00:00Z" >> "$REGISTRY"
    echo "fake config" > "${CLIENT_DIR}/phone.conf"

    run bash -c "echo 'y' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-remove-client' phone
    )"
    assert_success
    assert_output --partial "removed successfully"

    # Verify peer was removed from wg0.conf
    run cat "${TEST_WG_DIR}/wg0.conf"
    refute_output --partial "PHONE_PUBLIC_KEY"
    # Laptop peer should still be there
    assert_output --partial "LAPTOP_PUBLIC_KEY"
}

@test "updates registry status to removed" {
    cat > "${TEST_WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = YEJtMHh6N3NWWHV5TW1SWGE2Tkd6eWg0ZDRaZXJJVUE=

[Peer]
# tablet
PublicKey = TABLET_KEY
AllowedIPs = 10.50.0.12/32
EOF

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "tablet\t10.50.0.12\tTABLET_KEY\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"
    echo "fake" > "${CLIENT_DIR}/tablet.conf"

    run bash -c "echo 'y' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-remove-client' tablet
    )"
    assert_success

    # Check registry was updated
    run grep "tablet" "$REGISTRY"
    assert_output --partial "removed"
}

@test "deletes client config file" {
    cat > "${TEST_WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = YEJtMHh6N3NWWHV5TW1SWGE2Tkd6eWg0ZDRaZXJJVUE=

[Peer]
# device
PublicKey = DEVICE_KEY
AllowedIPs = 10.50.0.13/32
EOF

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "device\t10.50.0.13\tDEVICE_KEY\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"
    echo "fake" > "${CLIENT_DIR}/device.conf"

    run bash -c "echo 'y' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-remove-client' device
    )"
    assert_success

    # Config file should be gone
    assert [ ! -f "${CLIENT_DIR}/device.conf" ]
}

@test "creates backup before modifying server config" {
    cat > "${TEST_WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = 10.50.0.1/24
ListenPort = 51820
PrivateKey = YEJtMHh6N3NWWHV5TW1SWGE2Tkd6eWg0ZDRaZXJJVUE=

[Peer]
# backup-test
PublicKey = BACKUP_KEY
AllowedIPs = 10.50.0.14/32
EOF

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "backup-test\t10.50.0.14\tBACKUP_KEY\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"
    echo "fake" > "${CLIENT_DIR}/backup-test.conf"

    run bash -c "echo 'y' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-remove-client' backup-test
    )"
    assert_success
    assert_output --partial "Backup"

    # A .bak file should exist
    run find "${TEST_WG_DIR}" -name "wg0.conf.bak.*" -type f
    assert_success
    assert [ -n "$output" ]
}
