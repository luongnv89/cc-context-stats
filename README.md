# Claude Code Status Line

[![PyPI version](https://badge.fury.io/py/cc-statusline.svg)](https://pypi.org/project/cc-statusline/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A custom status line and token visualization toolkit for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

![Token Usage Graph](images/token-graph.jpeg)

## Features

- **Real-time Token Tracking** - Monitor context usage with color-coded availability indicators
- **Token Visualization** - ASCII charts showing token consumption over time
- **Git Integration** - Display current branch and uncommitted changes count
- **Delta Tracking** - See token consumption since last refresh
- **Autocompact Indicator** - Shows reserved buffer size when active
- **Cross-Platform** - Works on macOS, Linux, and Windows

## Installation

### Using pip (Recommended)

```bash
pip install cc-statusline
```

### Using uv

```bash
uv pip install cc-statusline
```

### From Source

```bash
git clone https://github.com/luongnv89/claude-statusline.git
cd claude-statusline
pip install -e .
```

## Quick Start

Add to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "claude-statusline"
  }
}
```

Restart Claude Code to see your status line.

## Status Line

![Status Line Detail](images/statusline-detail.png)

**Components:** Model | Directory | Git Branch | Changes | Token Usage | Delta | Autocompact | Session ID

![Claude Code Status Line](images/claude-statusline.png)

## Token Graph

Visualize token consumption with interactive ASCII charts:

```bash
token-graph                    # Latest session
token-graph <session_id>       # Specific session
token-graph --type cumulative  # Cumulative graph only
token-graph --type delta       # Delta graph only
token-graph --watch            # Real-time monitoring
token-graph -w 5               # Custom refresh interval (5s)
```

See [Token Graph Documentation](docs/token-graph.md) for more details.

## Configuration

Create `~/.claude/statusline.conf`:

```bash
autocompact=true    # Show autocompact buffer indicator
token_detail=true   # Show exact vs abbreviated token counts
show_delta=true     # Show token consumption delta
show_session=true   # Show session ID
```

See [Configuration Guide](docs/configuration.md) for all options.

## Shell Script Installation

For users who prefer shell scripts over Python:

```bash
curl -fsSL https://raw.githubusercontent.com/luongnv89/claude-statusline/main/install.sh | bash
```

### Available Scripts

| Script                  | Platform     | Requirements |
| ----------------------- | ------------ | ------------ |
| `statusline-full.sh`    | macOS, Linux | `jq`         |
| `statusline-git.sh`     | macOS, Linux | `jq`         |
| `statusline-minimal.sh` | macOS, Linux | `jq`         |
| `statusline.py`         | All          | Python 3.9+  |
| `statusline.js`         | All          | Node.js      |

## Documentation

| Document | Description |
| -------- | ----------- |
| [Installation Guide](docs/installation.md) | Setup instructions for all platforms |
| [Configuration](docs/configuration.md) | All configuration options |
| [Token Graph](docs/token-graph.md) | Token visualization tool |
| [Scripts Reference](docs/scripts.md) | Available scripts and architecture |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and solutions |
| [Contributing](CONTRIBUTING.md) | Development setup and guidelines |
| [Changelog](CHANGELOG.md) | Version history |

## Related

- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code)
- [Blog: Closing the Gap Between MVP and Production](https://medium.com/@luongnv89/closing-the-gap-between-mvp-and-production-with-feature-dev-an-official-plugin-from-anthropic-444e2f00a0ad)

## License

MIT
