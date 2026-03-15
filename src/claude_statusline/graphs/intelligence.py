"""Model Intelligence (MI) score computation.

Estimates answer quality based on context utilization, cache efficiency,
and output productivity. Inspired by the Michelangelo paper
(arXiv:2409.12640, Google DeepMind, Sep 2024).
"""

from __future__ import annotations

from dataclasses import dataclass

from claude_statusline.core.state import StateEntry

# Hardcoded constants — not configurable, to minimize cross-implementation sync burden
MI_WEIGHT_CPS = 0.60
MI_WEIGHT_ES = 0.25
MI_WEIGHT_PS = 0.15
MI_GREEN_THRESHOLD = 0.65
MI_YELLOW_THRESHOLD = 0.35
MI_PRODUCTIVITY_TARGET = 0.2


@dataclass
class IntelligenceConfig:
    """Configuration for MI computation."""

    beta: float = 1.5


@dataclass
class IntelligenceScore:
    """MI score with sub-components."""

    cps: float
    es: float
    ps: float
    mi: float
    utilization: float


def calculate_context_pressure(utilization: float, beta: float = 1.5) -> float:
    """Calculate Context Pressure Score (CPS).

    CPS = max(0, 1 - u^beta) where u is utilization ratio [0, 1+].

    Args:
        utilization: Context utilization ratio (current_used / context_window_size)
        beta: Curve shape parameter (default 1.5)

    Returns:
        CPS value in [0, 1]
    """
    if utilization <= 0:
        return 1.0
    return max(0.0, 1.0 - utilization**beta)


def calculate_efficiency(entry: StateEntry) -> float:
    """Calculate Efficiency Score (ES).

    ES = 0.3 + 0.7 * cache_hit_ratio, where cache_hit_ratio = cache_read / total_context.

    Args:
        entry: Current state entry

    Returns:
        ES value in [0.3, 1.0]
    """
    total_context = entry.current_used_tokens
    if total_context == 0:
        return 1.0
    cache_hit_ratio = entry.cache_read / total_context
    return 0.3 + 0.7 * cache_hit_ratio


def calculate_productivity(
    current: StateEntry, previous: StateEntry | None
) -> float:
    """Calculate Productivity Score (PS).

    Uses consecutive entry diffs for delta_lines and delta_output_tokens.

    Args:
        current: Current state entry
        previous: Previous state entry, or None

    Returns:
        PS value in [0.2, 1.0], or 0.5 if no previous entry
    """
    if previous is None:
        return 0.5

    delta_lines_added = current.lines_added - previous.lines_added
    delta_lines_removed = current.lines_removed - previous.lines_removed
    delta_output_tokens = current.total_output_tokens - previous.total_output_tokens

    if delta_output_tokens <= 0:
        return 0.5

    delta_lines = delta_lines_added + delta_lines_removed
    ratio = delta_lines / delta_output_tokens
    normalized = min(1.0, ratio / MI_PRODUCTIVITY_TARGET)
    return 0.2 + 0.8 * normalized


def calculate_intelligence(
    current: StateEntry,
    previous: StateEntry | None,
    context_window_size: int,
    beta: float = 1.5,
) -> IntelligenceScore:
    """Calculate composite Model Intelligence score.

    Args:
        current: Current state entry
        previous: Previous state entry (for productivity delta)
        context_window_size: Total context window size in tokens
        beta: CPS curve shape parameter

    Returns:
        IntelligenceScore with all sub-scores and composite MI
    """
    # Guard clause: unknown context window
    if context_window_size == 0:
        return IntelligenceScore(cps=1.0, es=1.0, ps=0.5, mi=1.0, utilization=0.0)

    utilization = current.current_used_tokens / context_window_size
    cps = calculate_context_pressure(utilization, beta)
    es = calculate_efficiency(current)
    ps = calculate_productivity(current, previous)

    mi = MI_WEIGHT_CPS * cps + MI_WEIGHT_ES * es + MI_WEIGHT_PS * ps

    return IntelligenceScore(cps=cps, es=es, ps=ps, mi=mi, utilization=utilization)


def get_mi_color(mi: float) -> str:
    """Get color name for MI score.

    Args:
        mi: MI score value

    Returns:
        Color name: "green", "yellow", or "red"
    """
    if mi > MI_GREEN_THRESHOLD:
        return "green"
    if mi > MI_YELLOW_THRESHOLD:
        return "yellow"
    return "red"


def format_mi_score(mi: float) -> str:
    """Format MI score for display.

    Args:
        mi: MI score value

    Returns:
        Formatted string like "0.82"
    """
    return f"{mi:.2f}"
