# Claude Code Status Line

A collection of customizable status line scripts and setup tools for [Claude Code](https://claude.com/claude-code).

## Screenshot

```
[Opus 4.5] my-project | main [3] | 64.0k free (32.0%) [AC:45k]
```

**Components:**
- `[Opus 4.5]` - Current AI model
- `my-project` - Current directory (blue)
- `main` - Git branch (magenta)
- `[3]` - Uncommitted changes count (cyan)
- `64.0k free (32.0%)` - Available context tokens (color-coded: green >50%, yellow >25%, red ≤25%)
- `[AC:45k]` - Autocompact status with reserved buffer size

## What is the Status Line?

The status line is a customizable display at the bottom of the Claude Code interface (similar to Oh-my-zsh prompts). It shows real-time information about your session:

- Current working directory
- Git branch and uncommitted changes
- Active AI model
- Context window usage (free tokens remaining)
- Autocompact buffer status

## Quick Start

### Option 1: Automated Setup

```bash
./install.sh
```

This will:
1. Copy a status line script to `~/.claude/statusline.sh`
2. Configure your Claude Code settings
3. Make the script executable

### Option 2: Manual Setup

1. Copy your preferred script to `~/.claude/`:
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

### Option 3: Using `/statusline` Skill

In Claude Code, simply run:
```
/statusline
```

## Available Scripts

| Script | Description |
|--------|-------------|
| `statusline-full.sh` | Full featured with context usage and AC status (recommended) |
| `statusline-original.sh` | Alternative format: `[dir] branch • Model [free] [AC]` |
| `statusline-git.sh` | Simple with git branch info |
| `statusline-minimal.sh` | Minimal: model + directory only |
| `statusline.py` | Python version (same as full) |
| `statusline.js` | Node.js version (same as full) |

## How It Works

1. Claude Code sends JSON data via stdin containing session context
2. Your script processes the data and outputs a single line
3. That line becomes your status line display
4. Updates occur when conversation messages change (max every 300ms)

### JSON Input Structure

```json
{
  "model": {
    "id": "claude-opus-4-5-20251101",
    "display_name": "Opus 4.5"
  },
  "workspace": {
    "current_dir": "/path/to/project",
    "project_dir": "/path/to/project"
  },
  "cost": {
    "total_cost_usd": 0.01234,
    "total_duration_ms": 45000
  },
  "context_window": {
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "context_window_size": 200000
  }
}
```

## Customization

### Autocompact Configuration

The status line shows autocompact (AC) status. Since Claude Code doesn't expose this setting externally, you need to manually sync it:

1. Create/edit `~/.claude/statusline.conf`:
   ```bash
   # When autocompact is enabled in Claude Code (default)
   autocompact=true

   # When you disable autocompact via /config in Claude Code
   autocompact=false
   ```

2. The status line will show:
   - `[AC:45k]` - Autocompact enabled, 45k tokens reserved for compacting
   - `[AC:off]` - Autocompact disabled, full context space available

**Note:** When AC is enabled, 22.5% of the context window is reserved for the autocompact buffer (45k for a 200k context window). The "free" percentage accounts for this reservation.

### ANSI Colors

Scripts can use ANSI escape codes for colors:

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}text${RESET}"
```

### Adding Your Own Metrics

Edit any script to add custom information. Common additions:
- CPU/Memory usage
- Time of day
- Custom project info
- API response times

## Requirements

- Claude Code CLI installed
- `jq` for bash scripts (install: `brew install jq` or `apt install jq`)
- Python 3 or Node.js for respective scripts

## Troubleshooting

**Status line not appearing?**
- Ensure script is executable: `chmod +x ~/.claude/statusline.sh`
- Test manually: `echo '{"model":{"display_name":"Test"}}' | ~/.claude/statusline.sh`

**Script errors?**
- Check that `jq` is installed
- Verify JSON parsing works correctly

**Colors not showing?**
- Ensure your terminal supports ANSI colors
- Use `-e` flag with echo: `echo -e`

## License

MIT
