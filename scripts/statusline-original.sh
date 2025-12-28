#!/bin/bash
# Original status line - alternative format with token metrics
# Usage: Copy to ~/.claude/statusline.sh and make executable
#
# Autocompact Configuration:
# The AC (autocompact) setting must be manually synced with Claude Code.
# Create/edit ~/.claude/statusline.conf and set:
#   autocompact=true   (when autocompact is enabled in Claude Code - default)
#   autocompact=false  (when you disable autocompact via /config in Claude Code)
#
# When AC is enabled, 22.5% of context window is reserved for autocompact buffer.

# Colors
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
DIM='\033[2m'
RESET='\033[0m'

# Read JSON input from stdin
input=$(cat)

# Extract information from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
dir_name=$(basename "$cwd")

# Git information (skip optional locks)
git_info=""
if [[ -d "$project_dir/.git" ]]; then
    git_branch=$(cd "$project_dir" 2>/dev/null && git --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
    git_status_count=$(cd "$project_dir" 2>/dev/null && git --no-optional-locks status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    if [[ -n "$git_branch" ]]; then
        if [[ "$git_status_count" != "0" ]]; then
            git_info=" ${MAGENTA}${git_branch}${RESET} ${CYAN}●${git_status_count}${RESET}"
        else
            git_info=" ${MAGENTA}${git_branch}${RESET}"
        fi
    fi
fi

# Autocompact setting - read from ~/.claude/statusline.conf
autocompact_enabled=true
ac_info=""
if [[ -f ~/.claude/statusline.conf ]]; then
    source ~/.claude/statusline.conf
    if [[ "$autocompact" == "false" ]]; then
        autocompact_enabled=false
    fi
fi

# Calculate context window - show remaining free space
context_free=""
total_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
current_usage=$(echo "$input" | jq '.context_window.current_usage')

if [[ "$total_size" -gt 0 && "$current_usage" != "null" ]]; then
    # Get tokens from current_usage (includes cache)
    input_tokens=$(echo "$current_usage" | jq -r '.input_tokens // 0')
    cache_creation=$(echo "$current_usage" | jq -r '.cache_creation_input_tokens // 0')
    cache_read=$(echo "$current_usage" | jq -r '.cache_read_input_tokens // 0')

    # Total used from current request
    used_tokens=$((input_tokens + cache_creation + cache_read))

    # Autocompact buffer is ~22.5% of context window (45k for 200k context)
    autocompact_buffer=$((total_size * 225 / 1000))

    # Free tokens calculation depends on autocompact setting
    if [[ "$autocompact_enabled" == "true" ]]; then
        free_tokens=$((total_size - used_tokens - autocompact_buffer))
        ac_info=" ${DIM}[AC]${RESET}"
    else
        free_tokens=$((total_size - used_tokens))
        ac_info=" ${DIM}[AC:off]${RESET}"
    fi

    if [[ "$free_tokens" -lt 0 ]]; then
        free_tokens=0
    fi
    free_pct=$((free_tokens * 100 / total_size))

    # Format tokens in k
    free_k=$((free_tokens / 1000))
    context_free=" ${GREEN}[${free_k}k free (${free_pct}%)]${RESET}"
fi

# Token metrics
token_info=""
total_input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
cache_creation_tokens=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read_tokens=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

if [[ "$total_input_tokens" -gt 0 || "$total_output_tokens" -gt 0 ]]; then
    in_k=$(awk "BEGIN {printf \"%.0f\", $total_input_tokens / 1000}")
    out_k=$(awk "BEGIN {printf \"%.0f\", $total_output_tokens / 1000}")

    # Build token info string with colors: in=blue, out=magenta, cache=cyan
    # Format: [in:72k,out:83k,cache:41k]
    cache_total=$((cache_creation_tokens + cache_read_tokens))
    if [[ "$cache_total" -gt 0 ]]; then
        cache_k=$(awk "BEGIN {printf \"%.0f\", $cache_total / 1000}")
        token_info=" ${DIM}[${RESET}${BLUE}in:${in_k}k${RESET}${DIM},${RESET}${MAGENTA}out:${out_k}k${RESET}${DIM},${RESET}${CYAN}cache:${cache_k}k${RESET}${DIM}]${RESET}"
    else
        token_info=" ${DIM}[${RESET}${BLUE}in:${in_k}k${RESET}${DIM},${RESET}${MAGENTA}out:${out_k}k${RESET}${DIM}]${RESET}"
    fi
fi

# Output: [dir] branch ●changes • Model [Xk free (X%)] [AC] [in:Xk,out:Xk,cache:Xk]
echo -e "${BLUE}[${dir_name}]${RESET}${git_info} ${DIM}• ${model}${RESET}${context_free}${ac_info}${token_info}"
