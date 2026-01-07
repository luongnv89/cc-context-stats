#!/bin/bash
# Token Usage Graph Visualizer for Claude Code
# Displays ASCII graphs of token consumption over time
#
# Usage:
#   token-graph.sh [session_id] [options]
#
# Options:
#   --type <cumulative|delta|both>  Graph type to display (default: both)
#   --watch, -w [interval]          Real-time monitoring mode (default: 2s)
#   --no-color                      Disable color output
#   --help                          Show this help
#
# Examples:
#   token-graph.sh                        # Latest session, both graphs
#   token-graph.sh abc123                 # Specific session
#   token-graph.sh --type delta           # Only delta graph
#   token-graph.sh --watch                # Real-time mode (2s refresh)
#   token-graph.sh -w 5                   # Real-time mode (5s refresh)

# Note: This script is compatible with bash 3.2+ (macOS default)

# === CONFIGURATION ===
# shellcheck disable=SC2034
VERSION="1.0.0"
COMMIT_HASH="dev" # Will be replaced during installation
STATE_DIR=~/.claude/statusline
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
INPUT_TOKENS=""
OUTPUT_TOKENS=""
DELTAS=""
DELTA_TIMES=""
DATA_COUNT=0
TERM_WIDTH=80
TERM_HEIGHT=24
GRAPH_WIDTH=60
GRAPH_HEIGHT=15
SESSION_ID=""
GRAPH_TYPE="both"
COLOR_ENABLED=true
TOKEN_DETAIL_ENABLED=true
WATCH_MODE=false
WATCH_INTERVAL=2

# === UTILITY FUNCTIONS ===

show_help() {
    cat <<'EOF'
Token Usage Graph Visualizer for Claude Code

USAGE:
    token-graph.sh [session_id] [options]

ARGUMENTS:
    session_id    Optional session ID. If not provided, uses the latest session.

OPTIONS:
    --type <type>  Graph type to display:
                   - cumulative: Total tokens over time
                   - delta: Token consumption per interval
                   - io: Input/output tokens over time
                   - both: Show cumulative and delta graphs (default)
                   - all: Show all graphs including I/O
    --watch, -w [interval]
                   Enable real-time monitoring mode.
                   Refreshes the graph every [interval] seconds (default: 2).
                   Press Ctrl+C to exit.
    --no-color     Disable color output
    --help         Show this help message

EXAMPLES:
    # Show graphs for latest session
    token-graph.sh

    # Show graphs for specific session
    token-graph.sh abc123def

    # Show only cumulative graph
    token-graph.sh --type cumulative

    # Show input/output token graphs
    token-graph.sh --type io

    # Real-time monitoring (refresh every 2 seconds)
    token-graph.sh --watch

    # Real-time monitoring with custom interval
    token-graph.sh -w 5

    # Combine options
    token-graph.sh abc123 --type cumulative --watch 3

    # Disable colors for piping to file
    token-graph.sh --no-color > output.txt

DATA SOURCE:
    Reads token history from ~/.claude/statusline/statusline.<session_id>.state
    CSV format: timestamp,total_input_tokens,total_output_tokens,current_usage_input_tokens,...

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
        # shellcheck disable=SC2034
        BLUE='' # Kept for consistency with other color definitions
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
    GRAPH_HEIGHT=$((TERM_HEIGHT / 3)) # Each graph takes 1/3 of terminal

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

migrate_old_state_files() {
    local old_dir=~/.claude
    local new_file
    mkdir -p "$STATE_DIR"
    for old_file in "$old_dir"/statusline*.state; do
        if [ -f "$old_file" ]; then
            new_file="${STATE_DIR}/$(basename "$old_file")"
            if [ ! -f "$new_file" ]; then
                mv "$old_file" "$new_file" 2>/dev/null || true
            else
                rm -f "$old_file" 2>/dev/null || true
            fi
        fi
    done
}

find_latest_state_file() {
    migrate_old_state_files

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
    latest=$(find "$STATE_DIR" -maxdepth 1 -name 'statusline.*.state' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

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
    line_count=$(wc -l <"$file" | tr -d ' ')

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
    INPUT_TOKENS=""
    OUTPUT_TOKENS=""
    CONTEXT_SIZES=""
    DATA_COUNT=0

    while IFS=',' read -r ts total_in total_out cur_in cur_out cache_creation cache_read cost_usd lines_added lines_removed session_id model_id workspace_project_dir context_size rest || [ -n "$ts" ]; do
        line_num=$((line_num + 1))

        # Skip empty lines
        [ -z "$ts" ] && continue

        # Validate timestamp (simple numeric check)
        case "$ts" in
        '' | *[!0-9]*)
            skipped_lines=$((skipped_lines + 1))
            [ $skipped_lines -le 3 ] && warn "Skipping invalid line $line_num"
            continue
            ;;
        esac

        # Handle both old format (timestamp,tokens) and new format (timestamp,total_in,total_out,...)
        if [ -z "$total_out" ]; then
            # Old format: timestamp,tokens - use tokens as both input and output combined
            local tok="$total_in"
            case "$tok" in
            '' | *[!0-9]*)
                skipped_lines=$((skipped_lines + 1))
                continue
                ;;
            esac
            total_in=$tok
            total_out=0
        fi

        # Validate numeric fields
        case "$total_in" in
        '' | *[!0-9]*) total_in=0 ;;
        esac
        case "$total_out" in
        '' | *[!0-9]*) total_out=0 ;;
        esac

        # Calculate combined tokens for backward compatibility
        local combined=$((total_in + total_out))

        # Validate context size (new format)
        case "$context_size" in
        '' | *[!0-9]*) context_size=0 ;;
        esac

        # Append to space-separated strings (bash 3.2 compatible)
        if [ -z "$TIMESTAMPS" ]; then
            TIMESTAMPS="$ts"
            TOKENS="$combined"
            INPUT_TOKENS="$total_in"
            OUTPUT_TOKENS="$total_out"
            CONTEXT_SIZES="$context_size"
        else
            TIMESTAMPS="$TIMESTAMPS $ts"
            TOKENS="$TOKENS $combined"
            INPUT_TOKENS="$INPUT_TOKENS $total_in"
            OUTPUT_TOKENS="$OUTPUT_TOKENS $total_out"
            CONTEXT_SIZES="$CONTEXT_SIZES $context_size"
        fi
        valid_lines=$((valid_lines + 1))
    done <"$file"

    DATA_COUNT=$valid_lines

    if [ $skipped_lines -gt 3 ]; then
        warn "... and $((skipped_lines - 3)) more invalid lines"
    fi

    if [ $valid_lines -lt 2 ]; then
        error_exit "Loaded only $valid_lines valid data points. Need at least 2."
    fi

    # Only show info message in non-watch mode
    if [ "$WATCH_MODE" != "true" ]; then
        info "Loaded $valid_lines data points from $(basename "$file")"
    fi
}

calculate_deltas() {
    local prev_tok=""
    local idx=0
    DELTAS=""
    DELTA_TIMES=""

    for tok in $TOKENS; do
        idx=$((idx + 1))
        if [ -z "$prev_tok" ]; then
            # Skip first data point - no previous value to compare against
            prev_tok=$tok
            continue
        fi

        local delta=$((tok - prev_tok))
        # Handle negative deltas (session reset) by showing 0
        [ $delta -lt 0 ] && delta=0

        # Get corresponding timestamp for this delta
        local ts
        ts=$(get_element "$TIMESTAMPS" "$idx")

        if [ -z "$DELTAS" ]; then
            DELTAS="$delta"
            DELTA_TIMES="$ts"
        else
            DELTAS="$DELTAS $delta"
            DELTA_TIMES="$DELTA_TIMES $ts"
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
    local min max
    min=$(echo "$stats" | cut -d' ' -f1)
    max=$(echo "$stats" | cut -d' ' -f2)
    # avg is available but not used in graph rendering

    # Avoid division by zero
    [ "$min" -eq "$max" ] && max=$((min + 1))
    local range=$((max - min))

    # Print title
    echo ""
    echo -e "${BOLD}$title${RESET}"
    echo -e "${DIM}Max: $(format_number "$max")  Min: $(format_number "$min")  Points: $n${RESET}"
    echo ""

    # Build grid using awk - smooth line with filled area below
    local grid_output
    grid_output=$(echo "$data" | awk -v width="$GRAPH_WIDTH" -v height="$GRAPH_HEIGHT" \
        -v min="$min" -v max="$max" -v range="$range" '
    BEGIN {
        # Characters for different parts of the graph
        # Line: dots for the trend line
        # Fill: lighter shading below the line
        dot = "●"
        fill_dark = "░"
        fill_light = "▒"
        empty = " "

        # Initialize grid with empty spaces
        for (r = 0; r < height; r++) {
            for (c = 0; c < width; c++) {
                grid[r,c] = empty
            }
        }

        # Store y values for each x position (for interpolation)
        for (c = 0; c < width; c++) {
            line_y[c] = -1
        }
    }
    {
        n = NF

        # First pass: calculate y position for each data point
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
            y = (max - val) * (height - 1) / range
            if (y >= height) y = height - 1
            if (y < 0) y = 0

            data_x[i] = x
            data_y[i] = y
        }

        # Second pass: interpolate between points to fill every x position
        for (i = 1; i < n; i++) {
            x1 = data_x[i]
            y1 = data_y[i]
            x2 = data_x[i+1]
            y2 = data_y[i+1]

            # Linear interpolation for each x between x1 and x2
            for (x = x1; x <= x2; x++) {
                if (x2 == x1) {
                    y = y1
                } else {
                    # Linear interpolation
                    t = (x - x1) / (x2 - x1)
                    y = y1 + t * (y2 - y1)
                }
                line_y[x] = y
            }
        }

        # Third pass: draw the filled area and line
        for (c = 0; c < width; c++) {
            if (line_y[c] >= 0) {
                line_row = int(line_y[c] + 0.5)  # Round to nearest integer
                if (line_row >= height) line_row = height - 1
                if (line_row < 0) line_row = 0

                # Fill area below the line with gradient
                for (r = line_row; r < height; r++) {
                    if (r == line_row) {
                        grid[r, c] = dot  # The line itself
                    } else if (r < line_row + 2) {
                        grid[r, c] = fill_light  # Darker fill near line
                    } else {
                        grid[r, c] = fill_dark   # Lighter fill further down
                    }
                }
            }
        }

        # Fourth pass: mark actual data points with larger dots
        for (i = 1; i <= n; i++) {
            x = data_x[i]
            y = int(data_y[i] + 0.5)
            if (y >= height) y = height - 1
            if (y < 0) y = 0
            grid[y, x] = dot
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
        if [ $r -eq 0 ] || [ $r -eq $((GRAPH_HEIGHT / 2)) ] || [ $r -eq $((GRAPH_HEIGHT - 1)) ]; then
            label=$(format_number $val)
        fi

        local row
        row=$(echo "$grid_output" | sed -n "$((r + 1))p")
        printf "%10s ${DIM}│${RESET}${color}%s${RESET}\n" "$label" "$row"
        r=$((r + 1))
    done

    # X-axis
    printf "%10s ${DIM}└" ""
    local c=0
    while [ $c -lt $GRAPH_WIDTH ]; do
        printf "─"
        c=$((c + 1))
    done
    printf "%s\n" "${RESET}"

    # Time labels
    local first_time last_time mid_time
    first_time=$(format_timestamp "$(get_element "$times" 1)")
    last_time=$(format_timestamp "$(get_element "$times" "$n")")
    local mid_idx=$(((n + 1) / 2))
    mid_time=$(format_timestamp "$(get_element "$times" "$mid_idx")")

    printf "%11s${DIM}%-*s%s%*s${RESET}\n" "" "$((GRAPH_WIDTH / 3))" "$first_time" "$mid_time" "$((GRAPH_WIDTH / 3))" "$last_time"
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

    # Get I/O token stats
    local current_input current_output
    current_input=$(get_element "$INPUT_TOKENS" "$DATA_COUNT")
    current_output=$(get_element "$OUTPUT_TOKENS" "$DATA_COUNT")
    current_context=$(get_element "$CONTEXT_SIZES" "$DATA_COUNT")

    # Calculate remaining context window
    local total_used=$((current_input + current_output))
    local remaining_context=$((current_context - total_used))
    local context_percentage=0
    if [ "$current_context" -gt 0 ]; then
        context_percentage=$((remaining_context * 100 / current_context))
    fi

    # Get statistics
    local del_stats
    del_stats=$(get_stats "$DELTAS")
    local del_max del_avg
    del_max=$(echo "$del_stats" | cut -d' ' -f2)
    del_avg=$(echo "$del_stats" | cut -d' ' -f3)

    echo ""
    echo -e "${BOLD}Summary Statistics${RESET}"
    local line_width=$((GRAPH_WIDTH + 11))
    printf "%s" "${DIM}"
    local i=0
    while [ $i -lt $line_width ]; do
        printf "-"
        i=$((i + 1))
    done
    printf "%s\n" "${RESET}"

    printf "  ${CYAN}%-20s${RESET} %s\n" "Total Tokens:" "$(format_number "$current_tokens")"
    printf "  ${BLUE}%-20s${RESET} %s\n" "Input Tokens (↓):" "$(format_number "$current_input")"
    printf "  ${MAGENTA}%-20s${RESET} %s\n" "Output Tokens (↑):" "$(format_number "$current_output")"
    if [ "$current_context" -gt 0 ]; then
        printf "  ${GREEN}%-20s${RESET} %s (%s%%)\n" "Remaining Context:" "$(format_number "$remaining_context")" "$context_percentage"
    fi
    printf "  ${CYAN}%-20s${RESET} %s\n" "Session Duration:" "$(format_duration "$duration")"
    printf "  ${CYAN}%-20s${RESET} %s\n" "Data Points:" "$DATA_COUNT"
    printf "  ${CYAN}%-20s${RESET} %s\n" "Average Delta:" "$(format_number "$del_avg")"
    printf "  ${CYAN}%-20s${RESET} %s\n" "Max Delta:" "$(format_number "$del_max")"
    printf "  ${CYAN}%-20s${RESET} %s\n" "Total Growth:" "$(format_number "$total_growth")"
    echo ""
}

render_footer() {
    echo -e "${DIM}Powered by ${CYAN}claude-statusline${DIM} v${VERSION}-${COMMIT_HASH} - https://github.com/luongnv89/claude-statusline${RESET}"
    echo ""
}

# === ARGUMENT PARSING ===

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
        --help | -h)
            show_help
            exit 0
            ;;
        --no-color)
            COLOR_ENABLED=false
            shift
            ;;
        --watch | -w)
            WATCH_MODE=true
            # Check if next argument is a number (interval)
            if [ $# -ge 2 ] && [[ "$2" =~ ^[0-9]+$ ]]; then
                WATCH_INTERVAL="$2"
                shift 2
            else
                shift
            fi
            ;;
        --type)
            if [ $# -lt 2 ]; then
                error_exit "--type requires an argument: cumulative, delta, or both"
            fi
            case "$2" in
            cumulative | delta | io | both | all)
                GRAPH_TYPE="$2"
                ;;
            *)
                error_exit "Invalid graph type: $2. Use: cumulative, delta, io, both, or all"
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

# Load configuration from file
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='=' read -r key value || [ -n "$key" ]; do
            # Skip comments and empty lines
            case "$key" in
            '#'* | '') continue ;;
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
        done <"$CONFIG_FILE"
    fi
}

# Render graphs once
render_once() {
    local state_file=$1

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
        render_timeseries_graph "Token Delta Per Interval" "$DELTAS" "$DELTA_TIMES" "$CYAN"
        ;;
    io)
        render_timeseries_graph "Input Tokens (↓)" "$INPUT_TOKENS" "$TIMESTAMPS" "$BLUE"
        render_timeseries_graph "Output Tokens (↑)" "$OUTPUT_TOKENS" "$TIMESTAMPS" "$MAGENTA"
        ;;
    both)
        render_timeseries_graph "Cumulative Token Usage" "$TOKENS" "$TIMESTAMPS" "$GREEN"
        render_timeseries_graph "Token Delta Per Interval" "$DELTAS" "$DELTA_TIMES" "$CYAN"
        ;;
    all)
        render_timeseries_graph "Input Tokens (↓)" "$INPUT_TOKENS" "$TIMESTAMPS" "$BLUE"
        render_timeseries_graph "Output Tokens (↑)" "$OUTPUT_TOKENS" "$TIMESTAMPS" "$MAGENTA"
        render_timeseries_graph "Cumulative Token Usage" "$TOKENS" "$TIMESTAMPS" "$GREEN"
        render_timeseries_graph "Token Delta Per Interval" "$DELTAS" "$DELTA_TIMES" "$CYAN"
        ;;
    esac

    # Render summary
    render_summary

    # Render footer
    render_footer
}

# Watch mode - continuously refresh the display
run_watch_mode() {
    local state_file=$1

    # ANSI escape codes for cursor control
    local CURSOR_HOME='\033[H'
    local CLEAR_SCREEN='\033[2J'
    local HIDE_CURSOR='\033[?25l'
    local SHOW_CURSOR='\033[?25h'

    # Set up signal handler for clean exit
    trap 'printf "${SHOW_CURSOR}\n${DIM}Watch mode stopped.${RESET}\n"; exit 0' INT TERM

    # Hide cursor for cleaner display
    printf "%s" "${HIDE_CURSOR}"

    # Initial clear
    printf "%s%s" "${CLEAR_SCREEN}" "${CURSOR_HOME}"

    while true; do
        # Move cursor to home position (top-left) instead of clearing
        # This prevents flickering by overwriting in place
        printf "%s" "${CURSOR_HOME}"

        # Re-read terminal dimensions in case of resize
        get_terminal_dimensions

        # Show watch mode indicator with live timestamp
        local current_time
        current_time=$(date +%H:%M:%S)
        printf "%s[LIVE %s] Refresh: %ss | Ctrl+C to exit%s\n" "${DIM}" "${current_time}" "${WATCH_INTERVAL}" "${RESET}"

        # Re-validate and render (file might have new data)
        if [ -f "$state_file" ]; then
            local line_count
            line_count=$(wc -l <"$state_file" | tr -d ' ')
            if [ "$line_count" -ge 2 ]; then
                render_once "$state_file"
            else
                printf "\n%sWaiting for more data points...%s\n" "${YELLOW}" "${RESET}"
                printf "%sCurrent: %s point(s), need at least 2%s\n" "${DIM}" "$line_count" "${RESET}"
            fi
        else
            printf "\n%sState file not found: %s%s\n" "${RED}" "$state_file" "${RESET}"
            printf "%sWaiting for file to be created...%s\n" "${DIM}" "${RESET}"
        fi

        # Clear any remaining lines from previous render (in case terminal resized smaller)
        printf "\033[J"

        sleep "$WATCH_INTERVAL"
    done
}

main() {
    parse_args "$@"
    init_colors
    get_terminal_dimensions
    load_config

    # Find and validate state file
    local state_file
    state_file=$(find_latest_state_file)

    if [ "$WATCH_MODE" = "true" ]; then
        # Watch mode - don't exit on validation errors, keep trying
        run_watch_mode "$state_file"
    else
        # Single run mode
        validate_state_file "$state_file"
        render_once "$state_file"
    fi
}

main "$@"
