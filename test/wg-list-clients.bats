#!/usr/bin/env bats
#
# Tests for wg-list-clients
#

setup() {
    load 'test_helper/common-setup'
    _common_setup

    source "$CONFIG_FILE"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@test "shows message when no registry exists" {
    rm -f "$REGISTRY"

    source "${BATS_TEST_DIRNAME}/../bin/wg-list-clients" --source-only 2>/dev/null || true
    run main
    assert_output --partial "No clients registered"
}

@test "displays header row" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY1\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    source "${BATS_TEST_DIRNAME}/../bin/wg-list-clients" --source-only 2>/dev/null || true
    run main
    assert_success
    assert_output --partial "NAME"
    assert_output --partial "VPN IP"
    assert_output --partial "STATUS"
}

@test "lists single client correctly" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY1\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    source "${BATS_TEST_DIRNAME}/../bin/wg-list-clients" --source-only 2>/dev/null || true
    run main
    assert_success
    assert_output --partial "phone"
    assert_output --partial "10.50.0.10"
    assert_output --partial "active"
    assert_output --partial "1 total"
    assert_output --partial "1 active"
}

@test "lists multiple clients" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "phone\t10.50.0.10\tKEY1\tactive\t2024-01-01T00:00:00Z" >> "$REGISTRY"
    echo -e "laptop\t10.50.0.11\tKEY2\tactive\t2024-01-02T00:00:00Z" >> "$REGISTRY"
    echo -e "tablet\t10.50.0.12\tKEY3\tremoved\t2024-01-03T00:00:00Z" >> "$REGISTRY"

    source "${BATS_TEST_DIRNAME}/../bin/wg-list-clients" --source-only 2>/dev/null || true
    run main
    assert_success
    assert_output --partial "3 total"
    assert_output --partial "2 active"
    assert_output --partial "1 removed"
    assert_output --partial "phone"
    assert_output --partial "laptop"
    assert_output --partial "tablet"
}

@test "shows removed clients with correct status" {
    echo -e "name\tip\tpublic_key\tstatus\tcreated_at" > "$REGISTRY"
    echo -e "old-phone\t10.50.0.10\tKEY1\tremoved\t2024-01-01T00:00:00Z" >> "$REGISTRY"

    source "${BATS_TEST_DIRNAME}/../bin/wg-list-clients" --source-only 2>/dev/null || true
    run main
    assert_success
    assert_output --partial "old-phone"
    assert_output --partial "removed"
}
