#!/usr/bin/env bats

# Test suite for statusline-minimal.sh

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$PROJECT_ROOT/scripts/statusline-minimal.sh"
    FIXTURES="$PROJECT_ROOT/tests/fixtures/json"
}

@test "statusline-minimal.sh exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

@test "outputs model name from JSON input" {
    input='{"model":{"display_name":"Opus 4.5"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"}}'
    result=$(echo "$input" | "$SCRIPT")
    [[ "$result" == *"Opus 4.5"* ]]
}

@test "outputs directory name" {
    input='{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/home/user/myproject","project_dir":"/tmp"}}'
    result=$(echo "$input" | "$SCRIPT")
    [[ "$result" == *"myproject"* ]]
}

@test "handles minimal valid input" {
    result=$(cat "$FIXTURES/valid_minimal.json" | "$SCRIPT")
    [[ "$result" == *"Claude"* ]]
    [[ "$result" == *"test"* ]]
}

@test "script runs without errors on valid input" {
    run bash "$SCRIPT" < "$FIXTURES/valid_full.json"
    [ "$status" -eq 0 ]
}
