# Claude Code Context Stats

[![PyPI version](https://badge.fury.io/py/cc-context-stats.svg)](https://pypi.org/project/cc-context-stats/)
[![Downloads](https://img.shields.io/pypi/dm/cc-context-stats)](https://pypi.org/project/cc-context-stats/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Never run out of context unexpectedly** - monitor your Claude Code tokens in real-time.

![Context Stats](images/token-graph.jpeg)

## Why Context Stats?

When working with Claude Code on complex tasks, you can easily burn through your context window without realizing it. Context Stats helps you:

- **See remaining context at a glance** - Know exactly how much room you have left
- **Track token consumption over time** - Understand your usage patterns
- **Get early warnings** - Color-coded indicators alert you before you hit limits
- **Analyze sessions** - Review token usage after completing tasks

## Installation

```bash
pip install cc-context-stats
```

Or with uv:

```bash
uv pip install cc-context-stats
```

## Quick Start

### 1. Enable the Status Line

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "claude-statusline"
  }
}
```

Restart Claude Code. You'll see real-time token stats in your status bar.

### 2. Monitor with Context Stats

```bash
context-stats --watch
```

This opens a live-updating dashboard showing:
- Cumulative token usage over time
- Token consumption per interaction (delta)
- Remaining context percentage
- Session statistics

## Context Stats CLI

The main feature - visualize your token consumption in real-time:

```bash
context-stats                    # Show graphs for latest session
context-stats --watch            # Live monitoring mode (updates every 2s)
context-stats -w 5               # Custom refresh interval (5 seconds)
context-stats --type cumulative  # Show only cumulative graph
context-stats --type delta       # Show only delta graph
context-stats --type all         # Show all graphs including I/O breakdown
context-stats <session_id>       # View specific session
```

### What You'll See

- **Cumulative Graph** - Total tokens used over time
- **Delta Graph** - Tokens consumed per interaction
- **Summary Stats** - Total tokens, input/output breakdown, remaining context, session duration

## Status Line

![Status Line](images/statusline-detail.png)

The status line shows at-a-glance metrics:

| Component | Description |
|-----------|-------------|
| Model | Current Claude model |
| Context | Tokens used / remaining with color coding |
| Delta | Token change since last update |
| Git | Branch name and uncommitted changes |
| Session | Session ID for correlation |

![Status Line Example](images/claude-statusline.png)

## Configuration

Create `~/.claude/statusline.conf`:

```bash
token_detail=true   # Show exact token counts (vs abbreviated like "12.5k")
show_delta=true     # Show token delta in status line
show_session=true   # Show session ID
autocompact=true    # Show autocompact buffer indicator
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
- [Blog: Building this project](https://medium.com/@luongnv89/closing-the-gap-between-mvp-and-production-with-feature-dev-an-official-plugin-from-anthropic-444e2f00a0ad)

## License

MIT
