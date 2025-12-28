# Claude Code Status Line

Custom status line scripts for [Claude Code](https://claude.com/claude-code).

![Status Line Detail](images/statusline-detail.png)

## Screenshot

![Claude Code Status Line](images/claude-statusline.png)

**Components:**
- `[Opus 4.5]` - Current AI model
- `my-project` - Current directory (blue)
- `main` - Git branch (magenta)
- `[3]` - Uncommitted changes count (cyan)
- `64,000 free (32.0%)` - Available context tokens (green >50%, yellow >25%, red ≤25%)
- `[+2,500]` - Token delta since last refresh
- `[AC:45k]` - Autocompact buffer size
- `session_id` - Current session ID (double-click to select and copy)

## Installation

### macOS / Linux

```bash
git clone https://github.com/luongnv89/claude-statusline.git
cd claude-statusline
./install.sh
```

Or manually:
```bash
cp scripts/statusline-full.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

### Windows

Use the Python or Node.js version (no `jq` required):

```powershell
git clone https://github.com/luongnv89/claude-statusline.git
copy claude-statusline\scripts\statusline.py %USERPROFILE%\.claude\statusline.py
```

Or with Node.js:
```powershell
copy claude-statusline\scripts\statusline.js %USERPROFILE%\.claude\statusline.js
```

### Configure Claude Code

Add to your Claude Code settings (`~/.claude/settings.json` or `%USERPROFILE%\.claude\settings.json`):

**macOS / Linux (bash):**
```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

**Windows (Python):**
```json
{
  "statusLine": {
    "type": "command",
    "command": "python %USERPROFILE%\\.claude\\statusline.py"
  }
}
```

**Windows (Node.js):**
```json
{
  "statusLine": {
    "type": "command",
    "command": "node %USERPROFILE%\\.claude\\statusline.js"
  }
}
```

## Configuration

The configuration file `~/.claude/statusline.conf` (or `%USERPROFILE%\.claude\statusline.conf` on Windows) is **automatically created** with default settings on first run if it doesn't exist.

### Available Settings

```bash
# Autocompact setting - sync with Claude Code's /config
autocompact=true   # (default) Show reserved buffer for compacting
autocompact=false  # When autocompact is disabled via /config

# Token display format
token_detail=true  # (default) Show exact token count: 64,000 free
token_detail=false # Show abbreviated tokens: 64.0k free

# Show token delta since last refresh (adds file I/O on every refresh)
# Disable if you don't need it to reduce overhead
show_delta=true    # (default) Show delta like [+2,500]
show_delta=false   # Disable delta display

# Show session_id in status line (double-click to select and copy)
show_session=true  # (default) Show session ID
show_session=false # Hide session ID
```

### Autocompact Display

- `[AC:45k]` - Autocompact enabled, 45k reserved for compacting
- `[AC:off]` - Autocompact disabled

### Token Display Examples

| Setting | Display |
|---------|---------|
| `token_detail=true` (default) | `64,000 free (32.0%)` `[+2,500]` |
| `token_detail=false` | `64.0k free (32.0%)` `[+2.5k]` |

### Token Delta

The `[+X,XXX]` indicator shows how many tokens were consumed since the last status line refresh. This helps you track token usage during your session.

- Only positive deltas are shown (when usage increases)
- First run after starting Claude Code shows no delta (no baseline yet)
- Each session has its own state file (`~/.claude/statusline.<session_id>.state`) to avoid conflicts when running multiple Claude Code sessions in parallel
- Token history is stored with timestamps for later analysis (format: `timestamp,tokens` per line)

### Session ID Display

The session ID is displayed at the end of the status line (in dimmed text). This is useful for:

- Identifying which session you're working in when running multiple Claude Code instances
- Correlating logs and state files with specific sessions
- Debugging session-specific issues

The session ID is displayed without brackets so you can double-click to select and copy it easily. Set `show_session=false` in your config to hide the session ID.

## Token Usage Graphs

Visualize token consumption over time with ASCII graphs using the `/token-graph` slash command (in the claude-statusline project directory) or directly via the script:

```bash
# Show graphs for latest session
./scripts/token-graph.sh

# Show graphs for specific session
./scripts/token-graph.sh <session_id>

# Show only cumulative or delta graph
./scripts/token-graph.sh --type cumulative
./scripts/token-graph.sh --type delta

# Disable colors (for piping to file)
./scripts/token-graph.sh --no-color > output.txt
```

**Features:**
- **Cumulative Token Graph**: Total tokens used over time
- **Token Delta Graph**: Per-interval consumption rate
- **Auto-detect terminal size**: Adapts to your terminal dimensions
- **Summary statistics**: Current usage, duration, average delta, max delta

**Example Output:**
```
Token Usage Graphs (Session: abc123)

Cumulative Token Usage
Max: 150,000  Min: 10,000  Points: 18

   150,000 |                                              ●
           |                                          ●───●
           |                                      ●───●
    80,000 |                              ●───●───●
           |                      ●───●───●
           |              ●───●───●
    10,000 |●───●───●───●
           └──────────────────────────────────────────────────
            10:00              10:45              11:30

Summary Statistics
───────────────────────────────────────────────────────
  Current Tokens:    147,500
  Session Duration:  1h 30m
  Data Points:       18
  Average Delta:     8,750
```

## Available Scripts

| Script | Platform | Requirements |
|--------|----------|--------------|
| `statusline-full.sh` | macOS, Linux | `jq` |
| `statusline-git.sh` | macOS, Linux | `jq` |
| `statusline-minimal.sh` | macOS, Linux | `jq` |
| `statusline.py` | All (Windows, macOS, Linux) | Python 3 |
| `statusline.js` | All (Windows, macOS, Linux) | Node.js |
| `token-graph.sh` | macOS, Linux | None (bash only) |

## Requirements

### macOS
```bash
brew install jq
```

### Linux (Debian/Ubuntu)
```bash
sudo apt install jq
```

### Linux (Fedora/RHEL)
```bash
sudo dnf install jq
```

### Windows
No additional requirements for Python/Node.js scripts.

For bash scripts via WSL:
```bash
sudo apt install jq
```

## Troubleshooting

**Status line not appearing?**

macOS/Linux:
```bash
chmod +x ~/.claude/statusline.sh
echo '{"model":{"display_name":"Test"}}' | ~/.claude/statusline.sh
```

Windows (Python):
```powershell
echo {"model":{"display_name":"Test"}} | python %USERPROFILE%\.claude\statusline.py
```

**Script errors?**
- macOS/Linux: Check `jq` is installed: `which jq`
- Windows: Check Python/Node.js is in PATH: `python --version` or `node --version`

## Blog Post

📖 [Closing the Gap Between MVP and Production with Feature-Dev](https://medium.com/@luongnv89/closing-the-gap-between-mvp-and-production-with-feature-dev-an-official-plugin-from-anthropic-444e2f00a0ad) - Learn about the process of building this project.

## License

MIT
