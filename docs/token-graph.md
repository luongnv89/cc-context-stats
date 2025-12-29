# Token Graph

Visualize token consumption over time with ASCII area charts.

![Token Usage Graph](../images/token-graph.png)

## Usage

After installation, the `token-graph` command is available globally:

```bash
# Show graphs for latest session
token-graph

# Show graphs for specific session
token-graph <session_id>

# Show only cumulative or delta graph
token-graph --type cumulative
token-graph --type delta

# Show both graphs (default)
token-graph --type both

# Real-time monitoring mode (refreshes every 2 seconds)
token-graph --watch
token-graph -w

# Real-time monitoring with custom interval
token-graph --watch 5
token-graph -w 3

# Combine options
token-graph abc123 --type cumulative --watch 3

# Disable colors (for piping to file)
token-graph --no-color > output.txt

# Show help
token-graph --help
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
- **Color Support**: With `--no-color` for piping
- **Bash 3.2+ Compatible**: Works on macOS default bash

## Example Output

```
Token Usage Graphs (Session: abc123)

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
token-graph --watch

# Custom interval: refresh every 5 seconds
token-graph -w 5

# Monitor specific session
token-graph abc123 --watch
```

Press `Ctrl+C` to exit watch mode.

![Real-time Token Graph](../images/claude-statusline-token-graph.gif)

Alternatively, use the system `watch` command:

```bash
watch -n 2 token-graph <session_id>
```

## Data Source

Reads from `~/.claude/statusline.<session_id>.state` files, automatically created when `show_delta=true` (default). Format: `timestamp,tokens` per line.

## Slash Command

In the claude-statusline project directory:

```bash
/token-graph                      # Latest session
/token-graph <session_id>         # Specific session
/token-graph --type cumulative    # Only cumulative
```
