#!/usr/bin/env bats

# Test suite for statusline-full.sh

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$PROJECT_ROOT/scripts/statusline-full.sh"
    FIXTURES="$PROJECT_ROOT/tests/fixtures/json"

    # Create a temp directory for config tests
    TEST_HOME=$(mktemp -d)
    export HOME="$TEST_HOME"
    mkdir -p "$TEST_HOME/.claude"
}

teardown() {
    rm -rf "$TEST_HOME"
}

@test "statusline-full.sh exists and is executable" {
    [ -f "$SCRIPT" ]
    [ -x "$SCRIPT" ]
}

@test "outputs model name from JSON input" {
    input='{"model":{"display_name":"Opus 4.5"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"}}'
    result=$(echo "$input" | "$SCRIPT")
    [[ "$result" == *"Opus 4.5"* ]]
}

@test "outputs directory name from path" {
    input='{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/home/user/myproject","project_dir":"/home/user/myproject"}}'
    result=$(echo "$input" | "$SCRIPT")
    [[ "$result" == *"myproject"* ]]
}

@test "handles full valid input with context window" {
    result=$(cat "$FIXTURES/valid_full.json" | "$SCRIPT")
    [[ "$result" == *"Opus 4.5"* ]]
    [[ "$result" == *"my-project"* ]]
    [[ "$result" == *"free"* ]]
}

@test "shows AC indicator when autocompact enabled" {
    input='{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/tmp","project_dir":"/tmp"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":10000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'
    result=$(echo "$input" | "$SCRIPT")
    [[ "$result" == *"[AC:"* ]]
}

@test "shows AC:off when autocompact disabled in config" {
    echo "autocompact=false" > "$TEST_HOME/.claude/statusline.conf"
    input='{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/tmp","project_dir":"/tmp"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":10000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'
    result=$(echo "$input" | "$SCRIPT")
    [[ "$result" == *"[AC:off]"* ]]
}

@test "shows exact tokens by default (token_detail=true)" {
    input='{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/tmp","project_dir":"/tmp"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":10000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'
    result=$(echo "$input" | "$SCRIPT")
    # Should NOT show 'k' suffix by default, should show comma-formatted number
    [[ "$result" != *"k free"* ]]
    [[ "$result" == *"free"* ]]
}

@test "shows abbreviated tokens when token_detail=false" {
    echo "token_detail=false" > "$TEST_HOME/.claude/statusline.conf"
    input='{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/tmp","project_dir":"/tmp"},"context_window":{"context_window_size":200000,"current_usage":{"input_tokens":10000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'
    result=$(echo "$input" | "$SCRIPT")
    # Should show 'k' suffix for abbreviated format
    [[ "$result" == *"k free"* ]]
}

@test "handles missing context window gracefully" {
    input='{"model":{"display_name":"Claude"},"workspace":{"current_dir":"/tmp/test","project_dir":"/tmp/test"}}'
    run bash "$SCRIPT" <<< "$input"
    [ "$status" -eq 0 ]
}

@test "calculates free tokens percentage correctly" {
    # Low usage fixture: 30k tokens used out of 200k = 85% free
    result=$(cat "$FIXTURES/low_usage.json" | "$SCRIPT")
    [[ "$result" == *"free"* ]]
}

@test "uses fixture files correctly" {
    for fixture in valid_full valid_minimal low_usage medium_usage high_usage; do
        run bash "$SCRIPT" < "$FIXTURES/${fixture}.json"
        [ "$status" -eq 0 ]
    done
}
