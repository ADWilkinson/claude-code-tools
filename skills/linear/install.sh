#!/bin/bash

# Linear Skill Installer
# Author: Andrew Wilkinson (github.com/ADWilkinson)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SKILL_DIR="$HOME/.claude/skills/linear"

echo
echo "Linear Skill Installer"
echo "======================"
echo

# Create skill directory
mkdir -p "$SKILL_DIR/scripts"

# Copy files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cp "$SCRIPT_DIR/SKILL.md" "$SKILL_DIR/"
cp "$SCRIPT_DIR/scripts/linear.ts" "$SKILL_DIR/scripts/"
chmod +x "$SKILL_DIR/scripts/linear.ts"

# Install npm dependency
echo "Installing @linear/sdk..."
cd "$SKILL_DIR" && npm init -y > /dev/null 2>&1 && npm install @linear/sdk > /dev/null 2>&1

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
