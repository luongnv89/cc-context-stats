#!/bin/bash
# Token Usage Graph Visualizer for Claude Code
# Displays ASCII graphs of token consumption over time
#
# Usage:
#   token-graph.sh [session_id] [options]
#
# Options:
#   --type <cumulative|delta|both>  Graph type to display (default: both)
#   --no-color                      Disable color output
#   --help                          Show this help
#
# Examples:
#   token-graph.sh                        # Latest session, both graphs
#   token-graph.sh abc123                 # Specific session
#   token-graph.sh --type delta           # Only delta graph

# Note: This script is compatible with bash 3.2+ (macOS default)

# === CONFIGURATION ===
VERSION="1.0.0"
STATE_DIR=~/.claude
CONFIG_FILE=~/.claude/statusline.conf

# === COLOR DEFINITIONS ===
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# === GLOBAL VARIABLES ===
# Use simple arrays for bash 3.2 compatibility
TIMESTAMPS=""
TOKENS=""
DELTAS=""
DATA_COUNT=0
TERM_WIDTH=80
TERM_HEIGHT=24
GRAPH_WIDTH=60
GRAPH_HEIGHT=15
SESSION_ID=""
GRAPH_TYPE="both"
COLOR_ENABLED=true
TOKEN_DETAIL_ENABLED=true

# === UTILITY FUNCTIONS ===

show_help() {
    cat << 'EOF'
Token Usage Graph Visualizer for Claude Code

USAGE:
    token-graph.sh [session_id] [options]

ARGUMENTS:
    session_id    Optional session ID. If not provided, uses the latest session.

OPTIONS:
    --type <type>  Graph type to display:
                   - cumulative: Total tokens over time
                   - delta: Token consumption per interval
                   - both: Show both graphs (default)
    --no-color     Disable color output
    --help         Show this help message

EXAMPLES:
    # Show graphs for latest session
    token-graph.sh

    # Show graphs for specific session
    token-graph.sh abc123def

    # Show only cumulative graph
    token-graph.sh --type cumulative

    # Disable colors for piping to file
    token-graph.sh --no-color > output.txt

DATA SOURCE:
    Reads token history from ~/.claude/statusline.<session_id>.state
    Each line contains: timestamp,tokens

EOF
}

error_exit() {
    echo -e "${RED}Error:${RESET} $1" >&2
    exit "${2:-1}"
}

warn() {
    echo -e "${YELLOW}Warning:${RESET} $1" >&2
}

info() {
    echo -e "${DIM}$1${RESET}"
}

init_colors() {
    if [ "$COLOR_ENABLED" != "true" ] || [ "${NO_COLOR:-}" = "1" ] || [ ! -t 1 ]; then
        BLUE=''
        MAGENTA=''
        CYAN=''
        GREEN=''
        YELLOW=''
        RED=''
        BOLD=''
        DIM=''
        RESET=''
    fi
}

get_terminal_dimensions() {
    # Try tput first
    if command -v tput >/dev/null 2>&1; then
        TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
        TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
    else
        # Fallback to stty
        local dims
        dims=$(stty size 2>/dev/null || echo "24 80")
        TERM_HEIGHT=$(echo "$dims" | cut -d' ' -f1)
        TERM_WIDTH=$(echo "$dims" | cut -d' ' -f2)
    fi

    # Calculate graph dimensions
    GRAPH_WIDTH=$((TERM_WIDTH - 15))  # Reserve space for Y-axis labels
    GRAPH_HEIGHT=$((TERM_HEIGHT / 3))  # Each graph takes 1/3 of terminal

    # Enforce minimums and maximums
    [ $GRAPH_WIDTH -lt 30 ] && GRAPH_WIDTH=30
    [ $GRAPH_HEIGHT -lt 8 ] && GRAPH_HEIGHT=8
    [ $GRAPH_HEIGHT -gt 20 ] && GRAPH_HEIGHT=20
}

format_number() {
    local num=$1
    if [ "$TOKEN_DETAIL_ENABLED" = "true" ]; then
        # Comma-separated format
        echo "$num" | awk '{ printf "%\047d", $1 }' 2>/dev/null || echo "$num"
    else
        # Abbreviated format
        echo "$num" | awk '{
            if ($1 >= 1000000) printf "%.1fM", $1/1000000
            else if ($1 >= 1000) printf "%.1fk", $1/1000
            else printf "%d", $1
        }'
    fi
}

format_timestamp() {
    local ts=$1
    # Try BSD date first (macOS), then GNU date
    date -r "$ts" +%H:%M 2>/dev/null || date -d "@$ts" +%H:%M 2>/dev/null || echo "$ts"
}

format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))

    if [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m"
    else
        echo "${seconds}s"
    fi
}

# === DATA FUNCTIONS ===

find_latest_state_file() {
    local pattern="$STATE_DIR/statusline"

    if [ -n "$SESSION_ID" ]; then
        # Specific session requested
        local file="$STATE_DIR/statusline.${SESSION_ID}.state"
        if [ -f "$file" ]; then
            echo "$file"
            return 0
        else
            error_exit "State file not found: $file"
        fi
    fi

    # Find most recent state file
    local latest
    latest=$(ls -t "$STATE_DIR"/statusline.*.state 2>/dev/null | head -1)

    if [ -z "$latest" ]; then
        # Try the default state file
        if [ -f "$STATE_DIR/statusline.state" ]; then
            echo "$STATE_DIR/statusline.state"
            return 0
        fi
        error_exit "No state files found in $STATE_DIR/\nRun Claude Code to generate token usage data."
    fi

    echo "$latest"
}

validate_state_file() {
    local file=$1

    if [ ! -f "$file" ]; then
        error_exit "State file not found: $file"
    fi

    if [ ! -r "$file" ]; then
        error_exit "Cannot read state file: $file"
    fi

    local line_count
    line_count=$(wc -l < "$file" | tr -d ' ')

    if [ "$line_count" -lt 2 ]; then
        error_exit "Need at least 2 data points to generate graphs.\nFound: $line_count entry. Use Claude Code to accumulate more data."
    fi
}

load_token_history() {
    local file=$1
    local line_num=0
    local valid_lines=0
    local skipped_lines=0

    TIMESTAMPS=""
    TOKENS=""
    DATA_COUNT=0

    while IFS=',' read -r ts tok || [ -n "$ts" ]; do
        line_num=$((line_num + 1))

        # Skip empty lines
        [ -z "$ts" ] && continue

        # Validate format (simple numeric check)
        case "$ts" in
            ''|*[!0-9]*)
                skipped_lines=$((skipped_lines + 1))
                [ $skipped_lines -le 3 ] && warn "Skipping invalid line $line_num: $ts,$tok"
                continue
                ;;
        esac
        case "$tok" in
            ''|*[!0-9]*)
                skipped_lines=$((skipped_lines + 1))
                [ $skipped_lines -le 3 ] && warn "Skipping invalid line $line_num: $ts,$tok"
                continue
                ;;
        esac

        # Append to space-separated strings (bash 3.2 compatible)
        if [ -z "$TIMESTAMPS" ]; then
            TIMESTAMPS="$ts"
            TOKENS="$tok"
        else
            TIMESTAMPS="$TIMESTAMPS $ts"
            TOKENS="$TOKENS $tok"
        fi
        valid_lines=$((valid_lines + 1))
    done < "$file"

    DATA_COUNT=$valid_lines

    if [ $skipped_lines -gt 3 ]; then
        warn "... and $((skipped_lines - 3)) more invalid lines"
    fi

    if [ $valid_lines -lt 2 ]; then
        error_exit "Loaded only $valid_lines valid data points. Need at least 2."
    fi

    info "Loaded $valid_lines data points from $(basename "$file")"
}

calculate_deltas() {
    local prev_tok=""
    DELTAS=""

    for tok in $TOKENS; do
        if [ -z "$prev_tok" ]; then
            # First delta is initial token count
            DELTAS="$tok"
        else
            local delta=$((tok - prev_tok))
            # Handle negative deltas (session reset) by showing 0
            [ $delta -lt 0 ] && delta=0
            DELTAS="$DELTAS $delta"
        fi
        prev_tok=$tok
    done
}

# Get Nth element from space-separated string (1-indexed)
get_element() {
    local str=$1
    local idx=$2
    echo "$str" | awk -v n="$idx" '{ print $n }'
}

# Get min/max/avg from space-separated numbers
get_stats() {
    local data=$1
    echo "$data" | tr ' ' '\n' | awk '
        BEGIN { min=999999999999; max=0; sum=0; n=0 }
        {
            if ($1 < min) min = $1
            if ($1 > max) max = $1
            sum += $1
            n++
        }
        END {
            avg = (n > 0) ? int(sum/n) : 0
            print min, max, avg, sum, n
        }
    '
}

# === GRAPH RENDERING ===

render_timeseries_graph() {
    local title=$1
    local data=$2
    local times=$3
    local color=$4

    local n
    n=$(echo "$data" | wc -w | tr -d ' ')
    [ "$n" -eq 0 ] && return

    # Get min/max
    local stats
    stats=$(get_stats "$data")
    local min max avg
    min=$(echo "$stats" | cut -d' ' -f1)
    max=$(echo "$stats" | cut -d' ' -f2)
    avg=$(echo "$stats" | cut -d' ' -f3)

    # Avoid division by zero
    [ "$min" -eq "$max" ] && max=$((min + 1))
    local range=$((max - min))

    # Print title
    echo ""
    echo -e "${BOLD}$title${RESET}"
    echo -e "${DIM}Max: $(format_number $max)  Min: $(format_number $min)  Points: $n${RESET}"
    echo ""

    # Build grid using awk for portability
    local grid_output
    grid_output=$(echo "$data" | awk -v width="$GRAPH_WIDTH" -v height="$GRAPH_HEIGHT" \
        -v min="$min" -v max="$max" -v range="$range" '
    BEGIN {
        # Initialize grid with spaces
        for (r = 0; r < height; r++) {
            for (c = 0; c < width; c++) {
                grid[r,c] = " "
            }
        }
    }
    {
        n = NF
        prev_x = -1
        prev_y = -1

        for (i = 1; i <= n; i++) {
            val = $i

            # Map index to x coordinate
            if (n == 1) {
                x = int(width / 2)
            } else {
                x = int((i - 1) * (width - 1) / (n - 1))
            }
            if (x >= width) x = width - 1
            if (x < 0) x = 0

            # Map value to y coordinate (inverted: 0=top)
            y = int((max - val) * (height - 1) / range)
            if (y >= height) y = height - 1
            if (y < 0) y = 0

            # Draw vertical line from previous point if needed
            if (prev_x >= 0 && prev_y != y) {
                if (prev_y < y) {
                    for (ly = prev_y + 1; ly < y; ly++) {
                        grid[ly, prev_x] = "|"
                    }
                } else {
                    for (ly = prev_y - 1; ly > y; ly--) {
                        grid[ly, x] = "|"
                    }
                }
            }

            # Plot point
            grid[y, x] = "@"

            prev_x = x
            prev_y = y
        }
    }
    END {
        # Print grid
        for (r = 0; r < height; r++) {
            row = ""
            for (c = 0; c < width; c++) {
                row = row grid[r,c]
            }
            print row
        }
    }')

    # Print grid with Y-axis labels
    local r=0
    while [ $r -lt $GRAPH_HEIGHT ]; do
        local val=$((max - r * range / (GRAPH_HEIGHT - 1)))
        local label=""

        # Show labels at top, middle, and bottom
        if [ $r -eq 0 ] || [ $r -eq $((GRAPH_HEIGHT/2)) ] || [ $r -eq $((GRAPH_HEIGHT-1)) ]; then
            label=$(format_number $val)
        fi

        local row
        row=$(echo "$grid_output" | sed -n "$((r+1))p")
        printf "%10s ${DIM}|${RESET}${color}%s${RESET}\n" "$label" "$row"
        r=$((r + 1))
    done

    # X-axis
    printf "%10s ${DIM}+" ""
    local c=0
    while [ $c -lt $GRAPH_WIDTH ]; do
        printf "-"
        c=$((c + 1))
    done
    printf "${RESET}\n"

    # Time labels
    local first_time last_time mid_time
    first_time=$(format_timestamp "$(get_element "$times" 1)")
    last_time=$(format_timestamp "$(get_element "$times" "$n")")
    local mid_idx=$(((n + 1) / 2))
    mid_time=$(format_timestamp "$(get_element "$times" "$mid_idx")")

    printf "%11s${DIM}%-*s%s%*s${RESET}\n" "" "$((GRAPH_WIDTH/3))" "$first_time" "$mid_time" "$((GRAPH_WIDTH/3))" "$last_time"
}

render_summary() {
    local first_ts last_ts duration current_tokens total_growth
    first_ts=$(get_element "$TIMESTAMPS" 1)
    last_ts=$(get_element "$TIMESTAMPS" "$DATA_COUNT")
    duration=$((last_ts - first_ts))
    current_tokens=$(get_element "$TOKENS" "$DATA_COUNT")
    local first_tokens
    first_tokens=$(get_element "$TOKENS" 1)
    total_growth=$((current_tokens - first_tokens))

    # Get statistics
    local del_stats
    del_stats=$(get_stats "$DELTAS")
    local del_max del_avg
    del_max=$(echo "$del_stats" | cut -d' ' -f2)
    del_avg=$(echo "$del_stats" | cut -d' ' -f3)

    echo ""
    echo -e "${BOLD}Summary Statistics${RESET}"
    local line_width=$((GRAPH_WIDTH + 11))
    printf "${DIM}"
    local i=0
    while [ $i -lt $line_width ]; do
        printf "-"
        i=$((i + 1))
    done
    printf "${RESET}\n"

    printf "  ${CYAN}%-20s${RESET} %s\n" "Current Tokens:" "$(format_number $current_tokens)"
    printf "  ${CYAN}%-20s${RESET} %s\n" "Session Duration:" "$(format_duration $duration)"
    printf "  ${CYAN}%-20s${RESET} %s\n" "Data Points:" "$DATA_COUNT"
    printf "  ${CYAN}%-20s${RESET} %s\n" "Average Delta:" "$(format_number $del_avg)"
    printf "  ${CYAN}%-20s${RESET} %s\n" "Max Delta:" "$(format_number $del_max)"
    printf "  ${CYAN}%-20s${RESET} %s\n" "Total Growth:" "$(format_number $total_growth)"
    echo ""
}

# === ARGUMENT PARSING ===

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --no-color)
                COLOR_ENABLED=false
                shift
                ;;
            --type)
                if [ $# -lt 2 ]; then
                    error_exit "--type requires an argument: cumulative, delta, or both"
                fi
                case "$2" in
                    cumulative|delta|both)
                        GRAPH_TYPE="$2"
                        ;;
                    *)
                        error_exit "Invalid graph type: $2. Use: cumulative, delta, or both"
                        ;;
                esac
                shift 2
                ;;
            --*)
                error_exit "Unknown option: $1\nUse --help for usage information."
                ;;
            *)
                # Assume it's a session ID
                if [ -z "$SESSION_ID" ]; then
                    SESSION_ID="$1"
                else
                    error_exit "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done
}

# === MAIN ===

main() {
    parse_args "$@"
    init_colors
    get_terminal_dimensions

    # Load configuration safely (no sourcing to prevent code injection)
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='=' read -r key value || [ -n "$key" ]; do
            # Skip comments and empty lines
            case "$key" in
                '#'*|'') continue ;;
            esac

            # Sanitize key and value
            key=$(echo "$key" | tr -d '[:space:]')
            value=$(echo "$value" | tr -d '"' | tr -d "'" | tr -d '[:space:]')

            case "$key" in
                token_detail)
                    if [ "$value" = "false" ]; then
                        TOKEN_DETAIL_ENABLED=false
                    fi
                    ;;
            esac
        done < "$CONFIG_FILE"
    fi

    # Find and validate state file
    local state_file
    state_file=$(find_latest_state_file)
    validate_state_file "$state_file"

    # Load data
    load_token_history "$state_file"
    calculate_deltas

    # Display header
    local session_name
    session_name=$(basename "$state_file" .state | sed 's/statusline\.//')
    echo ""
    echo -e "${BOLD}${MAGENTA}Token Usage Graphs${RESET} ${DIM}(Session: $session_name)${RESET}"

    # Render graphs
    case "$GRAPH_TYPE" in
        cumulative)
            render_timeseries_graph "Cumulative Token Usage" "$TOKENS" "$TIMESTAMPS" "$GREEN"
            ;;
        delta)
            render_timeseries_graph "Token Delta Per Interval" "$DELTAS" "$TIMESTAMPS" "$CYAN"
            ;;
        both)
            render_timeseries_graph "Cumulative Token Usage" "$TOKENS" "$TIMESTAMPS" "$GREEN"
            render_timeseries_graph "Token Delta Per Interval" "$DELTAS" "$TIMESTAMPS" "$CYAN"
            ;;
    esac

    # Render summary
    render_summary
}

main "$@"
