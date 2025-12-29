#!/bin/bash
#
# Claude Code Status Line Installer
# Installs and configures a status line for Claude Code
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
LOCAL_BIN="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}Claude Code Status Line Installer${RESET}"
echo "=================================="
echo

# Check for jq (required for bash scripts)
check_jq() {
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: 'jq' is not installed.${RESET}"
        echo "jq is required for bash status line scripts."
        echo
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "Install with: brew install jq"
        else
            echo "Install with: sudo apt install jq (Debian/Ubuntu)"
            echo "         or: sudo yum install jq (RHEL/CentOS)"
        fi
        echo
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo -e "${GREEN}✓${RESET} jq is installed"
    fi
}

# Select script type
select_script() {
    echo
    echo "Available status line scripts:"
    echo "  1) minimal  - Simple: model + directory"
    echo "  2) git      - With git branch info"
    echo "  3) full     - Full featured with context usage (recommended)"
    echo "  4) python   - Python version (full featured)"
    echo "  5) node     - Node.js version (full featured)"
    echo
    read -rp "Select script [1-5, default: 3]: " choice

    case ${choice:-3} in
        1) SCRIPT_SRC="$SCRIPT_DIR/scripts/statusline-minimal.sh"; SCRIPT_NAME="statusline.sh" ;;
        2) SCRIPT_SRC="$SCRIPT_DIR/scripts/statusline-git.sh"; SCRIPT_NAME="statusline.sh" ;;
        3) SCRIPT_SRC="$SCRIPT_DIR/scripts/statusline-full.sh"; SCRIPT_NAME="statusline.sh" ;;
        4) SCRIPT_SRC="$SCRIPT_DIR/scripts/statusline.py"; SCRIPT_NAME="statusline.py" ;;
        5) SCRIPT_SRC="$SCRIPT_DIR/scripts/statusline.js"; SCRIPT_NAME="statusline.js" ;;
        *) echo -e "${RED}Invalid choice${RESET}"; exit 1 ;;
    esac
}

# Create .claude directory if needed
ensure_claude_dir() {
    if [ ! -d "$CLAUDE_DIR" ]; then
        echo -e "${YELLOW}Creating $CLAUDE_DIR directory...${RESET}"
        mkdir -p "$CLAUDE_DIR"
    fi
    echo -e "${GREEN}✓${RESET} Claude directory exists: $CLAUDE_DIR"
}

# Copy script
install_script() {
    DEST="$CLAUDE_DIR/$SCRIPT_NAME"

    if [ -f "$DEST" ]; then
        echo
        echo -e "${YELLOW}Warning: $DEST already exists${RESET}"
        read -p "Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Keeping existing script."
            return
        fi
    fi

    cp "$SCRIPT_SRC" "$DEST"
    chmod +x "$DEST"
    echo -e "${GREEN}✓${RESET} Installed: $DEST"
}

# Install token-graph CLI tool
install_token_graph() {
    echo

    # Create ~/.local/bin if it doesn't exist
    if [ ! -d "$LOCAL_BIN" ]; then
        echo -e "${YELLOW}Creating $LOCAL_BIN directory...${RESET}"
        mkdir -p "$LOCAL_BIN"
    fi

    DEST="$LOCAL_BIN/token-graph"
    SRC="$SCRIPT_DIR/scripts/token-graph.sh"

    if [ -f "$DEST" ]; then
        echo -e "${YELLOW}Warning: $DEST already exists${RESET}"
        read -p "Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Keeping existing token-graph."
            return
        fi
    fi

    cp "$SRC" "$DEST"
    chmod +x "$DEST"
    echo -e "${GREEN}✓${RESET} Installed: $DEST"

    # Check if ~/.local/bin is in PATH
    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        echo
        echo -e "${YELLOW}Note: $LOCAL_BIN is not in your PATH${RESET}"
        echo "Add it to your shell configuration:"
        echo
        if [[ "$SHELL" == *"zsh"* ]]; then
            echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
            echo "  source ~/.zshrc"
        else
            echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
            echo "  source ~/.bashrc"
        fi
    fi
}

# Create config file with defaults if it doesn't exist
create_config() {
    CONFIG_FILE="$CLAUDE_DIR/statusline.conf"

    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}✓${RESET} Config file exists: $CONFIG_FILE"
        return
    fi

    cat > "$CONFIG_FILE" << 'EOF'
# Autocompact setting - sync with Claude Code's /config
autocompact=true

# Token display format
token_detail=true

# Show token delta since last refresh (adds file I/O on every refresh)
# Disable if you don't need it to reduce overhead
show_delta=true

# Show session_id in status line
show_session=true
EOF
    echo -e "${GREEN}✓${RESET} Created config file: $CONFIG_FILE"
}

# Update settings.json
update_settings() {
    echo

    # Create settings file if it doesn't exist
    if [ ! -f "$SETTINGS_FILE" ]; then
        echo '{}' > "$SETTINGS_FILE"
        echo -e "${GREEN}✓${RESET} Created $SETTINGS_FILE"
    fi

    # Check if jq is available for JSON manipulation
    if command -v jq &> /dev/null; then
        # Backup existing settings
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"

        # Add/update statusLine configuration
        SCRIPT_PATH="$HOME/.claude/$SCRIPT_NAME"
        jq --arg cmd "$SCRIPT_PATH" '.statusLine = {"type": "command", "command": $cmd}' \
            "$SETTINGS_FILE.backup" > "$SETTINGS_FILE"

        rm "$SETTINGS_FILE.backup"
        echo -e "${GREEN}✓${RESET} Updated settings.json with statusLine configuration"
    else
        echo -e "${YELLOW}Note: Could not update settings.json (jq not installed)${RESET}"
        echo
        echo "Please add this to $SETTINGS_FILE manually:"
        echo
        echo '  "statusLine": {'
        echo '    "type": "command",'
        echo "    \"command\": \"~/.claude/$SCRIPT_NAME\""
        echo '  }'
    fi
}

# Main installation
main() {
    check_jq
    ensure_claude_dir
    select_script
    install_script
    install_token_graph
    create_config
    update_settings

    echo
    echo -e "${GREEN}Installation complete!${RESET}"
    echo
    echo "Your status line is now configured."
    echo "Restart Claude Code to see the changes."
    echo
    echo "To customize, edit: $CLAUDE_DIR/$SCRIPT_NAME"
    echo "To change settings, edit: $CLAUDE_DIR/statusline.conf"
    echo
    echo "Run 'token-graph' to visualize token usage for any session."
}

main
