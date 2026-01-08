# Context Stats

Visualize token consumption over time with ASCII area charts.

![Context Stats](../images/context-stats.png)

## Usage

After installation, the `context-stats` command is available globally:

```bash
# Show graphs for latest session
context-stats

# Show graphs for specific session
context-stats <session_id>

# Show only cumulative or delta graph
context-stats --type cumulative
context-stats --type delta

# Show both graphs (default)
context-stats --type both

# Real-time monitoring mode (refreshes every 2 seconds)
context-stats --watch
context-stats -w

# Real-time monitoring with custom interval
context-stats --watch 5
context-stats -w 3

# Combine options
context-stats abc123 --type cumulative --watch 3

# Disable colors (for piping to file)
context-stats --no-color > output.txt

# Show help
context-stats --help
```

## Graph Types

### Cumulative

Shows total tokens used over time - useful for tracking overall usage growth.

### Delta

Shows token consumption per interval - useful for identifying usage bursts.

## Features

- **Smooth Area Charts**: Continuous lines with gradient-filled areas
- **Linear Interpolation**: Smooth curves between data points
- **Real-time Watch Mode**: Built-in `--watch` option for live monitoring
- **Auto-detect Terminal Size**: Adapts to your terminal
- **Summary Statistics**: Current tokens, duration, averages
- **Version Footer**: Shows version and project link at the bottom
- **Color Support**: With `--no-color` for piping
- **Bash 3.2+ Compatible**: Works on macOS default bash

## Example Output

```
Context Statss (Session: abc123)

Cumulative Token Usage
Max: 120,000  Min: 10,000  Points: 22

   120,000 |                                                    ●●●●●●●●●●●●●
           |                                             ●●●●●●●▒▒▒▒▒▒▒▒▒▒▒▒▒
           |                                        ●●●●●▒▒▒▒▒▒▒░░░░░░░░░░░░░
    65,000 |                               ●●▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    10,000 |●●●●●●●●●●●▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
           └─────────────────────────────────────────────────────────────────
           12:46                12:56                13:07

Summary Statistics
---------------------------------------------------------------------------
  Current Tokens:      120,000
  Session Duration:    21m
  Data Points:         22
  Average Delta:       5,454
  Max Delta:           14,000
  Total Growth:        110,000

Powered by claude-statusline v1.0.0-abc123 - https://github.com/luongnv89/claude-statusline
```

## Graph Symbols

| Symbol | Meaning                 |
| ------ | ----------------------- |
| `●`    | Trend line              |
| `▒`    | Medium fill (near line) |
| `░`    | Light fill (area below) |
| `│`    | Y-axis                  |
| `└─`   | X-axis                  |

## Real-time Monitoring

Use the built-in watch mode for live updates:

```bash
# Default: refresh every 2 seconds
context-stats --watch

# Custom interval: refresh every 5 seconds
context-stats -w 5

# Monitor specific session
context-stats abc123 --watch

# Combine with graph type
context-stats --type cumulative --watch 3
```

Press `Ctrl+C` to exit watch mode.

### Watch Mode Features

- **Flicker-free updates**: Uses cursor repositioning for smooth redraws
- **Live timestamp**: Shows `[LIVE HH:MM:SS]` indicator in header
- **Hidden cursor**: Clean display without cursor blinking
- **Terminal resize**: Adapts to terminal size changes automatically
- **Graceful waiting**: Handles missing or incomplete data files

### Example Watch Mode Output

```
[LIVE 14:32:15] Refresh: 2s | Ctrl+C to exit

Context Statss (Session: abc123)

Cumulative Token Usage
Max: 85,000  Min: 10,000  Points: 15
...
```

![Real-time Context Stats](../images/claude-statusline-context-stats.gif)

### Alternative: System Watch Command

You can also use the system `watch` command:

```bash
watch -n 2 context-stats <session_id>
```

However, the built-in `--watch` mode provides smoother updates without flickering.

## Data Source

Reads from `~/.claude/statusline/statusline.<session_id>.state` files, automatically created when `show_delta=true` (default). Format: `timestamp,tokens` per line.

## Slash Command

In the claude-statusline project directory:

```bash
/context-stats                      # Latest session
/context-stats <session_id>         # Specific session
/context-stats --type cumulative    # Only cumulative
```
