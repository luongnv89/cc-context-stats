"""Tests that MI always reflects context length: more free context = better MI.

This suite verifies the monotonicity property across all sub-scores and the
composite MI value, under varying ES/PS conditions and beta parameters.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from claude_statusline.core.state import StateEntry
from claude_statusline.graphs.intelligence import (
    MI_GREEN_THRESHOLD,
    MI_YELLOW_THRESHOLD,
    calculate_context_pressure,
    calculate_intelligence,
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


@pytest.fixture
def vectors():
    with open(FIXTURES_DIR / "mi_monotonicity_vectors.json") as f:
        return json.load(f)


# --- CPS monotonicity ---


class TestCPSMonotonicity:
    """CPS must strictly decrease as utilization increases."""

    def test_cps_decreases_with_utilization(self, vectors):
        """As context fills up, CPS must monotonically decrease."""
        steps = vectors["utilization_steps"]
        beta = vectors["beta"]
        cw = vectors["context_window"]

        prev_cps = None
        for step in steps:
            u = step["used"] / cw
            cps = calculate_context_pressure(u, beta)
            if prev_cps is not None:
                assert cps <= prev_cps, (
                    f"CPS must decrease as context fills: "
                    f"at {step['pct']}% (CPS={cps:.4f}) > "
                    f"previous (CPS={prev_cps:.4f})"
                )
            prev_cps = cps

    def test_cps_strictly_decreases_for_nonzero_steps(self, vectors):
        """CPS must strictly decrease between non-zero utilization steps."""
        steps = vectors["utilization_steps"]
        beta = vectors["beta"]
        cw = vectors["context_window"]

        # Skip the 0% step since CPS(0)=1.0 by definition
        nonzero_steps = [s for s in steps if s["used"] > 0]
        prev_cps = None
        for step in nonzero_steps:
            u = step["used"] / cw
            cps = calculate_context_pressure(u, beta)
            if prev_cps is not None:
                assert cps < prev_cps, (
                    f"CPS must strictly decrease between non-zero utilizations: "
                    f"at {step['pct']}% (CPS={cps:.4f}) >= "
                    f"previous (CPS={prev_cps:.4f})"
                )
            prev_cps = cps

    @pytest.mark.parametrize("beta", [1.0, 1.5, 2.0, 3.0])
    def test_cps_monotonic_for_all_beta(self, beta):
        """CPS monotonicity holds for any valid beta value."""
        prev_cps = None
        for pct in range(0, 101, 5):
            u = pct / 100.0
            cps = calculate_context_pressure(u, beta)
            if prev_cps is not None:
                assert cps <= prev_cps, (
                    f"CPS not monotonic at {pct}% with beta={beta}: "
                    f"{cps:.4f} > {prev_cps:.4f}"
                )
            prev_cps = cps

    def test_cps_boundary_values(self):
        """CPS=1.0 at 0% and CPS=0.0 at 100%."""
        assert calculate_context_pressure(0.0) == 1.0
        assert calculate_context_pressure(1.0) == 0.0


# --- Composite MI monotonicity ---


class TestMIMonotonicity:
    """MI must decrease as context fills, when ES and PS are held constant."""

    def test_mi_decreases_with_utilization_no_cache_no_prev(self, vectors):
        """MI monotonically decreases as context fills (baseline: no cache, no prev)."""
        steps = vectors["utilization_steps"]
        cw = vectors["context_window"]

        prev_mi = None
        for step in steps:
            used = step["used"]
            # No cache, no previous entry => ES=0.3, PS=0.5 (constants)
            cur = _make_entry(current_input=used)
            score = calculate_intelligence(cur, None, cw)

            if prev_mi is not None:
                assert score.mi <= prev_mi + 1e-9, (
                    f"MI must decrease with utilization: "
                    f"at {step['pct']}% (MI={score.mi:.4f}) > "
                    f"previous (MI={prev_mi:.4f})"
                )
            prev_mi = score.mi

    def test_mi_decreases_with_utilization_high_cache(self, vectors):
        """MI monotonically decreases even with high cache efficiency."""
        steps = vectors["utilization_steps"]
        cw = vectors["context_window"]

        prev_mi = None
        for step in steps:
            used = step["used"]
            # 80% of used tokens are from cache reads
            cache_read = int(used * 0.8)
            current_input = used - cache_read
            cur = _make_entry(current_input=current_input, cache_read=cache_read)
            score = calculate_intelligence(cur, None, cw)

            if prev_mi is not None:
                assert score.mi <= prev_mi + 1e-9, (
                    f"MI must decrease with utilization (high cache): "
                    f"at {step['pct']}% (MI={score.mi:.4f}) > "
                    f"previous (MI={prev_mi:.4f})"
                )
            prev_mi = score.mi

    def test_mi_decreases_with_utilization_with_productivity(self, vectors):
        """MI monotonically decreases even with high productivity."""
        steps = vectors["utilization_steps"]
        cw = vectors["context_window"]

        prev_entry = _make_entry(total_output=0, lines_added=0, lines_removed=0)

        prev_mi = None
        for step in steps:
            used = step["used"]
            cur = _make_entry(
                current_input=used,
                total_output=1000,
                lines_added=100,
                lines_removed=20,
            )
            score = calculate_intelligence(cur, prev_entry, cw)

            if prev_mi is not None:
                assert score.mi <= prev_mi + 1e-9, (
                    f"MI must decrease with utilization (with productivity): "
                    f"at {step['pct']}% (MI={score.mi:.4f}) > "
                    f"previous (MI={prev_mi:.4f})"
                )
            prev_mi = score.mi

    def test_mi_decreases_across_all_scenarios(self, vectors):
        """MI monotonically decreases for every ES/PS scenario in the fixture."""
        steps = vectors["utilization_steps"]
        cw = vectors["context_window"]

        for scenario in vectors["varying_es_ps_scenarios"]:
            prev_mi = None
            cache_ratio = scenario["cache_read_ratio"]
            dl = scenario["delta_lines"]
            do = scenario["delta_output"]

            for step in steps:
                used = step["used"]
                cache_read = int(used * cache_ratio)
                current_input = used - cache_read

                cur = _make_entry(
                    current_input=current_input,
                    cache_read=cache_read,
                    total_output=do if do else 0,
                    lines_added=dl,
                    lines_removed=0,
                )
                prev = _make_entry(total_output=0, lines_added=0, lines_removed=0)

                score = calculate_intelligence(cur, prev, cw)

                if prev_mi is not None:
                    assert score.mi <= prev_mi + 1e-9, (
                        f"MI not monotonic in scenario '{scenario['description']}' "
                        f"at {step['pct']}%: MI={score.mi:.4f} > prev={prev_mi:.4f}"
                    )
                prev_mi = score.mi

    @pytest.mark.parametrize("beta", [1.0, 1.5, 2.0, 3.0])
    def test_mi_decreases_for_all_beta(self, beta):
        """MI monotonically decreases for any valid beta value."""
        cw = 200000
        prev_mi = None

        for pct in range(0, 101, 5):
            used = int(pct / 100.0 * cw)
            cur = _make_entry(current_input=used)
            score = calculate_intelligence(cur, None, cw, beta=beta)

            if prev_mi is not None:
                assert score.mi <= prev_mi + 1e-9, (
                    f"MI not monotonic at {pct}% with beta={beta}: "
                    f"{score.mi:.4f} > {prev_mi:.4f}"
                )
            prev_mi = score.mi


# --- Fine-grained resolution: MI at 1% increments ---


class TestMIFineGrained:
    """MI monotonicity at 1% resolution to catch subtle non-monotonic kinks."""

    def test_mi_monotonic_at_1pct_resolution(self):
        """MI must not increase at any 1% step from 0% to 100%."""
        cw = 200000
        prev_mi = None

        for pct in range(0, 101):
            used = int(pct / 100.0 * cw)
            cur = _make_entry(current_input=used)
            score = calculate_intelligence(cur, None, cw)

            if prev_mi is not None:
                assert score.mi <= prev_mi + 1e-9, (
                    f"MI increased at {pct}%: {score.mi:.6f} > {prev_mi:.6f}"
                )
            prev_mi = score.mi

    def test_cps_monotonic_at_1pct_resolution(self):
        """CPS must not increase at any 1% step from 0% to 100%."""
        prev_cps = None

        for pct in range(0, 101):
            u = pct / 100.0
            cps = calculate_context_pressure(u)

            if prev_cps is not None:
                assert cps <= prev_cps + 1e-9, (
                    f"CPS increased at {pct}%: {cps:.6f} > {prev_cps:.6f}"
                )
            prev_cps = cps


# --- MI reflects context zones ---


class TestMIReflectsZones:
    """MI values should align with context zone semantics."""

    def test_smart_zone_has_higher_mi_than_dumb_zone(self):
        """MI at 20% (smart zone) must be higher than MI at 60% (dumb zone)."""
        cw = 200000
        smart = _make_entry(current_input=int(0.20 * cw))
        dumb = _make_entry(current_input=int(0.60 * cw))

        s_score = calculate_intelligence(smart, None, cw)
        d_score = calculate_intelligence(dumb, None, cw)

        assert s_score.mi > d_score.mi, (
            f"Smart zone MI ({s_score.mi:.4f}) should be > "
            f"dumb zone MI ({d_score.mi:.4f})"
        )

    def test_dumb_zone_has_higher_mi_than_wrap_up_zone(self):
        """MI at 60% (dumb zone) must be higher than MI at 90% (wrap up zone)."""
        cw = 200000
        dumb = _make_entry(current_input=int(0.60 * cw))
        wrap = _make_entry(current_input=int(0.90 * cw))

        d_score = calculate_intelligence(dumb, None, cw)
        w_score = calculate_intelligence(wrap, None, cw)

        assert d_score.mi > w_score.mi, (
            f"Dumb zone MI ({d_score.mi:.4f}) should be > "
            f"wrap up zone MI ({w_score.mi:.4f})"
        )

    def test_empty_context_has_highest_mi(self):
        """MI at 0% utilization must be the maximum possible MI."""
        cw = 200000
        empty = _make_entry(current_input=0)
        score = calculate_intelligence(empty, None, cw)

        # With 0 used tokens: total_context=0 => ES=1.0, no prev => PS=0.5
        # MI = 0.60*1.0 + 0.25*1.0 + 0.15*0.5 = 0.60 + 0.25 + 0.075 = 0.925
        assert score.mi == pytest.approx(0.925, abs=0.01)
        assert score.cps == 1.0

    def test_full_context_has_lowest_mi(self):
        """MI at 100% utilization must be the minimum possible MI."""
        cw = 200000
        full = _make_entry(current_input=cw)
        score = calculate_intelligence(full, None, cw)

        # CPS=0.0, current_used=200000 (all from current_input), no cache => ES=0.3, PS=0.5
        # MI = 0.60*0.0 + 0.25*0.3 + 0.15*0.5 = 0 + 0.075 + 0.075 = 0.15
        assert score.mi == pytest.approx(0.15, abs=0.01)
        assert score.cps == 0.0

    def test_mi_spread_covers_meaningful_range(self):
        """The MI range from 0% to 100% should span at least 0.5."""
        cw = 200000
        empty = _make_entry(current_input=0)
        full = _make_entry(current_input=cw)

        mi_empty = calculate_intelligence(empty, None, cw).mi
        mi_full = calculate_intelligence(full, None, cw).mi

        spread = mi_empty - mi_full
        assert spread >= 0.5, (
            f"MI spread too small: {mi_empty:.4f} - {mi_full:.4f} = {spread:.4f} < 0.5"
        )


# --- MI sensitivity to context ---


class TestMISensitivity:
    """CPS dominates MI (60% weight), so context pressure is always the primary signal."""

    def test_cps_weight_is_dominant(self):
        """CPS weight (0.60) must be the largest of all weights."""
        from claude_statusline.graphs.intelligence import (
            MI_WEIGHT_CPS,
            MI_WEIGHT_ES,
            MI_WEIGHT_PS,
        )

        assert MI_WEIGHT_CPS > MI_WEIGHT_ES
        assert MI_WEIGHT_CPS > MI_WEIGHT_PS
        assert MI_WEIGHT_CPS >= 0.5, "CPS should be at least half the MI weight"

    def test_worst_es_ps_still_monotonic(self):
        """Even with worst-case ES and PS, MI must still decrease with utilization."""
        cw = 200000
        # Worst case: no cache (ES=0.3), zero productivity (PS=0.2)
        prev = _make_entry(total_output=0, lines_added=0, lines_removed=0)

        prev_mi = None
        for pct in range(0, 101, 5):
            used = int(pct / 100.0 * cw)
            cur = _make_entry(
                current_input=used,
                total_output=1000,
                lines_added=0,
                lines_removed=0,
            )
            score = calculate_intelligence(cur, prev, cw)

            if prev_mi is not None:
                assert score.mi <= prev_mi + 1e-9, (
                    f"MI not monotonic at {pct}% (worst ES/PS): "
                    f"{score.mi:.4f} > {prev_mi:.4f}"
                )
            prev_mi = score.mi

    def test_best_es_ps_still_monotonic(self):
        """Even with best-case ES and PS, MI must still decrease with utilization."""
        cw = 200000
        prev = _make_entry(total_output=0, lines_added=0, lines_removed=0)

        prev_mi = None
        for pct in range(0, 101, 5):
            used = int(pct / 100.0 * cw)
            # Best case: all cache (ES=1.0) and super productive (PS=1.0)
            cur = _make_entry(
                current_input=0,
                cache_read=used,
                total_output=100,
                lines_added=50,
                lines_removed=10,
            )
            score = calculate_intelligence(cur, prev, cw)

            if prev_mi is not None:
                assert score.mi <= prev_mi + 1e-9, (
                    f"MI not monotonic at {pct}% (best ES/PS): "
                    f"{score.mi:.4f} > {prev_mi:.4f}"
                )
            prev_mi = score.mi
