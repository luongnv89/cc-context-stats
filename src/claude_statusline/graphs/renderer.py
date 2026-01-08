"""ASCII graph rendering engine."""

from __future__ import annotations

import shutil
from dataclasses import dataclass

from claude_statusline.core.colors import ColorManager
from claude_statusline.formatters.time import format_duration, format_timestamp
from claude_statusline.formatters.tokens import format_tokens
from claude_statusline.graphs.statistics import Stats, calculate_stats


@dataclass
class GraphDimensions:
    """Terminal and graph dimensions."""

    term_width: int
    term_height: int
    graph_width: int
    graph_height: int

    @classmethod
    def detect(cls) -> GraphDimensions:
        """Detect terminal dimensions and calculate graph size."""
        term_size = shutil.get_terminal_size((80, 24))
        term_width = term_size.columns
        term_height = term_size.lines

        # Calculate graph dimensions
        graph_width = term_width - 15  # Reserve space for Y-axis labels
        graph_height = term_height // 3  # Each graph takes 1/3 of terminal

        # Enforce minimums and maximums
        graph_width = max(30, graph_width)
        graph_height = max(8, min(20, graph_height))

        return cls(
            term_width=term_width,
            term_height=term_height,
            graph_width=graph_width,
            graph_height=graph_height,
        )


class GraphRenderer:
    """ASCII graph rendering engine."""

    # Characters for graph rendering
    DOT = "●"
    FILL_LIGHT = "▒"
    FILL_DARK = "░"

    def __init__(
        self,
        colors: ColorManager | None = None,
        dimensions: GraphDimensions | None = None,
        token_detail: bool = True,
    ) -> None:
        """Initialize graph renderer.

        Args:
            colors: ColorManager instance. Creates default if None.
            dimensions: GraphDimensions instance. Detects if None.
            token_detail: Whether to show detailed token counts.
        """
        self.colors = colors or ColorManager(enabled=True)
        self.dimensions = dimensions or GraphDimensions.detect()
        self.token_detail = token_detail

    def render_timeseries(
        self,
        data: list[int],
        timestamps: list[int],
        title: str,
        color: str,
    ) -> None:
        """Render a timeseries ASCII graph.

        Args:
            data: List of values to plot
            timestamps: Corresponding timestamps for x-axis labels
            title: Graph title
            color: ANSI color code for the graph
        """
        n = len(data)
        if n == 0:
            return

        stats = calculate_stats(data)
        min_val = stats.min_val
        max_val = stats.max_val

        # Avoid division by zero
        if min_val == max_val:
            max_val = min_val + 1
        value_range = max_val - min_val

        width = self.dimensions.graph_width
        height = self.dimensions.graph_height

        # Print title and stats
        print()
        print(f"{self.colors.bold}{title}{self.colors.reset}")
        print(
            f"{self.colors.dim}Max: {format_tokens(max_val, self.token_detail)}  "
            f"Min: {format_tokens(min_val, self.token_detail)}  "
            f"Points: {n}{self.colors.reset}"
        )
        print()

        # Build the graph grid
        grid = self._build_grid(data, min_val, max_val, value_range, width, height)

        # Print grid with Y-axis labels
        for r in range(height):
            val = max_val - r * value_range // (height - 1)

            # Show labels at top, middle, and bottom
            if r == 0 or r == height // 2 or r == height - 1:
                label = format_tokens(val, self.token_detail)
            else:
                label = ""

            row_data = grid[r] if r < len(grid) else " " * width
            print(
                f"{label:>10} {self.colors.dim}│{self.colors.reset}"
                f"{color}{row_data}{self.colors.reset}"
            )

        # X-axis
        print(f"{'':>10} {self.colors.dim}└{'─' * width}{self.colors.reset}")

        # Time labels
        if timestamps:
            first_time = format_timestamp(timestamps[0])
            last_time = format_timestamp(timestamps[-1])
            mid_idx = (n - 1) // 2
            mid_time = format_timestamp(timestamps[mid_idx]) if n > 2 else ""

            spacing = width // 3
            print(
                f"{' ':>11}{self.colors.dim}"
                f"{first_time:<{spacing}}{mid_time}{last_time:>{spacing}}"
                f"{self.colors.reset}"
            )

    def _build_grid(
        self,
        data: list[int],
        min_val: int,
        max_val: int,
        value_range: int,
        width: int,
        height: int,
    ) -> list[str]:
        """Build the ASCII grid for the graph.

        Args:
            data: List of values to plot
            min_val: Minimum value in data
            max_val: Maximum value in data
            value_range: max_val - min_val
            width: Graph width in characters
            height: Graph height in rows

        Returns:
            List of strings, one per row
        """
        n = len(data)
        if n == 0:
            return [" " * width for _ in range(height)]

        # Initialize grid with empty spaces
        grid = [[" " for _ in range(width)] for _ in range(height)]

        # Calculate y positions for each data point
        data_x = []
        data_y = []
        for i, val in enumerate(data):
            # Map index to x coordinate
            if n == 1:
                x = width // 2
            else:
                x = int((i) * (width - 1) / (n - 1))
            x = max(0, min(width - 1, x))

            # Map value to y coordinate (inverted: 0=top)
            if value_range == 0:
                y = height // 2
            else:
                y = int((max_val - val) * (height - 1) / value_range)
            y = max(0, min(height - 1, y))

            data_x.append(x)
            data_y.append(y)

        # Interpolate between points to fill every x position
        line_y = [-1.0] * width
        for i in range(len(data) - 1):
            x1, y1 = data_x[i], data_y[i]
            x2, y2 = data_x[i + 1], data_y[i + 1]

            # Ensure we don't go out of bounds
            for x in range(x1, min(x2 + 1, width)):
                if x2 == x1:
                    y = float(y1)
                else:
                    # Linear interpolation
                    t = (x - x1) / (x2 - x1)
                    y = y1 + t * (y2 - y1)
                line_y[x] = y

        # Draw filled area and line
        for c in range(width):
            if line_y[c] >= 0:
                line_row = int(line_y[c] + 0.5)  # Round to nearest integer
                line_row = max(0, min(height - 1, line_row))

                # Fill area below the line with gradient
                for r in range(line_row, height):
                    if r == line_row:
                        grid[r][c] = self.DOT
                    elif r < line_row + 2:
                        grid[r][c] = self.FILL_LIGHT
                    else:
                        grid[r][c] = self.FILL_DARK

        # Mark actual data points
        for i in range(len(data)):
            x = data_x[i]
            y = max(0, min(height - 1, int(data_y[i] + 0.5)))
            grid[y][x] = self.DOT

        # Convert grid to strings
        return ["".join(row) for row in grid]

    def render_summary(
        self,
        entries: list,  # list[StateEntry]
        deltas: list[int],
    ) -> None:
        """Render summary statistics.

        Args:
            entries: List of StateEntry objects
            deltas: List of token deltas
        """
        if not entries:
            return

        first = entries[0]
        last = entries[-1]
        duration = last.timestamp - first.timestamp
        total_growth = last.total_tokens - first.total_tokens

        # Delta statistics
        delta_stats = calculate_stats(deltas) if deltas else Stats(0, 0, 0, 0, 0)

        # Context window info - use current_used_tokens which represents actual context usage
        remaining_context = 0
        context_percentage = 0
        if last.context_window_size > 0:
            # current_used_tokens = current_input_tokens + cache_creation + cache_read
            current_used = last.current_used_tokens
            remaining_context = max(0, last.context_window_size - current_used)
            context_percentage = remaining_context * 100 // last.context_window_size

        print()
        print(f"{self.colors.bold}Summary Statistics{self.colors.reset}")
        line_width = self.dimensions.graph_width + 11
        print(f"{self.colors.dim}{'-' * line_width}{self.colors.reset}")

        print(
            f"  {self.colors.cyan}{'Total Tokens:':<20}{self.colors.reset} "
            f"{format_tokens(last.total_tokens, self.token_detail)}"
        )
        print(
            f"  {self.colors.blue}{'Input Tokens (↓):':<20}{self.colors.reset} "
            f"{format_tokens(last.total_input_tokens, self.token_detail)}"
        )
        print(
            f"  {self.colors.magenta}{'Output Tokens (↑):':<20}{self.colors.reset} "
            f"{format_tokens(last.total_output_tokens, self.token_detail)}"
        )
        if last.context_window_size > 0:
            print(
                f"  {self.colors.green}{'Remaining Context:':<20}{self.colors.reset} "
                f"{format_tokens(remaining_context, self.token_detail)} ({context_percentage}%)"
            )
        print(
            f"  {self.colors.cyan}{'Session Duration:':<20}{self.colors.reset} "
            f"{format_duration(duration)}"
        )
        print(f"  {self.colors.cyan}{'Data Points:':<20}{self.colors.reset} " f"{len(entries)}")
        print(
            f"  {self.colors.cyan}{'Average Delta:':<20}{self.colors.reset} "
            f"{format_tokens(delta_stats.avg_val, self.token_detail)}"
        )
        print(
            f"  {self.colors.cyan}{'Max Delta:':<20}{self.colors.reset} "
            f"{format_tokens(delta_stats.max_val, self.token_detail)}"
        )
        print(
            f"  {self.colors.cyan}{'Total Growth:':<20}{self.colors.reset} "
            f"{format_tokens(total_growth, self.token_detail)}"
        )
        print()

    def render_footer(self, version: str = "1.0.0", commit_hash: str = "dev") -> None:
        """Render the footer with version info.

        Args:
            version: Package version
            commit_hash: Git commit hash
        """
        print(
            f"{self.colors.dim}Powered by {self.colors.cyan}claude-statusline"
            f"{self.colors.dim} v{version}-{commit_hash} - "
            f"https://github.com/luongnv89/claude-statusline{self.colors.reset}"
        )
        print()
