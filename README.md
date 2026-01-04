# Claude Code Status Line

Custom status line scripts for [Claude Code](https://claude.com/claude-code).

![Status Line Detail](images/statusline-detail.png)

## Screenshot

![Claude Code Status Line](images/claude-statusline.png)

**Components:** Model | Directory | Git Branch | Changes | Token Usage | Delta | Autocompact | Session ID

## Quick Start

### One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/luongnv89/claude-statusline/main/install.sh | bash
```

### Install from Source

```bash
git clone https://github.com/luongnv89/claude-statusline.git
cd claude-statusline
./install.sh
```

Restart Claude Code to see your status line.

### Windows

```powershell
copy scripts\statusline.py %USERPROFILE%\.claude\statusline.py
```

See [Installation Guide](docs/installation.md) for manual setup and Windows configuration.

## Features

- **Token Tracking**: Real-time context usage with color-coded availability
- **Git Integration**: Branch name and uncommitted changes count
- **Token Delta**: Shows consumption since last refresh
- **Autocompact Indicator**: Displays reserved buffer size
- **Session ID**: Identify and correlate multiple sessions
- **Cross-Platform**: Bash, Python, and Node.js implementations

## Token Graph

Visualize token consumption with ASCII charts:

```bash
token-graph                    # Latest session
token-graph <session_id>       # Specific session
token-graph --type cumulative  # Only cumulative graph
token-graph --watch            # Real-time monitoring mode
token-graph -w 5               # Custom refresh interval (5s)
```

![Token Usage Graph](images/token-graph.png)

See [Token Graph Documentation](docs/token-graph.md) for details.

## Configuration

Edit `~/.claude/statusline.conf`:

```bash
autocompact=true    # Show autocompact buffer
token_detail=true   # Exact vs abbreviated token counts
show_delta=true     # Token consumption delta
show_session=true   # Session ID display
```

See [Configuration Guide](docs/configuration.md) for all options.

## Available Scripts

| Script                  | Platform     | Requirements |
| ----------------------- | ------------ | ------------ |
| `statusline-full.sh`    | macOS, Linux | `jq`         |
| `statusline-git.sh`     | macOS, Linux | `jq`         |
| `statusline-minimal.sh` | macOS, Linux | `jq`         |
| `statusline.py`         | All          | Python 3     |
| `statusline.js`         | All          | Node.js      |
| `token-graph.sh`        | macOS, Linux | None         |

See [Scripts Reference](docs/scripts.md) for details.

## Documentation

- [Installation Guide](docs/installation.md) - Setup instructions for all platforms
- [Configuration](docs/configuration.md) - All configuration options
- [Token Graph](docs/token-graph.md) - Token visualization tool
- [Scripts Reference](docs/scripts.md) - Available scripts and architecture
- [Troubleshooting](docs/troubleshooting.md) - Common issues and solutions
- [Contributing](CONTRIBUTING.md) - Development setup and guidelines
- [Changelog](CHANGELOG.md) - Version history

## Blog Post

[Closing the Gap Between MVP and Production with Feature-Dev](https://medium.com/@luongnv89/closing-the-gap-between-mvp-and-production-with-feature-dev-an-official-plugin-from-anthropic-444e2f00a0ad) - Learn about the process of building this project.

## License

MIT
