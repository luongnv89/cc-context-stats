"""Layout utilities for fitting statusline output to terminal width."""

from __future__ import annotations

import re
import shutil

# Pattern to strip ANSI escape sequences
_ANSI_RE = re.compile(r"\033\[[0-9;]*m")


def visible_width(s: str) -> int:
    """Return the visible width of a string after stripping ANSI escape sequences."""
    return len(_ANSI_RE.sub("", s))


def get_terminal_width() -> int:
    """Return the terminal width in columns, defaulting to 80."""
    return shutil.get_terminal_size().columns


def fit_to_width(parts: list[str], max_width: int) -> str:
    """Assemble parts into a single line that fits within max_width.

    Parts are added in priority order (first = highest priority).
    The first part (base) is always included. Subsequent parts are
    included only if adding them does not exceed max_width.
    Empty parts are skipped.

    Args:
        parts: List of strings in priority order (highest first).
        max_width: Maximum visible width allowed.

    Returns:
        Assembled string that fits within max_width.
    """
    if not parts:
        return ""

    # Base part is always included
    result = parts[0]
    current_width = visible_width(result)

    for part in parts[1:]:
        if not part:
            continue
        part_width = visible_width(part)
        if current_width + part_width <= max_width:
            result += part
            current_width += part_width

    return result
