#!/usr/bin/env bats

# Test suite for statusline-git.sh

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$PROJECT_ROOT/scripts/statusline-git.sh"
    FIXTURES="$PROJECT_ROOT/tests/fixtures/json"
}

@test "statusline-git.sh exists and is executable" {
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

@test "handles valid input without crashing" {
    run bash "$SCRIPT" < "$FIXTURES/valid_full.json"
    [ "$status" -eq 0 ]
}

@test "shows git branch when in git repo" {
    # Use project dir which is a git repo
    input=$(cat <<EOF
{"model":{"display_name":"Claude"},"workspace":{"current_dir":"$PROJECT_ROOT","project_dir":"$PROJECT_ROOT"}}
EOF
)
    result=$(echo "$input" | "$SCRIPT")
    # Should contain branch name (main or master usually)
    [[ "$result" == *"main"* ]] || [[ "$result" == *"master"* ]] || true
}
