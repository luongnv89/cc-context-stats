#!/usr/bin/env bats

# Test suite for install.sh

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$PROJECT_ROOT/install.sh"
}

@test "install.sh exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

@test "install.sh contains expected functions" {
    grep -q "check_jq" "$SCRIPT"
    grep -q "select_script" "$SCRIPT"
    grep -q "ensure_claude_dir" "$SCRIPT"
    grep -q "install_script" "$SCRIPT"
    grep -q "update_settings" "$SCRIPT"
}

@test "install.sh has correct shebang" {
    head -1 "$SCRIPT" | grep -q "#!/bin/bash"
}

@test "install.sh uses set -e for error handling" {
    grep -q "set -e" "$SCRIPT"
}
