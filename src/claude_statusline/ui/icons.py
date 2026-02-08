"""Activity icons and Pacman meter for token usage visualization."""

from __future__ import annotations

from enum import Enum

from claude_statusline.core.state import StateEntry
from claude_statusline.graphs.statistics import calculate_deltas, detect_spike


class ActivityTier(Enum):
    """Token activity intensity tiers."""

    IDLE = "idle"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    SPIKE = "spike"


# Standard mode icons (meaningful without color)
STANDARD_ICONS: dict[ActivityTier, str] = {
    ActivityTier.IDLE: "\u25cb",     # ○ empty circle
    ActivityTier.LOW: "\u25d0",      # ◐ half circle
    ActivityTier.MEDIUM: "\u25c9",   # ◉ bullseye
    ActivityTier.HIGH: "\u26a1",     # ⚡ lightning
    ActivityTier.SPIKE: "\U0001f4a5",  # 💥 burst
}

# Pacman mode icons
PACMAN_ICONS: dict[ActivityTier, str] = {
    ActivityTier.IDLE: "\u00b7",            # · dot
    ActivityTier.LOW: "\u15e7\u00b7\u00b7\u00b7",      # ᗧ···
    ActivityTier.MEDIUM: "\u15e7\u25cb\u00b7\u25cf",    # ᗧ○·●
    ActivityTier.HIGH: "\u15e7\u25cf\u25cf\u25cf",      # ᗧ●●●
    ActivityTier.SPIKE: "\U0001f47b\u15e7\u25cf\u25cf\u25cf",  # 👻ᗧ●●●
}

# Tier labels for accessibility (understandable without color)
TIER_LABELS: dict[ActivityTier, str] = {
    ActivityTier.IDLE: "Idle",
    ActivityTier.LOW: "Low activity",
    ActivityTier.MEDIUM: "Active",
    ActivityTier.HIGH: "High activity",
    ActivityTier.SPIKE: "Spike!",
}


def get_activity_tier(
    entries: list[StateEntry],
    context_window_size: int,
) -> ActivityTier:
    """Determine the current activity tier based on recent token deltas.

    Args:
        entries: List of StateEntry objects (chronological order)
        context_window_size: Total context window size in tokens

    Returns:
        The current ActivityTier
    """
    if len(entries) < 2:
        return ActivityTier.IDLE

    # Check if session is idle (>30s since last entry)
    import time

    now = int(time.time())
    last_timestamp = entries[-1].timestamp
    if now - last_timestamp > 30:
        return ActivityTier.IDLE

    # Calculate deltas from context usage
    context_used = [e.current_used_tokens for e in entries]
    deltas = calculate_deltas(context_used)

    if not deltas:
        return ActivityTier.IDLE

    latest_delta = deltas[-1]

    if context_window_size <= 0:
        return ActivityTier.LOW if latest_delta > 0 else ActivityTier.IDLE

    # Check for spike first (highest priority)
    if detect_spike(deltas, context_window_size):
        return ActivityTier.SPIKE

    # Calculate delta as percentage of context window
    delta_pct = (latest_delta / context_window_size) * 100

    if delta_pct > 5:
        return ActivityTier.HIGH
    elif delta_pct > 2:
        return ActivityTier.MEDIUM
    elif latest_delta > 0:
        return ActivityTier.LOW
    else:
        return ActivityTier.IDLE


def get_activity_icon(tier: ActivityTier, mode: str = "standard") -> str:
    """Get the icon for an activity tier.

    Args:
        tier: The activity tier
        mode: Icon mode - "standard", "pacman", or "off"

    Returns:
        Icon string, or empty string if mode is "off"
    """
    if mode == "off":
        return ""
    elif mode == "pacman":
        return PACMAN_ICONS.get(tier, "")
    else:
        return STANDARD_ICONS.get(tier, "")


def get_tier_label(tier: ActivityTier) -> str:
    """Get an accessible text label for a tier.

    Args:
        tier: The activity tier

    Returns:
        Human-readable label string
    """
    return TIER_LABELS.get(tier, "")


def render_pacman_meter(
    usage_pct: int,
    tier: ActivityTier,
    width: int = 30,
) -> str:
    """Render a Pacman-style context usage meter.

    The meter shows Pacman eating through a bar representing context usage.
    Pacman's position corresponds to the usage percentage.

    Args:
        usage_pct: Context usage percentage (0-100)
        tier: Current activity tier (affects Pacman appearance)
        width: Total width of the meter bar in characters

    Returns:
        Formatted meter string (no color codes - caller adds color)
    """
    usage_pct = max(0, min(100, usage_pct))
    bar_width = max(10, width)

    # Pacman position along the bar
    pacman_pos = int((usage_pct / 100) * (bar_width - 1))
    pacman_pos = max(0, min(bar_width - 1, pacman_pos))

    # Choose Pacman character
    if usage_pct > 80:
        pacman = "\u15e4"  # ᗤ fat pacman
    else:
        pacman = "\u15e7"  # ᗧ normal pacman

    # Ghost at the end during spikes
    ghost = "\U0001f47b" if tier == ActivityTier.SPIKE else " "

    # Build the bar
    # Left of pacman: empty (already eaten) = ░
    # Right of pacman: filled (yet to eat) = █
    eaten = "\u2591" * pacman_pos          # ░ light shade
    remaining = "\u2588" * (bar_width - pacman_pos - 1)  # █ full block

    meter = f"{eaten}{pacman}{remaining}{ghost}"
    label = f" {usage_pct}% used"

    return f"{meter}{label}"
