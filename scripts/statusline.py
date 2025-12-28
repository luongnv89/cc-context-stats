#!/usr/bin/env python3
"""
Python status line script for Claude Code
Usage: Copy to ~/.claude/statusline.py and make executable

Autocompact Configuration:
The AC (autocompact) setting must be manually synced with Claude Code.
Create/edit ~/.claude/statusline.conf and set:
  autocompact=true   (when autocompact is enabled in Claude Code - default)
  autocompact=false  (when you disable autocompact via /config in Claude Code)

When AC is enabled, 22.5% of context window is reserved for autocompact buffer.
"""

import json
import sys
import os
import subprocess

# ANSI Colors
BLUE = '\033[0;34m'
MAGENTA = '\033[0;35m'
CYAN = '\033[0;36m'
GREEN = '\033[0;32m'
YELLOW = '\033[0;33m'
RED = '\033[0;31m'
DIM = '\033[2m'
RESET = '\033[0m'


def get_git_info(project_dir):
    """Get git branch and change count"""
    git_dir = os.path.join(project_dir, '.git')
    if not os.path.isdir(git_dir):
        return ""

    try:
        # Get branch name (skip optional locks for performance)
        result = subprocess.run(
            ['git', '--no-optional-locks', 'rev-parse', '--abbrev-ref', 'HEAD'],
            cwd=project_dir,
            capture_output=True,
            text=True
        )
        branch = result.stdout.strip()

        if not branch:
            return ""

        # Count changes
        result = subprocess.run(
            ['git', '--no-optional-locks', 'status', '--porcelain'],
            cwd=project_dir,
            capture_output=True,
            text=True
        )
        changes = len([l for l in result.stdout.split('\n') if l.strip()])

        if changes > 0:
            return f" | {MAGENTA}{branch}{RESET} {CYAN}[{changes}]{RESET}"
        return f" | {MAGENTA}{branch}{RESET}"
    except Exception:
        return ""


def read_autocompact_setting():
    """Read autocompact setting from config file"""
    config_path = os.path.expanduser('~/.claude/statusline.conf')
    if not os.path.exists(config_path):
        return True  # Default: enabled

    try:
        with open(config_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('#') or '=' not in line:
                    continue
                key, value = line.split('=', 1)
                if key.strip() == 'autocompact':
                    return value.strip().lower() != 'false'
    except Exception:
        pass
    return True  # Default: enabled


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("[Claude] ~")
        return

    # Extract data
    cwd = data.get('workspace', {}).get('current_dir', '~')
    project_dir = data.get('workspace', {}).get('project_dir', cwd)
    model = data.get('model', {}).get('display_name', 'Claude')
    dir_name = os.path.basename(cwd) or '~'

    # Git info
    git_info = get_git_info(project_dir)

    # Autocompact setting - read from config file
    autocompact_enabled = read_autocompact_setting()

    # Context window calculation
    context_info = ""
    ac_info = ""
    total_size = data.get('context_window', {}).get('context_window_size', 0)
    current_usage = data.get('context_window', {}).get('current_usage')

    if total_size > 0 and current_usage:
        # Get tokens from current_usage (includes cache)
        input_tokens = current_usage.get('input_tokens', 0)
        cache_creation = current_usage.get('cache_creation_input_tokens', 0)
        cache_read = current_usage.get('cache_read_input_tokens', 0)

        # Total used from current request
        used_tokens = input_tokens + cache_creation + cache_read

        # Calculate autocompact buffer (22.5% of context window = 45k for 200k)
        autocompact_buffer = int(total_size * 0.225)

        # Free tokens calculation depends on autocompact setting
        if autocompact_enabled:
            # When AC enabled: subtract buffer to show actual usable space
            free_tokens = total_size - used_tokens - autocompact_buffer
            ac_info = f" {DIM}[AC]{RESET}"
        else:
            # When AC disabled: show full free space
            free_tokens = total_size - used_tokens
            ac_info = f" {DIM}[AC:off]{RESET}"

        if free_tokens < 0:
            free_tokens = 0

        # Calculate percentage with one decimal (relative to total size)
        free_pct = (free_tokens * 100.0) / total_size
        free_pct_int = int(free_pct)

        # Format tokens in k with one decimal
        free_display = f"{free_tokens / 1000:.1f}k"

        # Color based on free percentage
        if free_pct_int > 50:
            ctx_color = GREEN
        elif free_pct_int > 25:
            ctx_color = YELLOW
        else:
            ctx_color = RED

        context_info = f" | {ctx_color}{free_display} free ({free_pct:.1f}%){RESET}"

    # Token metrics (without cost)
    token_metrics = ""
    total_input_tokens = data.get('context_window', {}).get('total_input_tokens', 0)
    total_output_tokens = data.get('context_window', {}).get('total_output_tokens', 0)

    # Get cache info from current_usage
    cache_creation_tokens = data.get('context_window', {}).get('current_usage', {}).get('cache_creation_input_tokens', 0)
    cache_read_tokens = data.get('context_window', {}).get('current_usage', {}).get('cache_read_input_tokens', 0)

    if total_input_tokens > 0 or total_output_tokens > 0:
        in_k = total_input_tokens // 1000
        out_k = total_output_tokens // 1000

        # Build token info string with colors: in=blue, out=magenta, cache=cyan
        # Format: [in:72k,out:83k,cache:41k]
        cache_total = cache_creation_tokens + cache_read_tokens
        if cache_total > 0:
            cache_k = cache_total // 1000
            token_info = f"{DIM}[{RESET}{BLUE}in:{in_k}k{RESET}{DIM},{RESET}{MAGENTA}out:{out_k}k{RESET}{DIM},{RESET}{CYAN}cache:{cache_k}k{RESET}{DIM}]{RESET}"
        else:
            token_info = f"{DIM}[{RESET}{BLUE}in:{in_k}k{RESET}{DIM},{RESET}{MAGENTA}out:{out_k}k{RESET}{DIM}]{RESET}"

        token_metrics = f" | {token_info}"

    # Output: [Model] directory | branch [changes] | XXk free (XX%) [AC] | [in:Xk,out:Xk,cache:Xk]
    print(f"{DIM}[{model}]{RESET} {BLUE}{dir_name}{RESET}{git_info}{context_info}{ac_info}{token_metrics}")


if __name__ == '__main__':
    main()
