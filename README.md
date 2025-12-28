# Claude Code Status Line

Custom status line scripts for [Claude Code](https://claude.com/claude-code).

## Screenshot

![Claude Code Status Line](images/claude-statusline.png)

**Components:**
- `[Opus 4.5]` - Current AI model
- `my-project` - Current directory (blue)
- `main` - Git branch (magenta)
- `[3]` - Uncommitted changes count (cyan)
- `64.0k free (32.0%)` - Available context tokens (green >50%, yellow >25%, red ≤25%)
- `[AC:45k]` - Autocompact buffer size

## Installation

### Option 1: Automated

```bash
git clone https://github.com/luongnv89/claude-statusline.git
cd claude-statusline
./install.sh
```

### Option 2: Manual

1. Copy script to `~/.claude/`:
   ```bash
   cp scripts/statusline-full.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Add to `~/.claude/settings.json`:
   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh"
     }
   }
   ```

## Configuration

### Autocompact Setting

The AC indicator must be manually synced with Claude Code. Create `~/.claude/statusline.conf`:

```bash
# When autocompact is enabled (default)
autocompact=true

# When autocompact is disabled via /config
autocompact=false
```

**Display:**
- `[AC:45k]` - Autocompact enabled, 45k reserved for compacting
- `[AC:off]` - Autocompact disabled

## Available Scripts

| Script | Description |
|--------|-------------|
| `statusline-full.sh` | Full featured (recommended) |
| `statusline-git.sh` | Git branch info only |
| `statusline-minimal.sh` | Model + directory only |
| `statusline.py` | Python version |
| `statusline.js` | Node.js version |

## Requirements

- Claude Code CLI
- `jq` (install: `brew install jq` or `apt install jq`)
- Python 3 or Node.js for respective scripts

## Troubleshooting

**Status line not appearing?**
```bash
chmod +x ~/.claude/statusline.sh
echo '{"model":{"display_name":"Test"}}' | ~/.claude/statusline.sh
```

**Script errors?**
- Check `jq` is installed: `which jq`

## License

MIT
