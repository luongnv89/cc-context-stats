# Troubleshooting

## Common Issues

### Status line not appearing

**macOS/Linux:**

1. Check script is executable:

   ```bash
   chmod +x ~/.claude/statusline.sh
   ```

2. Test the script:

   ```bash
   echo '{"model":{"display_name":"Test"}}' | ~/.claude/statusline.sh
   ```

3. Verify settings.json configuration:

   ```bash
   cat ~/.claude/settings.json
   ```

**Windows (Python):**

```powershell
echo {"model":{"display_name":"Test"}} | python %USERPROFILE%\.claude\statusline.py
```

### jq not found

The bash scripts require `jq` for JSON parsing.

**macOS:**

```bash
brew install jq
```

**Linux (Debian/Ubuntu):**

```bash
sudo apt install jq
```

**Linux (Fedora/RHEL):**

```bash
sudo dnf install jq
```

Alternatively, use the Python or Node.js version which don't require `jq`.

### token-graph command not found

1. Verify installation:

   ```bash
   ls -la ~/.local/bin/token-graph
   ```

2. Check PATH:

   ```bash
   echo $PATH | grep -q "$HOME/.local/bin" && echo "In PATH" || echo "Not in PATH"
   ```

3. Add to PATH if needed:

   ```bash
   # zsh
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc

   # bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

### No token graph data

Token history requires:

1. `show_delta=true` in `~/.claude/statusline.conf` (default)
2. Active Claude Code session generating state files
3. State files at `~/.claude/statusline/statusline.<session_id>.state`

Check for state files:

```bash
ls -la ~/.claude/statusline/statusline.*.state
```

### Git info not showing

1. Verify you're in a git repository:

   ```bash
   git rev-parse --is-inside-work-tree
   ```

2. Check git is installed:

   ```bash
   which git
   ```

### Wrong token colors

Token colors depend on availability percentage:

| Availability | Expected Color |
| ------------ | -------------- |
| > 50%        | Green          |
| > 25%        | Yellow         |
| <= 25%       | Red            |

If colors look wrong, check terminal color support.

### Delta always shows zero

Token delta requires multiple statusline refreshes. The first refresh establishes a baseline; subsequent refreshes show the delta.

### Configuration not taking effect

1. Check config file location:

   ```bash
   cat ~/.claude/statusline.conf
   ```

2. Verify syntax (no spaces around `=`):

   ```bash
   # Correct
   show_delta=true

   # Wrong
   show_delta = true
   ```

3. Restart Claude Code after config changes.

## Debug Mode

### Test script output

```bash
# Create test input
cat << 'EOF' > /tmp/test-input.json
{
  "model": {"display_name": "Opus 4.5"},
  "cwd": "/test/project",
  "session_id": "test123",
  "context": {
    "tokens_remaining": 64000,
    "context_window": 200000,
    "autocompact_buffer_tokens": 45000
  }
}
EOF

# Test each script
cat /tmp/test-input.json | ~/.claude/statusline.sh
cat /tmp/test-input.json | python3 ~/.claude/statusline.py
cat /tmp/test-input.json | node ~/.claude/statusline.js
```

### Check state files

```bash
# View state file content
cat ~/.claude/statusline/statusline.*.state

# Watch state file updates
watch -n 1 'tail -5 ~/.claude/statusline/statusline.*.state'
```

## Getting Help

- Check [existing issues](https://github.com/luongnv89/claude-statusline/issues)
- Open a new issue with:
  - Operating system
  - Shell type (bash/zsh)
  - Script version being used
  - Error messages or unexpected behavior
