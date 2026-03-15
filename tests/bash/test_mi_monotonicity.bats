#!/usr/bin/env bats

# Tests that MI always reflects context length: more free context = better MI.
# Verifies the bash (awk) implementation of compute_mi maintains monotonicity.

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # Source the compute_mi function from statusline-full.sh
    # We extract it with a helper since the script runs main() on source
    eval "$(sed -n '/^compute_mi()/,/^}/p' "$PROJECT_ROOT/scripts/statusline-full.sh")"
}

# Helper: extract MI value (first field) from compute_mi output "MI CPS ES PS"
get_mi() {
    echo "$1" | awk '{print $1}'
}

# Helper: extract CPS value (second field) from compute_mi output
get_cps() {
    echo "$1" | awk '{print $2}'
}

# Helper: compare two floats, return 0 if a <= b
float_le() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a <= b + 0.001) }'
}

# Helper: compare two floats, return 0 if a < b
float_lt() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a < b) }'
}

# --- CPS monotonicity ---

@test "CPS decreases as utilization increases (bash/awk)" {
    local cw=200000
    local beta=1.5
    local prev_cps=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local result
        result=$(compute_mi "$used" "$cw" 0 "$used" 0 "" "$beta")
        local cps
        cps=$(get_cps "$result")

        if [ -n "$prev_cps" ]; then
            float_le "$cps" "$prev_cps" || {
                echo "CPS increased at ${pct}%: $cps > $prev_cps"
                return 1
            }
        fi
        prev_cps="$cps"
    done
}

@test "CPS boundary: 0% utilization gives CPS=1.0" {
    local result
    result=$(compute_mi 0 200000 0 0 0 "" 1.5)
    local cps
    cps=$(get_cps "$result")
    [ "$cps" = "1.000" ]
}

@test "CPS boundary: 100% utilization gives CPS=0.0" {
    local result
    result=$(compute_mi 200000 200000 0 200000 0 100 1.5)
    local cps
    cps=$(get_cps "$result")
    [ "$cps" = "0.000" ]
}

# --- CPS monotonicity with different beta values ---

@test "CPS monotonic with beta=1.0" {
    local cw=200000
    local prev_cps=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local result
        result=$(compute_mi "$used" "$cw" 0 "$used" 0 "" 1.0)
        local cps
        cps=$(get_cps "$result")

        if [ -n "$prev_cps" ]; then
            float_le "$cps" "$prev_cps" || {
                echo "CPS not monotonic at ${pct}% with beta=1.0: $cps > $prev_cps"
                return 1
            }
        fi
        prev_cps="$cps"
    done
}

@test "CPS monotonic with beta=2.0" {
    local cw=200000
    local prev_cps=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local result
        result=$(compute_mi "$used" "$cw" 0 "$used" 0 "" 2.0)
        local cps
        cps=$(get_cps "$result")

        if [ -n "$prev_cps" ]; then
            float_le "$cps" "$prev_cps" || {
                echo "CPS not monotonic at ${pct}% with beta=2.0: $cps > $prev_cps"
                return 1
            }
        fi
        prev_cps="$cps"
    done
}

@test "CPS monotonic with beta=3.0" {
    local cw=200000
    local prev_cps=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local result
        result=$(compute_mi "$used" "$cw" 0 "$used" 0 "" 3.0)
        local cps
        cps=$(get_cps "$result")

        if [ -n "$prev_cps" ]; then
            float_le "$cps" "$prev_cps" || {
                echo "CPS not monotonic at ${pct}% with beta=3.0: $cps > $prev_cps"
                return 1
            }
        fi
        prev_cps="$cps"
    done
}

# --- Composite MI monotonicity ---

@test "MI decreases with utilization (no cache, no prev)" {
    local cw=200000
    local prev_mi=""

    for pct in 0 5 10 20 30 40 50 60 70 80 90 95 100; do
        local used=$((pct * cw / 100))
        local result
        result=$(compute_mi "$used" "$cw" 0 "$used" 0 "" 1.5)
        local mi
        mi=$(get_mi "$result")

        if [ -n "$prev_mi" ]; then
            float_le "$mi" "$prev_mi" || {
                echo "MI increased at ${pct}%: $mi > $prev_mi"
                return 1
            }
        fi
        prev_mi="$mi"
    done
}

@test "MI decreases with utilization (high cache)" {
    local cw=200000
    local prev_mi=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local cache_read=$((used * 8 / 10))
        local result
        result=$(compute_mi "$used" "$cw" "$cache_read" "$used" 0 "" 1.5)
        local mi
        mi=$(get_mi "$result")

        if [ -n "$prev_mi" ]; then
            float_le "$mi" "$prev_mi" || {
                echo "MI increased at ${pct}% (high cache): $mi > $prev_mi"
                return 1
            }
        fi
        prev_mi="$mi"
    done
}

@test "MI decreases with utilization (with productivity)" {
    local cw=200000
    local prev_mi=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local result
        result=$(compute_mi "$used" "$cw" 0 "$used" 120 1000 1.5)
        local mi
        mi=$(get_mi "$result")

        if [ -n "$prev_mi" ]; then
            float_le "$mi" "$prev_mi" || {
                echo "MI increased at ${pct}% (with productivity): $mi > $prev_mi"
                return 1
            }
        fi
        prev_mi="$mi"
    done
}

# --- MI reflects context zones ---

@test "smart zone MI > dumb zone MI > wrap up zone MI" {
    local cw=200000

    local smart_result dumb_result wrap_result
    smart_result=$(compute_mi $((cw * 20 / 100)) "$cw" 0 $((cw * 20 / 100)) 0 "" 1.5)
    dumb_result=$(compute_mi $((cw * 60 / 100)) "$cw" 0 $((cw * 60 / 100)) 0 "" 1.5)
    wrap_result=$(compute_mi $((cw * 90 / 100)) "$cw" 0 $((cw * 90 / 100)) 0 "" 1.5)

    local smart_mi dumb_mi wrap_mi
    smart_mi=$(get_mi "$smart_result")
    dumb_mi=$(get_mi "$dumb_result")
    wrap_mi=$(get_mi "$wrap_result")

    float_lt "$dumb_mi" "$smart_mi" || {
        echo "Smart zone MI ($smart_mi) should be > dumb zone MI ($dumb_mi)"
        return 1
    }
    float_lt "$wrap_mi" "$dumb_mi" || {
        echo "Dumb zone MI ($dumb_mi) should be > wrap up zone MI ($wrap_mi)"
        return 1
    }
}

@test "empty context has highest MI, full context has lowest" {
    local cw=200000

    local empty_result full_result
    empty_result=$(compute_mi 0 "$cw" 0 0 0 "" 1.5)
    full_result=$(compute_mi "$cw" "$cw" 0 "$cw" 0 100 1.5)

    local empty_mi full_mi
    empty_mi=$(get_mi "$empty_result")
    full_mi=$(get_mi "$full_result")

    float_lt "$full_mi" "$empty_mi" || {
        echo "Empty context MI ($empty_mi) should be > full context MI ($full_mi)"
        return 1
    }
}

# --- Guard clause ---

@test "context_window=0 returns MI=1.0" {
    local result
    result=$(compute_mi 50000 0 30000 50000 0 "" 1.5)
    local mi
    mi=$(get_mi "$result")
    [ "$mi" = "1.00" ]
}
