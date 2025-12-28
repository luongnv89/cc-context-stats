# Claude Code Status Line

Custom status line scripts for [Claude Code](https://claude.com/claude-code).

## Screenshot

![Claude Code Status Line](images/claude-statusline.png)

**Components:**
- `[Opus 4.5]` - Current AI model
- `my-project` - Current directory (blue)
- `main` - Git branch (magenta)
- `[3]` - Uncommitted changes count (cyan)
- `64,000 free (32.0%)` - Available context tokens (green >50%, yellow >25%, red ≤25%)
- `[AC:45k]` - Autocompact buffer size

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

Create a configuration file to customize the status line behavior.

**macOS / Linux:** Create `~/.claude/statusline.conf`

**Windows:** Create `%USERPROFILE%\.claude\statusline.conf`

### Available Settings

```bash
# Autocompact setting - sync with Claude Code's /config
autocompact=true   # (default) Show reserved buffer for compacting
autocompact=false  # When autocompact is disabled via /config

# Token display format
token_detail=true  # (default) Show exact token count: 64,000 free
token_detail=false # Show abbreviated tokens: 64.0k free
```

### Autocompact Display

- `[AC:45k]` - Autocompact enabled, 45k reserved for compacting
- `[AC:off]` - Autocompact disabled

### Token Display Examples

| Setting | Display |
|---------|---------|
| `token_detail=true` (default) | `64,000 free (32.0%)` |
| `token_detail=false` | `64.0k free (32.0%)` |

## Available Scripts

| Script | Platform | Requirements |
|--------|----------|--------------|
| `statusline-full.sh` | macOS, Linux | `jq` |
| `statusline-git.sh` | macOS, Linux | `jq` |
| `statusline-minimal.sh` | macOS, Linux | `jq` |
| `statusline.py` | All (Windows, macOS, Linux) | Python 3 |
| `statusline.js` | All (Windows, macOS, Linux) | Node.js |

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
