#!/usr/bin/env python3
"""CLI entry point for claude-statusline command.

Usage: Copy to ~/.claude/statusline.py and make executable, or install via pip.

Configuration:
Create/edit ~/.claude/statusline.conf and set:

  autocompact=true   (when autocompact is enabled in Claude Code - default)
  autocompact=false  (when you disable autocompact via /config in Claude Code)

  token_detail=true  (show exact token count like 64,000 - default)
  token_detail=false (show abbreviated tokens like 64.0k)

  show_delta=true    (show token delta since last refresh like [+2,500] - default)
  show_delta=false   (disable delta display - saves file I/O on every refresh)

  show_session=true  (show session_id in status line - default)
  show_session=false (hide session_id from status line)

When AC is enabled, 22.5% of context window is reserved for autocompact buffer.
"""

from __future__ import annotations

import json
import sys

from claude_statusline.core.colors import (
    BLUE,
    DIM,
    GREEN,
    RED,
    RESET,
    YELLOW,
)
from claude_statusline.core.config import Config
from claude_statusline.core.git import get_git_info
from claude_statusline.core.state import StateEntry, StateFile
from claude_statusline.formatters.time import get_current_timestamp
from claude_statusline.formatters.tokens import calculate_context_usage, format_tokens


def main() -> None:
    """Main entry point for claude-statusline CLI."""
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        print("[Claude] ~")
        return

    # Extract data
    cwd = data.get("workspace", {}).get("current_dir", "~")
    project_dir = data.get("workspace", {}).get("project_dir", cwd)
    model = data.get("model", {}).get("display_name", "Claude")
    dir_name = cwd.rsplit("/", 1)[-1] if "/" in cwd else cwd or "~"

    # Git info
    git_info = get_git_info(project_dir)

    # Read settings from config file
    config = Config.load()

    # Extract session_id once for reuse
    session_id = data.get("session_id")

    # Context window calculation
    context_info = ""
    ac_info = ""
    delta_info = ""
    session_info = ""

    total_size = data.get("context_window", {}).get("context_window_size", 0)
    current_usage = data.get("context_window", {}).get("current_usage")
    total_input_tokens = data.get("context_window", {}).get("total_input_tokens", 0)
    total_output_tokens = data.get("context_window", {}).get("total_output_tokens", 0)
    cost_usd = data.get("cost", {}).get("total_cost_usd", 0)
    lines_added = data.get("cost", {}).get("total_lines_added", 0)
    lines_removed = data.get("cost", {}).get("total_lines_removed", 0)
    model_id = data.get("model", {}).get("id", "")
    workspace_project_dir = data.get("workspace", {}).get("project_dir", "")

    if total_size > 0 and current_usage:
        # Get tokens from current_usage (includes cache)
        input_tokens = current_usage.get("input_tokens", 0)
        cache_creation = current_usage.get("cache_creation_input_tokens", 0)
        cache_read = current_usage.get("cache_read_input_tokens", 0)

        # Total used from current request
        used_tokens = input_tokens + cache_creation + cache_read

        # Calculate context usage
        free_tokens, free_pct, autocompact_buffer = calculate_context_usage(
            used_tokens,
            total_size,
            config.autocompact,
        )

        if config.autocompact:
            buffer_k = autocompact_buffer // 1000
            ac_info = f" {DIM}[AC:{buffer_k}k]{RESET}"
        else:
            ac_info = f" {DIM}[AC:off]{RESET}"

        # Format tokens based on token_detail setting
        free_display = format_tokens(free_tokens, config.token_detail)

        # Color based on free percentage
        free_pct_int = int(free_pct)
        if free_pct_int > 50:
            ctx_color = GREEN
        elif free_pct_int > 25:
            ctx_color = YELLOW
        else:
            ctx_color = RED

        context_info = f" | {ctx_color}{free_display} free ({free_pct:.1f}%){RESET}"

        # Calculate and display token delta if enabled
        if config.show_delta:
            state_file = StateFile(session_id)
            prev_entry = state_file.read_last_entry()

            prev_tokens = prev_entry.current_used_tokens if prev_entry else 0
            has_prev = prev_entry is not None

            # Calculate delta
            delta = used_tokens - prev_tokens

            # Only show positive delta (and skip first run when no previous state)
            if has_prev and delta > 0:
                delta_display = format_tokens(delta, config.token_detail)
                delta_info = f" {DIM}[+{delta_display}]{RESET}"

            # Append current usage
            cur_input_tokens = current_usage.get("input_tokens", 0)
            cur_output_tokens = current_usage.get("output_tokens", 0)

            entry = StateEntry(
                timestamp=get_current_timestamp(),
                total_input_tokens=total_input_tokens,
                total_output_tokens=total_output_tokens,
                current_input_tokens=cur_input_tokens,
                current_output_tokens=cur_output_tokens,
                cache_creation=cache_creation,
                cache_read=cache_read,
                cost_usd=cost_usd,
                lines_added=lines_added,
                lines_removed=lines_removed,
                session_id=session_id or "",
                model_id=model_id,
                workspace_project_dir=workspace_project_dir,
                context_window_size=total_size,
            )
            state_file.append_entry(entry)

    # Display session_id if enabled
    if config.show_session and session_id:
        session_info = f" {DIM}{session_id}{RESET}"

    # Output: [Model] directory | branch [changes] | XXk free (XX%) [+delta] [AC] [session_id]
    print(
        f"{DIM}[{model}]{RESET} {BLUE}{dir_name}{RESET}"
        f"{git_info}{context_info}{delta_info}{ac_info}{session_info}"
    )


if __name__ == "__main__":
    main()
