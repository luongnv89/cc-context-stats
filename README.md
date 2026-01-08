# Claude Code Context Stats

[![PyPI version](https://badge.fury.io/py/cc-context-stats.svg)](https://pypi.org/project/cc-context-stats/)
[![Downloads](https://img.shields.io/pypi/dm/cc-context-stats)](https://pypi.org/project/cc-context-stats/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Never run out of context unexpectedly** - monitor your session context in real-time.

![Context Stats](images/context-status.png)

## Why Context Stats?

When working with Claude Code on complex tasks, you can easily burn through your context window without realizing it. As your context fills up, Claude's performance degrades - this is what Dex Horthy calls the "dumb zone". Context Stats helps you:

- **Know your zone** - See if you're in the Smart Zone, Dumb Zone, or Wrap Up Zone
- **Track context usage** - Real-time monitoring with live-updating graphs
- **Get early warnings** - Color-coded status alerts you before performance degrades
- **Make informed decisions** - Know when to start a fresh session

## Context Zones

| Zone                | Context Used | Status   | What It Means                                 |
| ------------------- | ------------ | -------- | --------------------------------------------- |
| 🟢 **Smart Zone**   | < 40%        | Optimal  | Claude is performing at its best              |
| 🟡 **Dumb Zone**    | 40-80%       | Degraded | Context getting full, Claude may miss details |
| 🔴 **Wrap Up Zone** | > 80%        | Critical | Better to wrap up and start a new session     |

## Installation

```bash
pip install cc-context-stats
```

Or with uv:

```bash
uv pip install cc-context-stats
```

## Quick Start

### Real-Time Monitoring

Simply run:

```bash
context-stats
```

This opens a live dashboard that refreshes every 2 seconds, showing:

- Your current project and session
- Context growth per interaction graph
- Your current zone status
- Remaining context percentage

Press `Ctrl+C` to exit.

### Status Line Integration

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "claude-statusline"
  }
}
```

Restart Claude Code to see real-time token stats in your status bar.

## Context Stats CLI

```bash
context-stats                    # Live monitoring (default)
context-stats -w 5               # Custom refresh interval (5 seconds)
context-stats --no-watch         # Show once and exit
context-stats --type cumulative  # Show cumulative context usage
context-stats --type both        # Show both graphs
context-stats --type all         # Show all graphs including I/O
context-stats <session_id>       # View specific session
```

### Output Example

```
Context Stats (my-project • abc123def)

Context Growth Per Interaction
Max: 4,787  Min: 0  Points: 254
...graph...

Session Summary
----------------------------------------------------------------------------
  >>> DUMB ZONE <<< (You are in the dumb zone - Dex Horthy says so)

  Context Remaining:   43,038 (21%)
  Input Tokens:        59,015
  Output Tokens:       43,429
  Session Duration:    2h 29m
```

## Status Line

![Status Line](images/statusline-detail.png)

The status line shows at-a-glance metrics in your Claude Code interface:

| Component | Description                               |
| --------- | ----------------------------------------- |
| Model     | Current Claude model                      |
| Context   | Tokens used / remaining with color coding |
| Delta     | Token change since last update            |
| Git       | Branch name and uncommitted changes       |
| Session   | Session ID for correlation                |

## Configuration

Create `~/.claude/statusline.conf`:

```bash
token_detail=true   # Show exact token counts (vs abbreviated like "12.5k")
show_delta=true     # Show token delta in status line
show_session=true   # Show session ID
autocompact=true    # Show autocompact buffer indicator
```

## Shell Script Installation

For users who prefer shell scripts:

```bash
curl -fsSL https://raw.githubusercontent.com/luongnv89/claude-statusline/main/install.sh | bash
```

## How It Works

Context Stats hooks into Claude Code's state files to track token usage across your sessions. Data is stored locally in `~/.claude/statusline/` and never sent anywhere.

## Documentation

- [Context Stats Guide](docs/context-stats.md) - Detailed usage guide
- [Configuration Options](docs/configuration.md) - All settings explained
- [Installation Guide](docs/installation.md) - Platform-specific setup
- [Troubleshooting](docs/troubleshooting.md) - Common issues
- [Changelog](CHANGELOG.md) - Version history

## Migration from cc-statusline

If you were using the previous `cc-statusline` package:

```bash
pip uninstall cc-statusline
pip install cc-context-stats
```

The `claude-statusline` command still works. The main change is `token-graph` is now `context-stats`.

## Related

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Dex Horthy on Context Windows](https://twitter.com/daborhty) - The "dumb zone" concept
- [Blog: Building this project](https://medium.com/@luongnv89/closing-the-gap-between-mvp-and-production-with-feature-dev-an-official-plugin-from-anthropic-444e2f00a0ad)

## License

MIT
