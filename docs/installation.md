# Installation Guide

## Quick Install

### One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/luongnv89/claude-statusline/main/install.sh | bash
```

This downloads and runs the installer directly from GitHub. In non-interactive mode, it installs the **full** statusline script by default.

### Interactive Install

To choose a different script variant:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/luongnv89/claude-statusline/main/install.sh)
```

This runs the installer interactively, allowing you to select from:

1. minimal - Simple: model + directory
2. git - With git branch info
3. full - Full featured with context usage (recommended)
4. python - Python version (full featured)
5. node - Node.js version (full featured)

### Install from Source

```bash
git clone https://github.com/luongnv89/cc-context-stats.git
cd claude-statusline
./install.sh
```

The installer will:

1. Install the statusline script to `~/.claude/`
2. Install `context-stats` CLI tool to `~/.local/bin/`
3. Create default configuration at `~/.claude/statusline.conf`
4. Update `~/.claude/settings.json`

### Windows

Use the Python or Node.js version (no `jq` required):

```powershell
git clone https://github.com/luongnv89/cc-context-stats.git
copy claude-statusline\scripts\statusline.py %USERPROFILE%\.claude\statusline.py
```

Or with Node.js:

```powershell
copy claude-statusline\scripts\statusline.js %USERPROFILE%\.claude\statusline.js
```

## Manual Installation

### macOS / Linux

```bash
cp scripts/statusline-full.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

### Context Stats CLI (Optional)

```bash
cp scripts/context-stats.sh ~/.local/bin/context-stats
chmod +x ~/.local/bin/context-stats
```

Ensure `~/.local/bin` is in your PATH:

```bash
# For zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# For bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Configure Claude Code

Add to your Claude Code settings:

**File location:**

- macOS/Linux: `~/.claude/settings.json`
- Windows: `%USERPROFILE%\.claude\settings.json`

### Bash (macOS/Linux)

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

### Python (All Platforms)

```json
{
  "statusLine": {
    "type": "command",
    "command": "python ~/.claude/statusline.py"
  }
}
```

Windows:

```json
{
  "statusLine": {
    "type": "command",
    "command": "python %USERPROFILE%\\.claude\\statusline.py"
  }
}
```

### Node.js (All Platforms)

```json
{
  "statusLine": {
    "type": "command",
    "command": "node ~/.claude/statusline.js"
  }
}
```

Windows:

```json
{
  "statusLine": {
    "type": "command",
    "command": "node %USERPROFILE%\\.claude\\statusline.js"
  }
}
```

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

## Verify Installation

Test your statusline script:

```bash
# macOS/Linux
echo '{"model":{"display_name":"Test"}}' | ~/.claude/statusline.sh

# Windows (Python)
echo {"model":{"display_name":"Test"}} | python %USERPROFILE%\.claude\statusline.py
```

You should see output like: `[Test] directory`

Restart Claude Code to see the status line.
