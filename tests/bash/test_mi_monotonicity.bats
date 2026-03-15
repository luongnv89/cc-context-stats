#!/usr/bin/env bats

# Tests that MI always reflects context length: more free context = better MI.
# Verifies the bash (awk) implementation of compute_mi maintains monotonicity.
# MI = max(0, 1 - alpha * u^beta) with per-model profiles.

setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    # Source the compute_mi and get_mi_color functions from statusline-full.sh
    eval "$(sed -n '/^compute_mi()/,/^}/p' "$PROJECT_ROOT/scripts/statusline-full.sh")"
    eval "$(sed -n '/^get_mi_color()/,/^}/p' "$PROJECT_ROOT/scripts/statusline-full.sh")"
}

# Helper: extract MI value from compute_mi output (single field now)
get_mi() {
    echo "$1"
}

# Helper: compare two floats, return 0 if a <= b
float_le() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a <= b + 0.001) }'
}

# Helper: compare two floats, return 0 if a < b
float_lt() {
    awk -v a="$1" -v b="$2" 'BEGIN { exit !(a < b) }'
}

# --- MI monotonicity per model ---

@test "MI decreases with utilization (opus profile)" {
    local cw=200000
    local prev_mi=""

    for pct in 0 5 10 20 30 40 50 60 70 80 90 95 100; do
        local used=$((pct * cw / 100))
        local mi
        mi=$(compute_mi "$used" "$cw" "claude-opus-4-6" "")

        if [ -n "$prev_mi" ]; then
            float_le "$mi" "$prev_mi" || {
                echo "MI increased at ${pct}% (opus): $mi > $prev_mi"
                return 1
            }
        fi
        prev_mi="$mi"
    done
}

@test "MI decreases with utilization (sonnet profile)" {
    local cw=200000
    local prev_mi=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local mi
        mi=$(compute_mi "$used" "$cw" "claude-sonnet-4-6" "")

        if [ -n "$prev_mi" ]; then
            float_le "$mi" "$prev_mi" || {
                echo "MI increased at ${pct}% (sonnet): $mi > $prev_mi"
                return 1
            }
        fi
        prev_mi="$mi"
    done
}

@test "MI decreases with utilization (haiku profile)" {
    local cw=200000
    local prev_mi=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local mi
        mi=$(compute_mi "$used" "$cw" "claude-haiku-4-5" "")

        if [ -n "$prev_mi" ]; then
            float_le "$mi" "$prev_mi" || {
                echo "MI increased at ${pct}% (haiku): $mi > $prev_mi"
                return 1
            }
        fi
        prev_mi="$mi"
    done
}

@test "MI decreases with utilization (unknown/default profile)" {
    local cw=200000
    local prev_mi=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local mi
        mi=$(compute_mi "$used" "$cw" "unknown-model" "")

        if [ -n "$prev_mi" ]; then
            float_le "$mi" "$prev_mi" || {
                echo "MI increased at ${pct}% (default): $mi > $prev_mi"
                return 1
            }
        fi
        prev_mi="$mi"
    done
}

# --- Beta override monotonicity ---

@test "MI monotonic with beta_override=1.0" {
    local cw=200000
    local prev_mi=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local mi
        mi=$(compute_mi "$used" "$cw" "claude-opus-4-6" 1.0)

        if [ -n "$prev_mi" ]; then
            float_le "$mi" "$prev_mi" || {
                echo "MI not monotonic at ${pct}% with beta=1.0: $mi > $prev_mi"
                return 1
            }
        fi
        prev_mi="$mi"
    done
}

@test "MI monotonic with beta_override=2.0" {
    local cw=200000
    local prev_mi=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local mi
        mi=$(compute_mi "$used" "$cw" "claude-opus-4-6" 2.0)

        if [ -n "$prev_mi" ]; then
            float_le "$mi" "$prev_mi" || {
                echo "MI not monotonic at ${pct}% with beta=2.0: $mi > $prev_mi"
                return 1
            }
        fi
        prev_mi="$mi"
    done
}

@test "MI monotonic with beta_override=3.0" {
    local cw=200000
    local prev_mi=""

    for pct in 0 10 20 30 40 50 60 70 80 90 100; do
        local used=$((pct * cw / 100))
        local mi
        mi=$(compute_mi "$used" "$cw" "claude-opus-4-6" 3.0)

        if [ -n "$prev_mi" ]; then
            float_le "$mi" "$prev_mi" || {
                echo "MI not monotonic at ${pct}% with beta=3.0: $mi > $prev_mi"
                return 1
            }
        fi
        prev_mi="$mi"
    done
}

# --- MI reflects context zones ---

@test "smart zone MI > dumb zone MI > wrap up zone MI" {
    local cw=200000

    local smart_mi dumb_mi wrap_mi
    smart_mi=$(compute_mi $((cw * 20 / 100)) "$cw" "claude-sonnet-4-6" "")
    dumb_mi=$(compute_mi $((cw * 60 / 100)) "$cw" "claude-sonnet-4-6" "")
    wrap_mi=$(compute_mi $((cw * 90 / 100)) "$cw" "claude-sonnet-4-6" "")

    float_lt "$dumb_mi" "$smart_mi" || {
        echo "Smart zone MI ($smart_mi) should be > dumb zone MI ($dumb_mi)"
        return 1
    }
    float_lt "$wrap_mi" "$dumb_mi" || {
        echo "Dumb zone MI ($dumb_mi) should be > wrap up zone MI ($wrap_mi)"
        return 1
    }
}

@test "empty context has MI=1.000" {
    local mi
    mi=$(compute_mi 0 200000 "claude-opus-4-6" "")
    [ "$mi" = "1.000" ]
}

@test "all models reach MI=0.000 at full context" {
    for model in "claude-opus-4-6" "claude-sonnet-4-6" "claude-haiku-4-5"; do
        local mi
        mi=$(compute_mi 200000 200000 "$model" "")
        [ "$mi" = "0.000" ] || {
            echo "$model at full context should be 0.000 but got $mi"
            return 1
        }
    done
}

@test "opus degrades less than sonnet at 70% utilization" {
    local cw=200000
    local used=$((cw * 70 / 100))
    local opus_mi sonnet_mi
    opus_mi=$(compute_mi "$used" "$cw" "claude-opus-4-6" "")
    sonnet_mi=$(compute_mi "$used" "$cw" "claude-sonnet-4-6" "")
    float_lt "$sonnet_mi" "$opus_mi" || {
        echo "Opus MI ($opus_mi) should be > sonnet MI ($sonnet_mi) at 70%"
        return 1
    }
}

# --- Guard clause ---

@test "context_window=0 returns MI=1.000" {
    local mi
    mi=$(compute_mi 50000 0 "claude-opus-4-6" "")
    [ "$mi" = "1.000" ]
}

# --- Color thresholds (MI + utilization) ---

@test "MI color: green for MI >= 0.90 and low utilization" {
    local color
    color=$(get_mi_color "0.95" "0.10")
    [ "$color" = "green" ]
}

@test "MI color: yellow for MI < 0.90" {
    local color
    color=$(get_mi_color "0.85" "0.10")
    [ "$color" = "yellow" ]
}

@test "MI color: yellow when context 40-80%" {
    local color
    color=$(get_mi_color "0.95" "0.50")
    [ "$color" = "yellow" ]
}

@test "MI color: red for MI <= 0.80" {
    local color
    color=$(get_mi_color "0.75" "0.10")
    [ "$color" = "red" ]
}

@test "MI color: red when context >= 80%" {
    local color
    color=$(get_mi_color "0.95" "0.85")
    [ "$color" = "red" ]
}
