"""Model Intelligence (MI) score computation.

Estimates answer quality degradation based on context utilization.
Calibrated from MRCR v2 8-needle benchmark data showing that retrieval
quality degrades monotonically with context length, at different rates
per model family.

Formula: MI(u) = max(0, 1 - u^beta)
Where u = utilization ratio, beta is model-specific.
Higher beta = quality retained longer (degradation happens later).
"""

from __future__ import annotations

from dataclasses import dataclass

from claude_statusline.core.state import StateEntry

# MI color thresholds — based on MI value and context utilization
MI_GREEN_THRESHOLD = 0.90
MI_YELLOW_THRESHOLD = 0.80
# Context utilization zones (used as fallback for color decisions)
MI_CONTEXT_YELLOW_THRESHOLD = 0.40  # 40% context used
MI_CONTEXT_RED_THRESHOLD = 0.80     # 80% context used

# Per-model degradation profiles calibrated from MRCR v2 8-needle benchmark
# beta controls curve shape: higher = quality retained longer
# All models drop from 1.0 to 0.0, but at different rates
MODEL_PROFILES: dict[str, float] = {
    "opus": 1.8,    # retains quality longest, steep drop near end
    "sonnet": 1.5,  # moderate degradation
    "haiku": 1.2,   # degrades earliest
    "default": 1.5, # same as sonnet
}


@dataclass
class IntelligenceScore:
    """MI score with utilization info."""

    mi: float
    utilization: float


def get_model_profile(model_id: str) -> float:
    """Match model_id to degradation beta.

    Args:
        model_id: Model identifier string (e.g., "claude-opus-4-6[1m]")

    Returns:
        Beta value for the model's degradation curve
    """
    model_lower = model_id.lower()
    for family in ("opus", "sonnet", "haiku"):
        if family in model_lower:
            return MODEL_PROFILES[family]
    return MODEL_PROFILES["default"]


def calculate_context_pressure(utilization: float, beta: float = 1.5) -> float:
    """Calculate Model Intelligence from context utilization.

    MI = max(0, 1 - u^beta)

    Args:
        utilization: Context utilization ratio (current_used / context_window_size)
        beta: Curve shape parameter (model-specific)

    Returns:
        MI value in [0, 1]
    """
    if utilization <= 0:
        return 1.0
    return max(0.0, 1.0 - utilization**beta)


def calculate_intelligence(
    current: StateEntry,
    context_window_size: int,
    model_id: str = "",
    beta_override: float = 0.0,
) -> IntelligenceScore:
    """Calculate Model Intelligence score.

    Args:
        current: Current state entry
        context_window_size: Total context window size in tokens
        model_id: Model identifier for profile lookup
        beta_override: If > 0, overrides model profile beta

    Returns:
        IntelligenceScore with MI and utilization
    """
    # Guard clause: unknown context window
    if context_window_size == 0:
        return IntelligenceScore(mi=1.0, utilization=0.0)

    beta_from_profile = get_model_profile(model_id or current.model_id)
    beta = beta_override if beta_override > 0 else beta_from_profile

    utilization = current.current_used_tokens / context_window_size
    mi = calculate_context_pressure(utilization, beta)

    return IntelligenceScore(mi=mi, utilization=utilization)


def get_mi_color(mi: float, utilization: float = 0.0) -> str:
    """Get color name for MI score considering both MI and context utilization.

    Rules:
      - Green: MI >= 0.90
      - Yellow: MI < 0.90 and > 0.80, OR context 40%-80%
      - Red: MI <= 0.80, OR context > 80%

    Args:
        mi: MI score value
        utilization: Context utilization ratio (0-1)

    Returns:
        Color name: "green", "yellow", or "red"
    """
    # Red: MI critically low or context nearly full
    if mi <= MI_YELLOW_THRESHOLD or utilization >= MI_CONTEXT_RED_THRESHOLD:
        return "red"
    # Yellow: MI degrading or context in warning zone
    if mi < MI_GREEN_THRESHOLD or utilization >= MI_CONTEXT_YELLOW_THRESHOLD:
        return "yellow"
    return "green"


def format_mi_score(mi: float) -> str:
    """Format MI score for display.

    Args:
        mi: MI score value

    Returns:
        Formatted string like "0.823"
    """
    return f"{mi:.3f}"
