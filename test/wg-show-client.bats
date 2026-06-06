#!/usr/bin/env bats
#
# Tests for wg-show-client
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
    source "${BATS_TEST_DIRNAME}/../bin/wg-show-client" --source-only 2>/dev/null || true

    run main ""
    assert_failure
    assert_output --partial "Usage"
}

@test "fails when client not found in registry" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"

    source "${BATS_TEST_DIRNAME}/../bin/wg-show-client" --source-only 2>/dev/null || true
    run main "nonexistent"
    assert_failure
    assert_output --partial "not found"
}

@test "displays client details from registry" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tbW9ja19wdWJsaWNfa2V5X2Jhc2U2NF9lbmNvZGVkXw==\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"
    touch "${CLIENT_DIR}/phone.conf"

    # Pipe 'n' to skip QR code prompt
    run bash -c "echo 'n' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-show-client' phone
    )"
    assert_success
    assert_output --partial "phone"
    assert_output --partial "10.50.0.10"
    assert_output --partial "active"
    assert_output --partial "2024-01-01"
}

@test "shows config file path when it exists" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "laptop\t10.50.0.11\tKEY2\tactive\t2024-02-01T00:00:00Z" >> "$REGISTRY"
    touch "${CLIENT_DIR}/laptop.conf"

    run bash -c "echo 'n' | (
        export WG_HUB_CLI_CONFIG='${CONFIG_FILE}'
        export WG_HUB_CLI_TESTING=1
        export PATH=\"${TEST_BIN_DIR}:\$PATH\"
        '${BATS_TEST_DIRNAME}/../bin/wg-show-client' laptop
    )"
    assert_success
    assert_output --partial "laptop.conf"
}

@test "indicates config file not found for removed client" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "old\t10.50.0.12\tKEY3\tremoved\t2024-03-01T00:00:00Z" >> "$REGISTRY"

    source "${BATS_TEST_DIRNAME}/../bin/wg-show-client" --source-only 2>/dev/null || true
    run main "old"
    assert_success
    assert_output --partial "(not found)"
}
