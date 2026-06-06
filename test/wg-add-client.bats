#!/usr/bin/env bats
#
# Tests for wg-add-client
#

setup() {
    load 'test_helper/common-setup'
    _common_setup

    # Source the script's functions (override CONFIG_FILE path)
    # We need to patch the script to use our test config
    export CONFIG_FILE
    export TEMPLATE_FILE
    source "$CONFIG_FILE"
}

# ---------------------------------------------------------------------------
# Validation tests
# ---------------------------------------------------------------------------

@test "rejects empty client name" {
    run bash -c "
        source '${CONFIG_FILE}'
        source '${BATS_TEST_DIRNAME}/../bin/wg-add-client' <<< '' 2>&1
    " -- ""
    assert_failure
}

@test "rejects invalid client name with spaces" {
    # Source the function directly
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    run validate_client_name "my client"
    assert_failure
    assert_output --partial "Invalid client name"
}

@test "rejects client name with special characters" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    run validate_client_name 'client@home'
    assert_failure
    assert_output --partial "Invalid client name"
}

@test "accepts valid client name with letters" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    run validate_client_name "my-phone"
    assert_success
}

@test "accepts valid client name with dots and underscores" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    run validate_client_name "laptop_work.2"
    assert_success
}

@test "rejects client name longer than 64 characters" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    local long_name
    long_name=$(printf 'a%.0s' {1..65})
    run validate_client_name "$long_name"
    assert_failure
    assert_output --partial "too long"
}

# ---------------------------------------------------------------------------
# Duplicate detection tests
# ---------------------------------------------------------------------------

@test "rejects duplicate client name in registry" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    # Create registry with existing client
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY123\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    run check_duplicate_client "phone"
    assert_failure
    assert_output --partial "already exists"
}

@test "allows new client name not in registry" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY123\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    run check_duplicate_client "laptop"
    assert_success
}

@test "allows re-adding a previously removed client" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY123\tremoved\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    run check_duplicate_client "phone"
    assert_success

    # Old entry should be removed from registry
    run grep "^phone" "$REGISTRY"
    assert_failure
}

@test "rejects client if config file already exists" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    touch "${CLIENT_DIR}/existing.conf"

    run check_duplicate_client "existing"
    assert_failure
    assert_output --partial "already exists"
}

# ---------------------------------------------------------------------------
# IP assignment tests
# ---------------------------------------------------------------------------

@test "assigns first available IP (10.50.0.10)" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    run find_next_free_ip
    assert_success
    assert_output "10.50.0.10"
}

@test "skips reserved IPs" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    # Reserve .10 as well
    RESERVED_IPS="10.50.0.1 10.50.0.2 10.50.0.10"

    run find_next_free_ip
    assert_success
    assert_output "10.50.0.11"
}

@test "skips IPs already in wg0.conf" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    # Add a peer with .10 to wg0.conf
    cat >> "$WG_CONF" <<EOF

[Peer]
# existing-client
PublicKey = somekey123
AllowedIPs = 10.50.0.10/32
EOF

    run find_next_free_ip
    assert_success
    assert_output "10.50.0.11"
}

@test "skips IPs already in registry" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    run find_next_free_ip
    assert_success
    assert_output "10.50.0.11"
}

@test "fails when all IPs are exhausted" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    # Set a tiny range and fill it
    CLIENT_START="10"
    CLIENT_END="11"

    # Put both IPs in the wg0.conf
    cat >> "$WG_CONF" <<EOF

[Peer]
PublicKey = key1
AllowedIPs = 10.50.0.10/32

[Peer]
PublicKey = key2
AllowedIPs = 10.50.0.11/32
EOF

    run find_next_free_ip
    assert_failure
    assert_output --partial "No free VPN IPs"
}

# ---------------------------------------------------------------------------
# Key generation tests
# ---------------------------------------------------------------------------

@test "generates client keypair using wg mock" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    generate_client_keypair
    assert [ -n "$CLIENT_PRIVATE_KEY" ]
    assert [ -n "$CLIENT_PUBLIC_KEY" ]
}

@test "derives server public key from wg0.conf" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    run derive_server_public_key
    assert_success
}

# ---------------------------------------------------------------------------
# Registry tests
# ---------------------------------------------------------------------------

@test "creates registry with header on first client" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    CLIENT_PUBLIC_KEY="testkey123"
    write_registry_entry "newclient" "10.50.0.10"

    assert [ -f "$REGISTRY" ]

    run head -1 "$REGISTRY"
    assert_output --partial "name"
    assert_output --partial "ip"
    assert_output --partial "public_key"

    run tail -1 "$REGISTRY"
    assert_output --partial "newclient"
    assert_output --partial "10.50.0.10"
    assert_output --partial "testkey123"
    assert_output --partial "active"
}

@test "appends to existing registry" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    CLIENT_PUBLIC_KEY="newkey456"
    write_registry_entry "laptop" "10.50.0.11"

    run wc -l < "$REGISTRY"
    # header + phone + laptop = 3 lines
    assert_output --partial "3"
}

# ---------------------------------------------------------------------------
# Config generation tests
# ---------------------------------------------------------------------------

@test "creates client config from template" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    CLIENT_PRIVATE_KEY="dGVzdF9wcml2YXRlX2tleQ=="
    SERVER_PUBLIC_KEY="dGVzdF9zZXJ2ZXJfcHViX2tleQ=="

    run create_client_config "testclient" "10.50.0.10"
    assert_success

    local config_path="${CLIENT_DIR}/testclient.conf"
    assert [ -f "$config_path" ]

    run cat "$config_path"
    assert_output --partial "PrivateKey = dGVzdF9wcml2YXRlX2tleQ=="
    assert_output --partial "Address = 10.50.0.10/24"
    assert_output --partial "PublicKey = dGVzdF9zZXJ2ZXJfcHViX2tleQ=="
    assert_output --partial "Endpoint = 203.0.113.1:51820"
    assert_output --partial "AllowedIPs = 10.50.0.0/24"
    assert_output --partial "PersistentKeepalive = 25"
}

@test "client config includes DNS when configured" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    CLIENT_PRIVATE_KEY="dGVzdF9wcml2YXRlX2tleQ=="
    SERVER_PUBLIC_KEY="dGVzdF9zZXJ2ZXJfcHViX2tleQ=="
    CLIENT_DNS="1.1.1.1, 8.8.8.8"

    create_client_config "dnsclient" "10.50.0.20"

    run cat "${CLIENT_DIR}/dnsclient.conf"
    assert_output --partial "DNS = 1.1.1.1, 8.8.8.8"
}

@test "client config omits DNS line when empty" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    CLIENT_PRIVATE_KEY="dGVzdF9wcml2YXRlX2tleQ=="
    SERVER_PUBLIC_KEY="dGVzdF9zZXJ2ZXJfcHViX2tleQ=="
    CLIENT_DNS=""

    create_client_config "nodns" "10.50.0.30"

    run cat "${CLIENT_DIR}/nodns.conf"
    refute_output --partial "DNS ="
}

# ---------------------------------------------------------------------------
# Server config modification tests
# ---------------------------------------------------------------------------

@test "appends peer block to server config" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    CLIENT_PUBLIC_KEY="Y2xpZW50X3B1YmxpY19rZXk="

    append_peer_to_server "newpeer" "10.50.0.10"

    run cat "$WG_CONF"
    assert_output --partial "[Peer]"
    assert_output --partial "# newpeer"
    assert_output --partial "PublicKey = Y2xpZW50X3B1YmxpY19rZXk="
    assert_output --partial "AllowedIPs = 10.50.0.10/32"
}

@test "backup creates timestamped copy" {
    source "${BATS_TEST_DIRNAME}/../bin/wg-add-client" --source-only 2>/dev/null || true

    run backup_server_config
    assert_success

    # The output is the backup path
    assert [ -f "$output" ]

    # Backup should match original
    run diff "$WG_CONF" "$output"
    assert_success
}
