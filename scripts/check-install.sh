#!/bin/bash
#
# cc-context-stats Installation Checker
# Verifies that both the statusline and context-stats CLI are properly installed
# regardless of installation method (shell installer or pip).
#
# Usage:
#   ./scripts/check-install.sh
#   curl -fsSL https://raw.githubusercontent.com/luongnv89/cc-context-stats/main/scripts/check-install.sh | bash
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
RESET='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() {
    echo -e "  ${GREEN}✓${RESET} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "  ${RED}✗${RESET} $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo -e "  ${YELLOW}!${RESET} $1"
    WARN=$((WARN + 1))
}

info() {
    echo -e "  ${DIM}$1${RESET}"
}

# Detect which installation method was used
detect_install_method() {
    local methods=()

    # Check shell installer artifacts
    if [ -f "$HOME/.claude/statusline.py" ]; then
        methods+=("shell")
    fi

    # Check pip install
    if pip show cc-context-stats &>/dev/null 2>&1 || pip3 show cc-context-stats &>/dev/null 2>&1; then
        methods+=("pip")
    fi

    echo "${methods[@]}"
}

# Test that a command can process statusline JSON from stdin
test_statusline_command() {
    local cmd="$1"
    local test_json='{"model":{"display_name":"Claude","model_id":"claude-sonnet-4-20250514"},"session":{"id":"test-session"},"token_usage":{"total_input":1000,"total_output":500,"cache_creation_input":0,"cache_read_input":0,"percentage_used":5},"workspace":{"project_dir":"/tmp/test"}}'

    local output
    output=$(echo "$test_json" | eval "$cmd" 2>/dev/null)
    local exit_code=$?

    if [ $exit_code -eq 0 ] && [ -n "$output" ]; then
        return 0
    fi
    return 1
}

echo -e "${BLUE}cc-context-stats Installation Check${RESET}"
echo "====================================="
echo

# ─── Step 1: Detect installation method ───
echo -e "${BLUE}1. Installation Detection${RESET}"

METHODS=$(detect_install_method)
if [ -z "$METHODS" ]; then
    fail "No installation detected"
    info "Install via one of:"
    info "  curl -fsSL https://raw.githubusercontent.com/luongnv89/cc-context-stats/main/install.sh | bash"
    info "  pip install cc-context-stats"
    echo
    echo -e "${RED}Check failed: nothing is installed.${RESET}"
    exit 1
fi

for method in $METHODS; do
    pass "Detected installation method: $method"
done
echo

# ─── Step 2: Check statusline command availability ───
echo -e "${BLUE}2. Statusline Command${RESET}"

STATUSLINE_CMD=""
STATUSLINE_SOURCE=""

# Check claude-statusline in PATH (pip install)
if command -v claude-statusline &>/dev/null; then
    STATUSLINE_CMD="claude-statusline"
    STATUSLINE_SOURCE="PATH ($(command -v claude-statusline))"
fi

# Check standalone Python script (shell installer)
if [ -f "$HOME/.claude/statusline.py" ]; then
    if [ -z "$STATUSLINE_CMD" ]; then
        STATUSLINE_CMD="python3 $HOME/.claude/statusline.py"
        STATUSLINE_SOURCE="standalone Python ($HOME/.claude/statusline.py)"
    else
        pass "Also found standalone Python: ~/.claude/statusline.py"
    fi
fi

if [ -n "$STATUSLINE_CMD" ]; then
    pass "Statusline command found: $STATUSLINE_SOURCE"
else
    fail "No statusline command found"
    info "Expected one of:"
    info "  - 'claude-statusline' in PATH (pip install)"
    info "  - ~/.claude/statusline.py (shell installer or manual Python)"
fi

# Test that the statusline command actually works
if [ -n "$STATUSLINE_CMD" ]; then
    if test_statusline_command "$STATUSLINE_CMD"; then
        pass "Statusline command produces output from JSON input"
    else
        fail "Statusline command failed to process test input"
        info "Try running: echo '{\"model\":{\"display_name\":\"Test\"}}' | $STATUSLINE_CMD"
    fi
fi
echo

# ─── Step 3: Check context-stats CLI availability ───
echo -e "${BLUE}3. Context-Stats CLI${RESET}"

CONTEXT_STATS_CMD=""
CONTEXT_STATS_SOURCE=""

# Check context-stats in PATH (npm/pip install or bash installer with ~/.local/bin in PATH)
if command -v context-stats &>/dev/null; then
    CONTEXT_STATS_CMD="context-stats"
    CONTEXT_STATS_SOURCE="PATH ($(command -v context-stats))"
fi

# Check bash installer location specifically
if [ -x "$HOME/.local/bin/context-stats" ]; then
    if [ -z "$CONTEXT_STATS_CMD" ]; then
        CONTEXT_STATS_CMD="$HOME/.local/bin/context-stats"
        CONTEXT_STATS_SOURCE="$HOME/.local/bin/context-stats (not in PATH)"
        warn "context-stats found at ~/.local/bin/ but not in PATH"
        if [[ "$SHELL" == *"zsh"* ]]; then
            info "Add to PATH: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
        else
            info "Add to PATH: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
        fi
    else
        pass "context-stats in PATH: $CONTEXT_STATS_SOURCE"
    fi
else
    if [ -n "$CONTEXT_STATS_CMD" ]; then
        pass "context-stats in PATH: $CONTEXT_STATS_SOURCE"
    else
        fail "context-stats CLI not found"
        info "Expected one of:"
        info "  - 'context-stats' in PATH (pip install)"
        info "  - ~/.local/bin/context-stats (shell installer)"
    fi
fi

# Test context-stats --help
if [ -n "$CONTEXT_STATS_CMD" ]; then
    if $CONTEXT_STATS_CMD --help &>/dev/null 2>&1 || $CONTEXT_STATS_CMD -h &>/dev/null 2>&1; then
        pass "context-stats --help works"
    else
        warn "context-stats --help did not succeed (may still work)"
    fi
fi
echo

# ─── Step 4: Check Claude Code settings.json ───
echo -e "${BLUE}4. Claude Code Settings${RESET}"

SETTINGS_FILE="$HOME/.claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    pass "Settings file exists: $SETTINGS_FILE"

    # Check for statusLine configuration
    if command -v jq &>/dev/null; then
        SL_TYPE=$(jq -r '.statusLine.type // empty' "$SETTINGS_FILE" 2>/dev/null)
        SL_CMD=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null)

        if [ "$SL_TYPE" = "command" ] && [ -n "$SL_CMD" ]; then
            pass "statusLine configured: type=command, command=$SL_CMD"

            # Verify the configured command actually exists/works
            # Expand ~ to $HOME for checking
            EXPANDED_CMD="${SL_CMD/#\~/$HOME}"

            if [ -x "$EXPANDED_CMD" ]; then
                pass "Configured statusline command is executable"
            elif command -v "$SL_CMD" &>/dev/null; then
                pass "Configured statusline command is in PATH"
            else
                fail "Configured statusline command not found: $SL_CMD"
                info "The command in settings.json does not exist or is not executable"
                if [ -n "$STATUSLINE_CMD" ]; then
                    info "Fix: update settings.json statusLine.command to: $STATUSLINE_CMD"
                fi
            fi
        else
            fail "statusLine not configured in settings.json"
            info "Add to $SETTINGS_FILE:"
            info '  "statusLine": { "type": "command", "command": "claude-statusline" }'
        fi
    else
        # No jq, try grep
        if grep -q '"statusLine"' "$SETTINGS_FILE" 2>/dev/null; then
            pass "statusLine entry found in settings.json (install jq for detailed check)"
        else
            fail "statusLine not configured in settings.json"
            info "Add to $SETTINGS_FILE:"
            info '  "statusLine": { "type": "command", "command": "claude-statusline" }'
        fi
    fi
else
    fail "Settings file not found: $SETTINGS_FILE"
    info "Create it with:"
    info '  echo '"'"'{"statusLine":{"type":"command","command":"claude-statusline"}}'"'"' > ~/.claude/settings.json'
fi
echo

# ─── Step 5: Check config file ───
echo -e "${BLUE}5. Configuration${RESET}"

CONFIG_FILE="$HOME/.claude/statusline.conf"
if [ -f "$CONFIG_FILE" ]; then
    pass "Config file exists: $CONFIG_FILE"
else
    warn "No config file at $CONFIG_FILE (defaults will be used)"
    info "Create one for customization - see README for options"
fi

# Check state directory
STATE_DIR="$HOME/.claude/statusline"
if [ -d "$STATE_DIR" ]; then
    STATE_COUNT=$(ls "$STATE_DIR"/statusline.*.state 2>/dev/null | wc -l | tr -d ' ')
    pass "State directory exists with $STATE_COUNT session file(s)"
else
    warn "State directory not yet created: $STATE_DIR"
    info "This is normal for fresh installs - it will be created on first Claude Code session"
fi
echo

# ─── Summary ───
echo -e "${BLUE}Summary${RESET}"
echo "======="

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${RESET} ($PASS passed, $WARN warnings)"
    echo
    echo "Both statusline and context-stats are properly installed."
    echo "Restart Claude Code to activate the status line."
else
    echo -e "${RED}$FAIL check(s) failed${RESET}, $PASS passed, $WARN warnings"
    echo

    # Provide targeted fix guidance
    if [ -z "$STATUSLINE_CMD" ] && [ -z "$CONTEXT_STATS_CMD" ]; then
        echo "Neither component is installed. Run the full installer:"
        echo -e "  ${BLUE}curl -fsSL https://raw.githubusercontent.com/luongnv89/cc-context-stats/main/install.sh | bash${RESET}"
    elif [ -z "$STATUSLINE_CMD" ]; then
        echo "The statusline is missing. Fix depends on your install method:"
        echo "  pip:    Verify with 'pip show cc-context-stats' and check 'claude-statusline' is in PATH"
        echo "  shell:  Re-run the installer: ./install.sh"
    elif [ -z "$CONTEXT_STATS_CMD" ]; then
        echo "The context-stats CLI is missing. Fix depends on your install method:"
        echo "  pip:    Verify with 'pip show cc-context-stats' and check 'context-stats' is in PATH"
        echo "  shell:  Re-run the installer: ./install.sh"
    else
        echo "Components found but settings may need updating."
        echo "Check the failed items above for specific fix instructions."
    fi
fi

exit $FAIL
