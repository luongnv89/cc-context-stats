"""Tests for Model Intelligence (MI) score computation."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from claude_statusline.core.state import StateEntry
from claude_statusline.graphs.intelligence import (
    MI_GREEN_THRESHOLD,
    MI_YELLOW_THRESHOLD,
    MODEL_PROFILES,
    calculate_context_pressure,
    calculate_intelligence,
    format_mi_score,
    get_mi_color,
    get_model_profile,
)

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"


def _make_entry(
    current_input=0,
    cache_creation=0,
    cache_read=0,
    total_output=0,
    lines_added=0,
    lines_removed=0,
    context_window_size=200000,
    model_id="test-model",
) -> StateEntry:
    """Helper to create a StateEntry with sane defaults."""
    return StateEntry(
        timestamp=1000000,
        total_input_tokens=0,
        total_output_tokens=total_output,
        current_input_tokens=current_input,
        current_output_tokens=0,
        cache_creation=cache_creation,
        cache_read=cache_read,
        cost_usd=0.0,
        lines_added=lines_added,
        lines_removed=lines_removed,
        session_id="test",
        model_id=model_id,
        workspace_project_dir="/test",
        context_window_size=context_window_size,
    )


# --- Model profile tests ---


class TestModelProfile:
    def test_opus_detected(self):
        assert get_model_profile("claude-opus-4-6[1m]") == MODEL_PROFILES["opus"]

    def test_sonnet_detected(self):
        assert get_model_profile("claude-sonnet-4-6") == MODEL_PROFILES["sonnet"]

    def test_haiku_detected(self):
        assert get_model_profile("claude-haiku-4-5-20251001") == MODEL_PROFILES["haiku"]

    def test_unknown_falls_back_to_default(self):
        assert get_model_profile("unknown-model-xyz") == MODEL_PROFILES["default"]

    def test_case_insensitive(self):
        assert get_model_profile("Claude-OPUS-4-6") == MODEL_PROFILES["opus"]

    def test_empty_string_returns_default(self):
        assert get_model_profile("") == MODEL_PROFILES["default"]

    def test_all_profiles_are_positive(self):
        for name, beta in MODEL_PROFILES.items():
            assert beta > 0, f"Profile {name} beta must be positive"

    def test_opus_retains_quality_longest(self):
        """Higher beta = quality retained longer. Opus should have highest beta."""
        assert MODEL_PROFILES["opus"] > MODEL_PROFILES["sonnet"]
        assert MODEL_PROFILES["sonnet"] > MODEL_PROFILES["haiku"]


# --- MI formula tests ---


class TestContextPressure:
    def test_empty_context(self):
        assert calculate_context_pressure(0.0) == 1.0

    def test_full_context(self):
        # MI = 1 - 1^beta = 0 for any beta
        assert calculate_context_pressure(1.0) == 0.0

    def test_half_context_default(self):
        mi = calculate_context_pressure(0.5)
        assert 0.64 < mi < 0.66  # 1 - 0.5^1.5 ≈ 0.646

    def test_custom_beta_linear(self):
        mi = calculate_context_pressure(0.5, beta=1.0)
        assert mi == pytest.approx(0.5, abs=0.01)

    def test_custom_beta_quadratic(self):
        mi = calculate_context_pressure(0.5, beta=2.0)
        assert mi == pytest.approx(0.75, abs=0.01)

    def test_over_capacity_clamped(self):
        mi = calculate_context_pressure(1.5)
        assert mi == 0.0

    def test_negative_utilization(self):
        assert calculate_context_pressure(-0.1) == 1.0


# --- Guard clause ---


class TestGuardClause:
    def test_zero_context_window(self):
        entry = _make_entry(current_input=50000)
        score = calculate_intelligence(entry, context_window_size=0)
        assert score.mi == 1.0
        assert score.utilization == 0.0


# --- Composite MI tests ---


class TestComposite:
    def test_fresh_opus_session(self):
        cur = _make_entry(current_input=10000, model_id="claude-opus-4-6")
        score = calculate_intelligence(cur, 200000, "claude-opus-4-6")
        assert score.mi > 0.98

    def test_full_context_always_zero(self):
        """All models reach MI=0.0 at full context (alpha=1.0 for all)."""
        for model in ["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5"]:
            cur = _make_entry(current_input=200000, model_id=model)
            score = calculate_intelligence(cur, 200000, model)
            assert score.mi == 0.0, f"{model} at full context should be 0.0"

    def test_opus_retains_longer_than_sonnet(self):
        """Opus should have higher MI than sonnet at same utilization."""
        cur_o = _make_entry(current_input=100000, model_id="claude-opus-4-6")
        cur_s = _make_entry(current_input=100000, model_id="claude-sonnet-4-6")
        o = calculate_intelligence(cur_o, 200000, "claude-opus-4-6")
        s = calculate_intelligence(cur_s, 200000, "claude-sonnet-4-6")
        assert o.mi > s.mi

    def test_beta_override(self):
        cur = _make_entry(current_input=100000, model_id="claude-opus-4-6")
        score = calculate_intelligence(cur, 200000, "claude-opus-4-6", beta_override=1.0)
        # MI = 1 - 0.5^1.0 = 0.5
        assert score.mi == pytest.approx(0.5, abs=0.01)

    def test_bounds(self):
        """MI should always be in [0, 1]."""
        for u in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]:
            used = int(u * 200000)
            cur = _make_entry(current_input=used)
            score = calculate_intelligence(cur, 200000, "claude-sonnet-4-6")
            assert 0.0 <= score.mi <= 1.0, f"MI out of bounds at u={u}: {score.mi}"

    def test_uses_entry_model_id_if_not_provided(self):
        cur = _make_entry(current_input=100000, model_id="claude-opus-4-6")
        score = calculate_intelligence(cur, 200000)
        opus_expected = calculate_intelligence(cur, 200000, "claude-opus-4-6")
        assert score.mi == pytest.approx(opus_expected.mi, abs=0.001)


# --- Color tests ---


class TestColor:
    def test_green(self):
        assert get_mi_color(0.8) == "green"

    def test_yellow(self):
        assert get_mi_color(0.5) == "yellow"

    def test_red(self):
        assert get_mi_color(0.2) == "red"

    def test_boundary_green(self):
        assert get_mi_color(MI_GREEN_THRESHOLD + 0.001) == "green"

    def test_boundary_yellow_upper(self):
        assert get_mi_color(MI_GREEN_THRESHOLD) == "yellow"

    def test_boundary_yellow_lower(self):
        assert get_mi_color(MI_YELLOW_THRESHOLD + 0.001) == "yellow"

    def test_boundary_red(self):
        assert get_mi_color(MI_YELLOW_THRESHOLD) == "red"


# --- Format tests ---


class TestFormat:
    def test_three_decimals(self):
        assert format_mi_score(0.823) == "0.823"

    def test_zero(self):
        assert format_mi_score(0.0) == "0.000"

    def test_one(self):
        assert format_mi_score(1.0) == "1.000"

    def test_rounding(self):
        assert format_mi_score(0.82449) == "0.824"
        assert format_mi_score(0.82451) == "0.825"


# --- Shared test vectors ---


class TestSharedVectors:
    """Test against shared vectors for cross-implementation parity."""

    @pytest.fixture
    def vectors(self):
        with open(FIXTURES_DIR / "mi_test_vectors.json") as f:
            return json.load(f)

    def test_all_vectors(self, vectors):
        for vec in vectors:
            inp = vec["input"]
            exp = vec["expected"]

            cur = _make_entry(
                current_input=inp["current_used"],
                model_id=inp["model_id"],
                context_window_size=inp["context_window"],
            )

            beta_override = inp["beta_override"] if inp["beta_override"] is not None else 0.0

            score = calculate_intelligence(
                cur, inp["context_window"], inp["model_id"], beta_override
            )

            assert score.mi == pytest.approx(exp["mi"], abs=0.01), (
                f"MI mismatch for '{vec['description']}': "
                f"got {score.mi:.4f}, expected {exp['mi']}"
            )
            assert score.utilization == pytest.approx(exp["utilization"], abs=0.01), (
                f"Utilization mismatch for '{vec['description']}': "
                f"got {score.utilization:.4f}, expected {exp['utilization']}"
            )
