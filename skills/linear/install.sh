#!/bin/bash

# Linear Skill Installer
# Author: Andrew Wilkinson (github.com/ADWilkinson)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
DRY_RUN=false

show_help() {
    echo "Linear Skill Installer"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --claude-dir DIR    Custom Claude directory (default: ~/.claude)"
    echo "  --dry-run           Preview what would be installed"
    echo "  -h, --help          Show this help message"
    echo
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --claude-dir)
            CLAUDE_DIR="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}✗${NC} Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

CLAUDE_DIR="${CLAUDE_DIR/#\~/$HOME}"
SKILL_DIR="$CLAUDE_DIR/skills/linear"

echo
echo "Linear Skill Installer"
echo "======================"
echo

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would create $SKILL_DIR/scripts"
    echo -e "${YELLOW}[DRY RUN]${NC} Would copy SKILL.md and scripts/linear.ts"
    echo -e "${YELLOW}[DRY RUN]${NC} Would install @linear/sdk (using available package manager)"
    exit 0
fi

# Create skill directory
mkdir -p "$SKILL_DIR/scripts"

# Copy files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/"
cp "$SCRIPT_DIR/scripts/linear.ts" "$SKILL_DIR/scripts/"
chmod +x "$SKILL_DIR/scripts/linear.ts"

# Detect available package manager
if command -v bun >/dev/null 2>&1; then
    PM="bun"
    PM_INSTALL="bun add"
elif command -v pnpm >/dev/null 2>&1; then
    PM="pnpm"
    PM_INSTALL="pnpm add"
elif command -v yarn >/dev/null 2>&1; then
    PM="yarn"
    PM_INSTALL="yarn add"
elif command -v npm >/dev/null 2>&1; then
    PM="npm"
    PM_INSTALL="npm install"
else
    PM=""
fi

# Install dependency
if [ -n "$PM" ]; then
    echo "Installing @linear/sdk using $PM..."
    if [ ! -f "$SKILL_DIR/package.json" ]; then
        (cd "$SKILL_DIR" && $PM init -y > /dev/null 2>&1) || (cd "$SKILL_DIR" && npm init -y > /dev/null 2>&1)
    fi
    (cd "$SKILL_DIR" && $PM_INSTALL @linear/sdk > /dev/null 2>&1) || true
else
    echo -e "${YELLOW}!${NC} No package manager found - skipping @linear/sdk install"
    echo "Install later with: (cd \"$SKILL_DIR\" && npm install @linear/sdk)"
fi

echo -e "${GREEN}✓${NC} Skill installed to $SKILL_DIR"

# Check for API key
if [ -z "$LINEAR_API_KEY" ]; then
    echo
    echo -e "${YELLOW}!${NC} LINEAR_API_KEY not found in environment"
    echo
    echo "Add to ~/.zshrc (or ~/.bashrc):"
    echo "  export LINEAR_API_KEY=\"lin_api_...\""
    echo
    echo "Get your key from:"
    echo "  Linear → Settings → Security & access → Personal API keys"
else
    echo -e "${GREEN}✓${NC} LINEAR_API_KEY detected"
fi

echo
echo "Restart Claude Code to load the skill."
echo
echo "Usage examples:"
echo "  \"show my tasks\""
echo "  \"create task: fix the login bug\""
echo "  \"mark ENG-123 done\""
echo
