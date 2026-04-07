#!/usr/bin/env bats

# Test suite for scripts/check-install.sh

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$PROJECT_ROOT/scripts/check-install.sh"
}

@test "check-install.sh exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

@test "check-install.sh has correct shebang" {
    head -1 "$SCRIPT" | grep -q "#!/bin/bash"
}

@test "check-install.sh contains statusline check section" {
    grep -q "Statusline Command" "$SCRIPT"
    grep -q "claude-statusline" "$SCRIPT"
    grep -q "statusline.py" "$SCRIPT"
}

@test "check-install.sh contains context-stats check section" {
    grep -q "Context-Stats CLI" "$SCRIPT"
    grep -q "context-stats" "$SCRIPT"
}

@test "check-install.sh contains settings.json check section" {
    grep -q "Claude Code Settings" "$SCRIPT"
    grep -q "settings.json" "$SCRIPT"
    grep -q "statusLine" "$SCRIPT"
}

@test "check-install.sh detects install methods" {
    grep -q 'methods+=("shell")' "$SCRIPT"
    grep -q 'methods+=("pip")' "$SCRIPT"
}

@test "check-install.sh tests statusline command with JSON input" {
    grep -q "test_statusline_command" "$SCRIPT"
    grep -q "test_json" "$SCRIPT"
}

@test "check-install.sh provides fix guidance on failure" {
    grep -q "curl -fsSL" "$SCRIPT"
    grep -q "pip show" "$SCRIPT"
}

@test "check-install.sh exits with failure count" {
    grep -q 'exit $FAIL' "$SCRIPT"
}
