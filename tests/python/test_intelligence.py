"""Tests for Model Intelligence (MI) score computation."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from claude_statusline.core.state import StateEntry
from claude_statusline.graphs.intelligence import (
    MI_GREEN_THRESHOLD,
    MI_WEIGHT_CPS,
    MI_WEIGHT_ES,
    MI_WEIGHT_PS,
    MI_YELLOW_THRESHOLD,
    IntelligenceScore,
    calculate_context_pressure,
    calculate_efficiency,
    calculate_intelligence,
    calculate_productivity,
    format_mi_score,
    get_mi_color,
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
        model_id="test-model",
        workspace_project_dir="/test",
        context_window_size=context_window_size,
    )


# --- CPS tests ---


class TestContextPressure:
    def test_empty_context(self):
        assert calculate_context_pressure(0.0) == 1.0

    def test_full_context(self):
        assert calculate_context_pressure(1.0) == 0.0

    def test_half_context(self):
        cps = calculate_context_pressure(0.5)
        assert 0.64 < cps < 0.66  # ~0.646

    def test_custom_beta_linear(self):
        cps = calculate_context_pressure(0.5, beta=1.0)
        assert cps == pytest.approx(0.5, abs=0.01)

    def test_custom_beta_quadratic(self):
        cps = calculate_context_pressure(0.5, beta=2.0)
        assert cps == pytest.approx(0.75, abs=0.01)

    def test_over_capacity_clamped(self):
        cps = calculate_context_pressure(1.5)
        assert cps == 0.0

    def test_negative_utilization(self):
        assert calculate_context_pressure(-0.1) == 1.0


# --- CPS guard clause ---


class TestGuardClause:
    def test_zero_context_window(self):
        entry = _make_entry(current_input=50000)
        score = calculate_intelligence(entry, None, context_window_size=0)
        assert score.mi == 1.0
        assert score.cps == 1.0
        assert score.es == 1.0
        assert score.ps == 0.5
        assert score.utilization == 0.0


# --- ES tests ---


class TestEfficiency:
    def test_no_tokens(self):
        entry = _make_entry()
        assert calculate_efficiency(entry) == 1.0

    def test_all_cache_read(self):
        entry = _make_entry(cache_read=100000)
        assert calculate_efficiency(entry) == 1.0

    def test_no_cache(self):
        entry = _make_entry(current_input=100000)
        assert calculate_efficiency(entry) == pytest.approx(0.3, abs=0.01)

    def test_mixed_cache(self):
        # 60% cache read
        entry = _make_entry(current_input=20000, cache_creation=20000, cache_read=60000)
        es = calculate_efficiency(entry)
        assert es == pytest.approx(0.3 + 0.7 * 0.6, abs=0.01)


# --- PS tests ---


class TestProductivity:
    def test_no_previous_entry(self):
        entry = _make_entry(total_output=1000, lines_added=100)
        assert calculate_productivity(entry, None) == 0.5

    def test_no_output(self):
        prev = _make_entry(total_output=1000)
        cur = _make_entry(total_output=1000)  # no increase
        assert calculate_productivity(cur, prev) == 0.5

    def test_high_productivity(self):
        prev = _make_entry(total_output=0, lines_added=0, lines_removed=0)
        cur = _make_entry(total_output=100, lines_added=20, lines_removed=5)
        ps = calculate_productivity(cur, prev)
        # ratio = 25/100 = 0.25, normalized = min(1, 0.25/0.2) = 1.0
        assert ps == pytest.approx(1.0, abs=0.01)

    def test_zero_productivity(self):
        prev = _make_entry(total_output=0, lines_added=0, lines_removed=0)
        cur = _make_entry(total_output=1000, lines_added=0, lines_removed=0)
        ps = calculate_productivity(cur, prev)
        assert ps == pytest.approx(0.2, abs=0.01)

    def test_moderate_productivity(self):
        prev = _make_entry(total_output=0, lines_added=0, lines_removed=0)
        cur = _make_entry(total_output=1000, lines_added=50, lines_removed=10)
        ps = calculate_productivity(cur, prev)
        # ratio = 60/1000 = 0.06, normalized = min(1, 0.06/0.2) = 0.3
        assert ps == pytest.approx(0.2 + 0.8 * 0.3, abs=0.01)

    def test_capping(self):
        prev = _make_entry(total_output=0, lines_added=0, lines_removed=0)
        cur = _make_entry(total_output=10, lines_added=100, lines_removed=100)
        ps = calculate_productivity(cur, prev)
        # ratio = 200/10 = 20, normalized = min(1, 20/0.2) = 1.0
        assert ps == pytest.approx(1.0, abs=0.01)

    def test_consecutive_diffs(self):
        """Verify PS uses consecutive entry diffs, not cumulative totals."""
        prev = _make_entry(total_output=500, lines_added=50, lines_removed=10)
        cur = _make_entry(total_output=600, lines_added=55, lines_removed=12)
        ps = calculate_productivity(cur, prev)
        # delta_lines = (55-50) + (12-10) = 7, delta_output = 100
        # ratio = 7/100 = 0.07, normalized = 0.07/0.2 = 0.35
        assert ps == pytest.approx(0.2 + 0.8 * 0.35, abs=0.01)


# --- Composite tests ---


class TestComposite:
    def test_optimal_conditions(self):
        prev = _make_entry(total_output=0, lines_added=0, lines_removed=0)
        cur = _make_entry(
            current_input=1000, cache_read=9000, total_output=100,
            lines_added=25, lines_removed=5,
        )
        score = calculate_intelligence(cur, prev, 200000)
        assert score.mi > 0.9

    def test_worst_conditions(self):
        prev = _make_entry(total_output=0, lines_added=0, lines_removed=0)
        cur = _make_entry(
            current_input=200000, total_output=10000,
            lines_added=0, lines_removed=0,
        )
        score = calculate_intelligence(cur, prev, 200000)
        assert score.mi < 0.2

    def test_weight_sum(self):
        assert MI_WEIGHT_CPS + MI_WEIGHT_ES + MI_WEIGHT_PS == pytest.approx(1.0)

    def test_bounds(self):
        """MI should always be in [0, 1]."""
        prev = _make_entry(total_output=0)
        for u in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]:
            used = int(u * 200000)
            cur = _make_entry(current_input=used, total_output=1000, lines_added=50)
            score = calculate_intelligence(cur, prev, 200000)
            assert 0.0 <= score.mi <= 1.0, f"MI out of bounds at u={u}: {score.mi}"


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
    def test_two_decimals(self):
        assert format_mi_score(0.82) == "0.82"

    def test_zero(self):
        assert format_mi_score(0.0) == "0.00"

    def test_one(self):
        assert format_mi_score(1.0) == "1.00"

    def test_rounding(self):
        assert format_mi_score(0.8249) == "0.82"
        assert format_mi_score(0.8251) == "0.83"


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

            # Build entries from vector input
            current_input = inp["current_input"]
            cache_creation = inp["cache_creation"]
            cache_read = inp["cache_read"]
            # current_used should equal current_input + cache_creation + cache_read
            # but we trust the vector's current_used for the entry construction
            cur = _make_entry(
                current_input=current_input,
                cache_creation=cache_creation,
                cache_read=cache_read,
                total_output=inp["cur_output"],
                lines_added=inp["cur_lines_added"],
                lines_removed=inp["cur_lines_removed"],
                context_window_size=inp["context_window"],
            )

            has_prev = inp["prev_output"] is not None
            if has_prev:
                prev = _make_entry(
                    total_output=inp["prev_output"],
                    lines_added=inp["prev_lines_added"],
                    lines_removed=inp["prev_lines_removed"],
                )
            else:
                prev = None

            score = calculate_intelligence(
                cur, prev, inp["context_window"], inp["beta"]
            )

            assert score.cps == pytest.approx(exp["cps"], abs=0.01), (
                f"CPS mismatch for '{vec['description']}': "
                f"got {score.cps}, expected {exp['cps']}"
            )
            assert score.es == pytest.approx(exp["es"], abs=0.01), (
                f"ES mismatch for '{vec['description']}': "
                f"got {score.es}, expected {exp['es']}"
            )
            assert score.ps == pytest.approx(exp["ps"], abs=0.01), (
                f"PS mismatch for '{vec['description']}': "
                f"got {score.ps}, expected {exp['ps']}"
            )
            assert score.mi == pytest.approx(exp["mi"], abs=0.01), (
                f"MI mismatch for '{vec['description']}': "
                f"got {score.mi}, expected {exp['mi']}"
            )
