#!/bin/bash
# Full-featured status line with context window usage
# Usage: Copy to ~/.claude/statusline.sh and make executable
#
# Configuration:
# Create/edit ~/.claude/statusline.conf and set:
#
#   autocompact=true   (when autocompact is enabled in Claude Code - default)
#   autocompact=false  (when you disable autocompact via /config in Claude Code)
#
#   token_detail=true  (show exact token count like 64,000 - default)
#   token_detail=false (show abbreviated tokens like 64.0k)
#
# When AC is enabled, 22.5% of context window is reserved for autocompact buffer.

# Colors
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

# Read JSON input from stdin
input=$(cat)

# Extract information from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
dir_name=$(basename "$cwd")

# Git information (skip optional locks for performance)
git_info=""
if [[ -d "$project_dir/.git" ]]; then
    git_branch=$(cd "$project_dir" 2>/dev/null && git --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
    git_status_count=$(cd "$project_dir" 2>/dev/null && git --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    if [[ -n "$git_branch" ]]; then
        if [[ "$git_status_count" != "0" ]]; then
            git_info=" | ${MAGENTA}${git_branch}${RESET} ${CYAN}[${git_status_count}]${RESET}"
        else
            git_info=" | ${MAGENTA}${git_branch}${RESET}"
        fi
    fi
fi

# Read settings from ~/.claude/statusline.conf
# Sync this manually when you change settings in Claude Code via /config
autocompact_enabled=true
token_detail_enabled=true
autocompact=""  # Will be set by sourced config
token_detail="" # Will be set by sourced config
ac_info=""
if [[ -f ~/.claude/statusline.conf ]]; then
    # shellcheck source=/dev/null
    source ~/.claude/statusline.conf
    if [[ "$autocompact" == "false" ]]; then
        autocompact_enabled=false
    fi
    if [[ "$token_detail" == "false" ]]; then
        token_detail_enabled=false
    fi
fi

# Calculate context window - show remaining free space
context_info=""
total_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
current_usage=$(echo "$input" | jq '.context_window.current_usage')

if [[ "$total_size" -gt 0 && "$current_usage" != "null" ]]; then
    # Get tokens from current_usage (includes cache)
    input_tokens=$(echo "$current_usage" | jq -r '.input_tokens // 0')
    cache_creation=$(echo "$current_usage" | jq -r '.cache_creation_input_tokens // 0')
    cache_read=$(echo "$current_usage" | jq -r '.cache_read_input_tokens // 0')

    # Total used from current request
    used_tokens=$((input_tokens + cache_creation + cache_read))

    # Calculate autocompact buffer (22.5% of context window = 45k for 200k)
    autocompact_buffer=$((total_size * 225 / 1000))

    # Free tokens calculation depends on autocompact setting
    if [[ "$autocompact_enabled" == "true" ]]; then
        # When AC enabled: subtract buffer to show actual usable space
        free_tokens=$((total_size - used_tokens - autocompact_buffer))
        buffer_k=$(awk "BEGIN {printf \"%.0f\", $autocompact_buffer / 1000}")
        ac_info=" ${DIM}[AC:${buffer_k}k]${RESET}"
    else
        # When AC disabled: show full free space
        free_tokens=$((total_size - used_tokens))
        ac_info=" ${DIM}[AC:off]${RESET}"
    fi

    if [[ "$free_tokens" -lt 0 ]]; then
        free_tokens=0
    fi

    # Calculate percentage with one decimal (relative to total size)
    free_pct=$(awk "BEGIN {printf \"%.1f\", ($free_tokens * 100.0 / $total_size)}")
    free_pct_int=${free_pct%.*}

    # Format tokens based on token_detail setting
    if [[ "$token_detail_enabled" == "true" ]]; then
        # Use awk for portable comma formatting (works regardless of locale)
        free_display=$(awk -v n="$free_tokens" 'BEGIN { printf "%\047d", n }')
    else
        free_display=$(awk "BEGIN {printf \"%.1fk\", $free_tokens / 1000}")
    fi

    # Color based on free percentage
    if [[ "$free_pct_int" -gt 50 ]]; then
        ctx_color="$GREEN"
    elif [[ "$free_pct_int" -gt 25 ]]; then
        ctx_color="$YELLOW"
    else
        ctx_color="$RED"
    fi

    context_info=" | ${ctx_color}${free_display} free (${free_pct}%)${RESET}"
fi

# Output: [Model] directory | branch [changes] | XXk free (XX%) [AC]
echo -e "${DIM}[${model}]${RESET} ${BLUE}${dir_name}${RESET}${git_info}${context_info}${ac_info}"
