"""Tests for rotating waiting text and activity detection."""

import time

from claude_statusline.core.state import StateEntry
from claude_statusline.ui.waiting import (
    STATIC_MESSAGE,
    WAITING_MESSAGES,
    get_waiting_text,
    is_active,
)


def _make_entry(timestamp: int = 0) -> StateEntry:
    """Helper to create a StateEntry for testing."""
    return StateEntry(
        timestamp=timestamp,
        total_input_tokens=1000,
        total_output_tokens=0,
        current_input_tokens=1000,
        current_output_tokens=0,
        cache_creation=0,
        cache_read=0,
        cost_usd=0.0,
        lines_added=0,
        lines_removed=0,
        session_id="test",
        model_id="test-model",
        workspace_project_dir="/tmp/test",
        context_window_size=200_000,
    )


class TestGetWaitingText:
    """Tests for rotating waiting text."""

    def test_returns_string(self):
        text = get_waiting_text(0)
        assert isinstance(text, str)
        assert len(text) > 0

    def test_rotates_every_two_cycles(self):
        """Messages should change every 2 cycles."""
        text_0 = get_waiting_text(0)
        text_1 = get_waiting_text(1)
        text_2 = get_waiting_text(2)

        # Cycle 0 and 1 should be the same (same message index)
        assert text_0 == text_1
        # Cycle 2 should be different (next message)
        assert text_0 != text_2

    def test_wraps_around(self):
        """Should cycle back to the first message."""
        total_messages = len(WAITING_MESSAGES)
        # After going through all messages (2 cycles each), should wrap
        first = get_waiting_text(0)
        wrapped = get_waiting_text(total_messages * 2)
        assert first == wrapped

    def test_all_messages_reachable(self):
        """Every message should appear at some cycle."""
        seen = set()
        for i in range(len(WAITING_MESSAGES) * 2):
            seen.add(get_waiting_text(i))
        assert seen == set(WAITING_MESSAGES)

    def test_reduced_motion_returns_static(self):
        """With reduced_motion=True, always return static message."""
        for i in range(10):
            text = get_waiting_text(i, reduced_motion=True)
            assert text == STATIC_MESSAGE

    def test_reduced_motion_consistent(self):
        """Static message should be the same regardless of cycle."""
        texts = {get_waiting_text(i, reduced_motion=True) for i in range(20)}
        assert len(texts) == 1


class TestIsActive:
    """Tests for session activity detection."""

    def test_empty_entries(self):
        assert is_active([]) is False

    def test_recent_entry_is_active(self):
        """Entry within timeout is active."""
        entry = _make_entry(timestamp=int(time.time()) - 5)
        assert is_active([entry]) is True

    def test_old_entry_is_not_active(self):
        """Entry older than timeout is not active."""
        entry = _make_entry(timestamp=int(time.time()) - 60)
        assert is_active([entry]) is False

    def test_exactly_at_timeout_is_active(self):
        """Entry exactly at timeout boundary is still active."""
        entry = _make_entry(timestamp=int(time.time()) - 30)
        assert is_active([entry], timeout=30) is True

    def test_just_past_timeout_is_not_active(self):
        """Entry just past timeout boundary is not active."""
        entry = _make_entry(timestamp=int(time.time()) - 31)
        assert is_active([entry], timeout=30) is False

    def test_custom_timeout(self):
        """Custom timeout should be respected."""
        entry = _make_entry(timestamp=int(time.time()) - 10)
        assert is_active([entry], timeout=5) is False
        assert is_active([entry], timeout=15) is True

    def test_uses_last_entry(self):
        """Should check the most recent (last) entry, not the first."""
        old_entry = _make_entry(timestamp=int(time.time()) - 120)
        recent_entry = _make_entry(timestamp=int(time.time()) - 5)
        assert is_active([old_entry, recent_entry]) is True

    def test_old_entries_with_recent_last(self):
        """Multiple old entries don't matter if last one is recent."""
        now = int(time.time())
        entries = [
            _make_entry(timestamp=now - 300),
            _make_entry(timestamp=now - 200),
            _make_entry(timestamp=now - 100),
            _make_entry(timestamp=now - 2),
        ]
        assert is_active(entries) is True
