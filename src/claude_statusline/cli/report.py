"""Report command — generates comprehensive token usage analytics.

Usage:
    context-stats report [--output FILE] [--since-days N]

Analyzes token consumption across all Claude Code projects and generates
a markdown report with project-level, session-level, and subagent-level
breakdowns.
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime
from pathlib import Path

from claude_statusline import __version__
from claude_statusline.analytics import load_all_projects
from claude_statusline.formatters.tokens import format_tokens


def _parse_report_args(argv: list[str]) -> argparse.Namespace:
    """Parse report subcommand arguments.

    Args:
        argv: Argument list (after 'report' keyword).

    Returns:
        Parsed namespace with output and since_days.
    """
    parser = argparse.ArgumentParser(
        prog="context-stats report",
        description="Generate comprehensive token usage analytics",
    )
    parser.add_argument(
        "--output",
        "-o",
        default=None,
        help="Output file path (default: context-stats-report-<timestamp>.md)",
    )
    parser.add_argument(
        "--since-days",
        type=int,
        default=None,
        help="Only include sessions from the last N days",
    )
    return parser.parse_args(argv)


def _format_timestamp(ts: int) -> str:
    """Format Unix timestamp as human-readable datetime."""
    try:
        return datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")
    except (ValueError, OSError, OverflowError):
        return str(ts)


def _format_duration(seconds: int) -> str:
    """Format duration in seconds."""
    seconds = max(0, seconds)
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60
    if hours > 0:
        return f"{hours}h {minutes}m {secs}s"
    if minutes > 0:
        return f"{minutes}m {secs}s"
    return f"{secs}s"


def generate_report(projects_stats: list) -> str:
    """Generate markdown report from project statistics.

    Args:
        projects_stats: List of ProjectStats objects.

    Returns:
        Markdown-formatted report string.
    """
    lines = []

    # Header
    lines.append("# Token Usage Analytics Report")
    lines.append("")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"Source: cc-context-stats v{__version__}")
    lines.append("")

    # Grand totals
    total_input = sum(p.total_input_tokens for p in projects_stats)
    total_output = sum(p.total_output_tokens for p in projects_stats)
    total_cache_creation = sum(p.total_cache_creation for p in projects_stats)
    total_cache_read = sum(p.total_cache_read for p in projects_stats)
    total_cost = sum(p.cost_usd for p in projects_stats)
    total_sessions = sum(p.session_count for p in projects_stats)

    lines.append("## Grand Totals")
    lines.append("")
    lines.append(
        f"- **Total Tokens**: {format_tokens(total_input + total_output + total_cache_creation + total_cache_read)}"
    )
    lines.append(f"  - Input: {format_tokens(total_input)}")
    lines.append(f"  - Output: {format_tokens(total_output)}")
    lines.append(f"  - Cache Creation: {format_tokens(total_cache_creation)}")
    lines.append(f"  - Cache Read: {format_tokens(total_cache_read)}")
    lines.append(f"- **Total Cost**: ${total_cost:.2f}")
    lines.append(f"- **Total Sessions**: {total_sessions}")
    lines.append(f"- **Projects Analyzed**: {len(projects_stats)}")
    lines.append("")

    # Per-project breakdown
    lines.append("## Projects")
    lines.append("")

    for idx, project in enumerate(projects_stats, 1):
        lines.append(f"### {idx}. {project.project_dir}")
        lines.append("")
        lines.append(f"- **Total Tokens**: {format_tokens(project.total_tokens())}")
        lines.append(f"  - Input: {format_tokens(project.total_input_tokens)}")
        lines.append(f"  - Output: {format_tokens(project.total_output_tokens)}")
        lines.append(f"  - Cache Creation: {format_tokens(project.total_cache_creation)}")
        lines.append(f"  - Cache Read: {format_tokens(project.total_cache_read)}")
        lines.append(f"- **Cost**: ${project.cost_usd:.2f}")
        lines.append(f"- **Sessions**: {project.session_count}")
        lines.append("")

        # Top 10 sessions for this project
        if project.sessions:
            lines.append("#### Sessions (by token count)")
            lines.append("")

            sorted_sessions = sorted(
                project.sessions,
                key=lambda s: s.total_tokens(),
                reverse=True,
            )[:10]

            for session in sorted_sessions:
                duration = _format_duration(session.end_time - session.start_time)
                start = _format_timestamp(session.start_time)
                tokens = format_tokens(session.total_tokens())

                lines.append(f"- **{session.session_id[:8]}...** ({session.model_id})")
                lines.append(f"  - Tokens: {tokens} | Cost: ${session.cost_usd:.2f}")
                lines.append(f"  - Duration: {duration} | Started: {start}")
                lines.append(
                    f"  - Details: {format_tokens(session.total_input_tokens)} input, {format_tokens(session.total_output_tokens)} output, {format_tokens(session.total_cache_creation)} cache_create, {format_tokens(session.total_cache_read)} cache_read"
                )

            lines.append("")

    lines.append("---")
    lines.append("*Report generated by cc-context-stats*")

    return "\n".join(lines)


def run_report(argv: list[str]) -> None:
    """Execute report command.

    Args:
        argv: Command-line arguments (after 'report' keyword).
    """
    args = _parse_report_args(argv)

    # Load all project statistics
    projects_stats = load_all_projects(since_days=args.since_days)

    if not projects_stats:
        print("No project data found in ~/.claude/statusline/", file=sys.stderr)
        sys.exit(1)

    # Generate report
    report = generate_report(projects_stats)

    # Determine output file
    if args.output:
        output_path = Path(args.output)
    else:
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        output_path = Path.cwd() / f"context-stats-report-{timestamp}.md"

    # Write report
    try:
        with open(output_path, "w") as f:
            f.write(report)
        print(f"✓ Report generated: {output_path}")
    except OSError as e:
        print(f"✗ Failed to write report: {e}", file=sys.stderr)
        sys.exit(1)
