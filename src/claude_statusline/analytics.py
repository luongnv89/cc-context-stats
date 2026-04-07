"""Data loading and aggregation for token usage analytics.

This module provides utilities to:
- Load session state files from ~/.claude/statusline/
- Aggregate token usage by project
- Filter sessions by date range
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path

from claude_statusline.core.state import StateEntry, StateFile


@dataclass
class SubagentStats:
    """Statistics for a single subagent across sessions."""

    agent_id: str
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    total_cache_creation: int = 0
    total_cache_read: int = 0
    session_count: int = 0


@dataclass
class SessionStats:
    """Statistics for a single session."""

    session_id: str
    project_dir: str
    model_id: str
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    total_cache_creation: int = 0
    total_cache_read: int = 0
    cost_usd: float = 0.0
    start_time: int = 0
    end_time: int = 0
    entry_count: int = 0
    subagents: dict[str, SubagentStats] = field(default_factory=dict)

    def total_tokens(self) -> int:
        """Total tokens (input + output + cache)."""
        return (
            self.total_input_tokens
            + self.total_output_tokens
            + self.total_cache_creation
            + self.total_cache_read
        )


@dataclass
class ProjectStats:
    """Aggregated statistics for a project."""

    project_dir: str
    total_input_tokens: int = 0
    total_output_tokens: int = 0
    total_cache_creation: int = 0
    total_cache_read: int = 0
    cost_usd: float = 0.0
    session_count: int = 0
    sessions: list[SessionStats] = field(default_factory=list)
    subagents: dict[str, SubagentStats] = field(default_factory=dict)

    def total_tokens(self) -> int:
        """Total tokens (input + output + cache)."""
        return (
            self.total_input_tokens
            + self.total_output_tokens
            + self.total_cache_creation
            + self.total_cache_read
        )


def _discover_state_files() -> list[Path]:
    """Discover all state files in ~/.claude/statusline/.

    Returns:
        List of state file paths.
    """
    state_dir = StateFile.STATE_DIR
    if not state_dir.exists():
        return []

    state_files = []
    for file in state_dir.glob("statusline.*.state"):
        if file.is_file():
            state_files.append(file)
    return sorted(state_files)


def _load_session_stats(state_file_path: Path) -> SessionStats | None:
    """Load statistics for a single session from a state file.

    Args:
        state_file_path: Path to the state file.

    Returns:
        SessionStats object or None if unable to load.
    """
    entries = []
    try:
        with open(state_file_path) as f:
            for line in f:
                entry = StateEntry.from_csv_line(line)
                if entry:
                    entries.append(entry)
    except (OSError, ValueError):
        return None

    if not entries:
        return None

    # Extract session ID from filename (statusline.<session_id>.state)
    session_id = state_file_path.stem.replace("statusline.", "")

    # Get project_dir from the first entry's workspace_project_dir field
    project_dir = entries[0].workspace_project_dir or "Unknown"

    # Aggregate stats
    stats = SessionStats(
        session_id=session_id,
        project_dir=project_dir,
        model_id=entries[-1].model_id,
        start_time=entries[0].timestamp,
        end_time=entries[-1].timestamp,
        entry_count=len(entries),
    )

    # Use the final cumulative values
    final_entry = entries[-1]
    stats.total_input_tokens = final_entry.total_input_tokens
    stats.total_output_tokens = final_entry.total_output_tokens
    stats.total_cache_creation = final_entry.cache_creation
    stats.total_cache_read = final_entry.cache_read
    stats.cost_usd = final_entry.cost_usd

    return stats


def _group_sessions_by_project(
    sessions: list[SessionStats], since_days: int | None = None
) -> dict[str, ProjectStats]:
    """Group sessions by project directory.

    Args:
        sessions: List of SessionStats objects.
        since_days: Only include sessions from the last N days.

    Returns:
        Dictionary mapping project_dir to ProjectStats.
    """
    cutoff_time = None
    if since_days:
        cutoff_time = int((datetime.now() - timedelta(days=since_days)).timestamp())

    projects: dict[str, ProjectStats] = {}

    for session in sessions:
        # Apply date filter if specified
        if cutoff_time and session.end_time < cutoff_time:
            continue

        # Create project entry if needed
        if session.project_dir not in projects:
            projects[session.project_dir] = ProjectStats(project_dir=session.project_dir)

        proj = projects[session.project_dir]
        proj.total_input_tokens += session.total_input_tokens
        proj.total_output_tokens += session.total_output_tokens
        proj.total_cache_creation += session.total_cache_creation
        proj.total_cache_read += session.total_cache_read
        proj.cost_usd += session.cost_usd
        proj.session_count += 1
        proj.sessions.append(session)

    return projects


def load_all_projects(since_days: int | None = None) -> list[ProjectStats]:
    """Load statistics for all projects.

    Args:
        since_days: Only include sessions from the last N days.

    Returns:
        List of ProjectStats objects, sorted by total tokens (descending).
    """
    state_files = _discover_state_files()

    # Load all sessions from state files
    sessions = []
    for state_file in state_files:
        session = _load_session_stats(state_file)
        if session:
            sessions.append(session)

    # Group sessions by project and apply date filtering
    projects_dict = _group_sessions_by_project(sessions, since_days)

    # Convert to sorted list
    all_stats = list(projects_dict.values())
    all_stats.sort(key=lambda s: s.total_tokens(), reverse=True)
    return all_stats
