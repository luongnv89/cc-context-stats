"""Rotating waiting text for active sessions."""

from __future__ import annotations

import time

from claude_statusline.core.state import StateEntry

WAITING_MESSAGES = [
    "Thinking...",
    "Cooking...",
    "Crunching tokens...",
    "Compiling plan...",
    "Running steps...",
    "Processing...",
    "Working on it...",
    "Analyzing...",
]

# Static message for reduced-motion mode
STATIC_MESSAGE = "Working..."


def get_waiting_text(cycle_index: int, reduced_motion: bool = False) -> str:
    """Get the current waiting text based on the refresh cycle.

    Messages rotate every 2 cycles (approximately every 4 seconds at 2s refresh).

    Args:
        cycle_index: The current watch-mode refresh counter
        reduced_motion: If True, return a static message instead of rotating

    Returns:
        A waiting message string
    """
    if reduced_motion:
        return STATIC_MESSAGE

    # Rotate every 2 cycles to keep it readable
    message_index = (cycle_index // 2) % len(WAITING_MESSAGES)
    return WAITING_MESSAGES[message_index]


def is_active(entries: list[StateEntry], timeout: int = 30) -> bool:
    """Determine if the session is currently active.

    A session is considered active if the most recent state entry
    was recorded within `timeout` seconds of the current time.

    Args:
        entries: List of StateEntry objects (chronological order)
        timeout: Seconds since last entry to consider session active (default: 30)

    Returns:
        True if the session appears to be actively running
    """
    if not entries:
        return False

    now = int(time.time())
    last_timestamp = entries[-1].timestamp
    return (now - last_timestamp) <= timeout
