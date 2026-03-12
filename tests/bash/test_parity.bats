#!/usr/bin/env bats

# Cross-implementation parity tests: Python vs Node.js statusline scripts
# Ensures both implementations produce equivalent output for identical input.

strip_ansi() {
    printf '%s' "$1" | sed -e $'s/\033\[[0-9;]*m//g' -e 's/\\033\[[0-9;]*m//g'
}

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    PYTHON_SCRIPT="$PROJECT_ROOT/scripts/statusline.py"
    NODE_SCRIPT="$PROJECT_ROOT/scripts/statusline.js"
    FIXTURES="$PROJECT_ROOT/tests/fixtures/json"

    # Create isolated temp HOME so state files don't pollute real ~/.claude/
    TEST_HOME=$(mktemp -d)
    export HOME="$TEST_HOME"

    # Normalize terminal width for deterministic output
    export COLUMNS=120

    # Disable delta display to avoid cross-fixture state file interference
    mkdir -p "$TEST_HOME/.claude"
    echo "show_delta=false" > "$TEST_HOME/.claude/statusline.conf"

    # Create a non-git temp working directory so both scripts skip git info
    TEST_WORKDIR=$(mktemp -d)
    cd "$TEST_WORKDIR"
}

teardown() {
    rm -rf "$TEST_HOME"
    rm -rf "$TEST_WORKDIR"
}

# Helper: inject a session_id into a JSON fixture via Python
inject_session_py() {
    local fixture="$1" session="$2"
    python3 -c "
import json, sys
data = json.load(open('$fixture'))
data['session_id'] = '$session'
json.dump(data, sys.stdout)
"
}

# Helper: inject a session_id into a JSON fixture via Node
inject_session_node() {
    local fixture="$1" session="$2"
    node -e "
const fs = require('fs');
const data = JSON.parse(fs.readFileSync('$fixture', 'utf8'));
data.session_id = '$session';
process.stdout.write(JSON.stringify(data));
"
}

# ============================================
# Stdout Parity Tests
# ============================================

@test "stdout parity: Python and Node.js produce identical ANSI-stripped output for all fixtures" {
    for fixture in "$FIXTURES"/*.json; do
        fixture_name=$(basename "$fixture")

        py_output=$(cat "$fixture" | python3 "$PYTHON_SCRIPT" 2>/dev/null)
        node_output=$(cat "$fixture" | node "$NODE_SCRIPT" 2>/dev/null)

        py_clean=$(strip_ansi "$py_output")
        node_clean=$(strip_ansi "$node_output")

        if [ "$py_clean" != "$node_clean" ]; then
            echo "STDOUT MISMATCH for fixture: $fixture_name"
            echo "---"
            echo "Python output:  $py_clean"
            echo "Node.js output: $node_clean"
            echo "---"
            return 1
        fi
    done
}

# ============================================
# CSV State File Parity Tests
# ============================================

@test "CSV parity: both scripts write exactly 14 fields for all fixtures" {
    for fixture in "$FIXTURES"/*.json; do
        fixture_name=$(basename "$fixture" .json)

        py_session="parity-py-${fixture_name}"
        node_session="parity-node-${fixture_name}"

        py_input=$(inject_session_py "$fixture" "$py_session")
        node_input=$(inject_session_node "$fixture" "$node_session")

        echo "$py_input" | python3 "$PYTHON_SCRIPT" > /dev/null 2>&1
        echo "$node_input" | node "$NODE_SCRIPT" > /dev/null 2>&1

        py_state_file="$TEST_HOME/.claude/statusline/statusline.${py_session}.state"
        node_state_file="$TEST_HOME/.claude/statusline/statusline.${node_session}.state"

        # Skip fixtures that don't produce state files (e.g., no context_window data)
        if [ ! -f "$py_state_file" ] && [ ! -f "$node_state_file" ]; then
            continue
        fi

        # If only one script wrote a state file, that's a parity failure
        if [ ! -f "$py_state_file" ]; then
            echo "PARITY ERROR for fixture: $fixture_name"
            echo "Node.js wrote a state file but Python did not"
            return 1
        fi
        if [ ! -f "$node_state_file" ]; then
            echo "PARITY ERROR for fixture: $fixture_name"
            echo "Python wrote a state file but Node.js did not"
            return 1
        fi

        # Read last line of each state file
        py_line=$(tail -1 "$py_state_file")
        node_line=$(tail -1 "$node_state_file")

        # Count fields (comma-separated)
        py_field_count=$(echo "$py_line" | awk -F',' '{print NF}')
        node_field_count=$(echo "$node_line" | awk -F',' '{print NF}')

        if [ "$py_field_count" -ne 14 ]; then
            echo "FIELD COUNT ERROR for fixture: $fixture_name"
            echo "Python state has $py_field_count fields (expected 14)"
            echo "Python line: $py_line"
            return 1
        fi
        if [ "$node_field_count" -ne 14 ]; then
            echo "FIELD COUNT ERROR for fixture: $fixture_name"
            echo "Node.js state has $node_field_count fields (expected 14)"
            echo "Node.js line: $node_line"
            return 1
        fi
    done
}

@test "CSV parity: fields 1-13 match between Python and Node.js for all fixtures" {
    # Field names for diagnostic output (index 0 = timestamp, 1-13 = data fields)
    local field_names=(
        "timestamp"
        "total_input_tokens"
        "total_output_tokens"
        "current_usage_input_tokens"
        "current_usage_output_tokens"
        "current_usage_cache_creation"
        "current_usage_cache_read"
        "total_cost_usd"
        "total_lines_added"
        "total_lines_removed"
        "session_id"
        "model_id"
        "workspace_project_dir"
        "context_window_size"
    )

    for fixture in "$FIXTURES"/*.json; do
        fixture_name=$(basename "$fixture" .json)

        py_session="parity-fields-py-${fixture_name}"
        node_session="parity-fields-node-${fixture_name}"

        py_input=$(inject_session_py "$fixture" "$py_session")
        node_input=$(inject_session_node "$fixture" "$node_session")

        echo "$py_input" | python3 "$PYTHON_SCRIPT" > /dev/null 2>&1
        echo "$node_input" | node "$NODE_SCRIPT" > /dev/null 2>&1

        py_state_file="$TEST_HOME/.claude/statusline/statusline.${py_session}.state"
        node_state_file="$TEST_HOME/.claude/statusline/statusline.${node_session}.state"

        # Skip fixtures that don't produce state files
        if [ ! -f "$py_state_file" ] && [ ! -f "$node_state_file" ]; then
            continue
        fi

        [ -f "$py_state_file" ] || { echo "Python wrote no state file but Node did for $fixture_name"; return 1; }
        [ -f "$node_state_file" ] || { echo "Node wrote no state file but Python did for $fixture_name"; return 1; }

        py_line=$(tail -1 "$py_state_file")
        node_line=$(tail -1 "$node_state_file")

        # Compare fields 1-13 (skip timestamp at index 0, and skip session_id at index 10 since we set different ones)
        local has_mismatch=0
        for i in $(seq 1 13); do
            # Skip field 10 (session_id) since we intentionally set different session IDs
            if [ "$i" -eq 10 ]; then
                continue
            fi

            py_field=$(echo "$py_line" | cut -d',' -f$((i + 1)))
            node_field=$(echo "$node_line" | cut -d',' -f$((i + 1)))

            if [ "$py_field" != "$node_field" ]; then
                echo "FIELD MISMATCH for fixture: $fixture_name"
                echo "  Field $i (${field_names[$i]}): Python='$py_field' Node='$node_field'"
                has_mismatch=1
            fi
        done

        if [ "$has_mismatch" -eq 1 ]; then
            echo "Full Python line:  $py_line"
            echo "Full Node.js line: $node_line"
            return 1
        fi
    done
}

@test "CSV parity: timestamp differs by at most 2 seconds between Python and Node.js" {
    for fixture in "$FIXTURES"/*.json; do
        fixture_name=$(basename "$fixture" .json)

        py_session="parity-ts-py-${fixture_name}"
        node_session="parity-ts-node-${fixture_name}"

        py_input=$(inject_session_py "$fixture" "$py_session")
        node_input=$(inject_session_node "$fixture" "$node_session")

        echo "$py_input" | python3 "$PYTHON_SCRIPT" > /dev/null 2>&1
        echo "$node_input" | node "$NODE_SCRIPT" > /dev/null 2>&1

        py_state_file="$TEST_HOME/.claude/statusline/statusline.${py_session}.state"
        node_state_file="$TEST_HOME/.claude/statusline/statusline.${node_session}.state"

        # Skip fixtures that don't produce state files
        if [ ! -f "$py_state_file" ] && [ ! -f "$node_state_file" ]; then
            continue
        fi

        [ -f "$py_state_file" ] || { echo "Python wrote no state file but Node did for $fixture_name"; return 1; }
        [ -f "$node_state_file" ] || { echo "Node wrote no state file but Python did for $fixture_name"; return 1; }

        py_line=$(tail -1 "$py_state_file")
        node_line=$(tail -1 "$node_state_file")

        # Extract timestamp (field 0, which is field 1 in cut 1-indexed)
        py_ts=$(echo "$py_line" | cut -d',' -f1)
        node_ts=$(echo "$node_line" | cut -d',' -f1)

        # Calculate absolute difference
        if [ -n "$py_ts" ] && [ -n "$node_ts" ]; then
            diff=$((py_ts - node_ts))
            abs_diff=${diff#-}

            if [ "$abs_diff" -gt 2 ]; then
                echo "TIMESTAMP DRIFT for fixture: $fixture_name"
                echo "  Python timestamp:  $py_ts"
                echo "  Node.js timestamp: $node_ts"
                echo "  Difference: ${abs_diff}s (max allowed: 2s)"
                return 1
            fi
        fi
    done
}
