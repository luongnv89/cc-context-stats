"""Data loading and aggregation for token usage analytics.

This module provides utilities to:
- Discover project directories in ~/.claude/projects/
- Load session state files and aggregate token usage
- Parse project metadata and subagent information
- Filter sessions by date range
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

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


def _discover_projects() -> list[Path]:
    """Discover all project directories in ~/.claude/projects/.

    Returns:
        List of project directory paths.
    """
    projects_dir = Path.home() / ".claude" / "projects"
    if not projects_dir.exists():
        return []

    projects = []
    for item in projects_dir.iterdir():
        if item.is_dir():
            projects.append(item)
    return sorted(projects)


def _decode_project_dir(encoded: str) -> str:
    """Decode project directory name.

    Project directories in ~/.claude/projects/ are encoded with underscores
    replacing path separators (e.g., /path/to/project → _path_to_project).

    Args:
        encoded: Encoded project directory name.

    Returns:
        Decoded project directory path.
    """
    # Remove leading underscore if present
    if encoded.startswith("_"):
        encoded = encoded[1:]
    # Replace remaining underscores with path separators
    return "/" + encoded.replace("_", "/")


def _load_session_stats(session_dir: Path, project_dir: str) -> Optional[SessionStats]:
    """Load statistics for a single session.

    Args:
        session_dir: Path to session directory (UUID).
        project_dir: Decoded project directory path.

    Returns:
        SessionStats object or None if no state file found.
    """
    # Find state file for this session (typically sessionid.state or similar)
    state_file = StateFile(session_dir.name)
    state_file.session_id = session_dir.name

    # Try to read from the session-specific state file
    # The StateFile uses a glob pattern internally, so we need to match it
    from claude_statusline.core.state import _validate_session_id

    try:
        _validate_session_id(session_dir.name)
    except ValueError:
        return None

    # Find the state file
    state_files = list(Path.home().glob(f".claude/statusline/statusline.{session_dir.name}.state"))
    if not state_files:
        return None

    state_file_path = state_files[0]
    entries = []
    try:
        with open(state_file_path) as f:
            for line in f:
                entry = StateEntry.from_csv_line(line)
                if entry:
                    entries.append(entry)
    except (IOError, ValueError):
        return None

    if not entries:
        return None

    # Aggregate stats
    stats = SessionStats(
        session_id=session_dir.name,
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

    # Load subagent data
    _load_subagents(session_dir, stats)

    return stats


def _load_subagents(session_dir: Path, stats: SessionStats) -> None:
    """Load subagent data for a session.

    Args:
        session_dir: Path to session directory.
        stats: SessionStats object to populate.
    """
    subagents_dir = session_dir / "subagents"
    if not subagents_dir.exists():
        return

    agent_data: dict[str, dict] = {}

    for jsonl_file in subagents_dir.glob("*.jsonl"):
        try:
            with open(jsonl_file) as f:
                for line in f:
                    try:
                        data = json.loads(line.strip())
                        agent_id = data.get("agentId", "unknown")
                        if agent_id not in agent_data:
                            agent_data[agent_id] = {"count": 0}
                        agent_data[agent_id]["count"] += 1
                    except json.JSONDecodeError:
                        pass
        except IOError:
            pass

    # Convert to SubagentStats (simple count-based tracking)
    for agent_id, data in agent_data.items():
        stats.subagents[agent_id] = SubagentStats(agent_id=agent_id)


def _load_project_stats(project_dir: Path, since_days: Optional[int] = None) -> Optional[ProjectStats]:
    """Load all session statistics for a project.

    Args:
        project_dir: Path to project directory.
        since_days: Only include sessions from the last N days.

    Returns:
        ProjectStats object or None if no sessions found.
    """
    decoded_dir = _decode_project_dir(project_dir.name)

    stats = ProjectStats(project_dir=decoded_dir)

    # Iterate over session directories (UUIDs)
    for session_dir in project_dir.iterdir():
        if not session_dir.is_dir():
            continue

        session_stats = _load_session_stats(session_dir, decoded_dir)
        if not session_stats:
            continue

        # Apply date filter if specified
        if since_days:
            cutoff_time = int((datetime.now() - timedelta(days=since_days)).timestamp())
            if session_stats.end_time < cutoff_time:
                continue

        # Aggregate into project stats
        stats.total_input_tokens += session_stats.total_input_tokens
        stats.total_output_tokens += session_stats.total_output_tokens
        stats.total_cache_creation += session_stats.total_cache_creation
        stats.total_cache_read += session_stats.total_cache_read
        stats.cost_usd += session_stats.cost_usd
        stats.session_count += 1

        # Aggregate subagent stats
        for agent_id, agent_stats in session_stats.subagents.items():
            if agent_id not in stats.subagents:
                stats.subagents[agent_id] = SubagentStats(agent_id=agent_id)
            proj_agent = stats.subagents[agent_id]
            proj_agent.session_count += 1

        stats.sessions.append(session_stats)

    return stats if stats.session_count > 0 else None


def load_all_projects(since_days: Optional[int] = None) -> list[ProjectStats]:
    """Load statistics for all projects.

    Args:
        since_days: Only include sessions from the last N days.

    Returns:
        List of ProjectStats objects, sorted by total tokens (descending).
    """
    projects = _discover_projects()
    all_stats = []

    for project_dir in projects:
        stats = _load_project_stats(project_dir, since_days)
        if stats:
            all_stats.append(stats)

    # Sort by total tokens (descending)
    all_stats.sort(key=lambda s: s.total_tokens(), reverse=True)
    return all_stats
