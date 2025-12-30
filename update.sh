#!/bin/bash

# Claude Code Tools Update Script
# Author: Andrew Wilkinson (github.com/ADWilkinson)
# Updates installed tools to the latest version

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/ADWilkinson/claude-code-tools/main"
CLAUDE_DIR="$HOME/.claude"
DRY_RUN=false
VERBOSE=false

print_status() { echo -e "${BLUE}→${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_verbose() { [ "$VERBOSE" = true ] && echo -e "  $1"; }

show_help() {
    echo "Claude Code Tools Updater"
    echo
    echo "Usage: ./update.sh [options]"
    echo
    echo "Options:"
    echo "  --dry-run    Preview what would be updated"
    echo "  -v           Verbose output"
    echo "  -h, --help   Show this help message"
    echo
}

# Files to update
AGENTS=(
    "backend-developer.md"
    "blockchain-specialist.md"
    "database-manager.md"
    "devops-engineer.md"
    "extension-developer.md"
    "firebase-specialist.md"
    "frontend-developer.md"
    "indexer-developer.md"
    "mobile-developer.md"
    "performance-engineer.md"
    "testing-specialist.md"
    "zk-specialist.md"
)

COMMANDS=(
    "repo-polish.md"
    "update-claudes.md"
)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo
echo -e "${BOLD}Claude Code Tools Updater${NC}"
echo "========================="
echo

if [ ! -d "$CLAUDE_DIR" ]; then
    print_error "Claude Code directory not found at $CLAUDE_DIR"
    print_error "Run install.sh first"
    exit 1
fi

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN - No files will be modified"
    echo
fi

updated=0
failed=0

# Update agents
print_status "Updating agents..."
mkdir -p "$CLAUDE_DIR/agents"
for agent in "${AGENTS[@]}"; do
    if [ "$DRY_RUN" = true ]; then
        print_verbose "Would update: agents/$agent"
        ((updated++))
    else
        if curl -sf "$REPO_URL/agents/$agent" -o "$CLAUDE_DIR/agents/$agent" 2>/dev/null; then
            print_verbose "Updated: agents/$agent"
            ((updated++))
        else
            print_verbose "Failed: agents/$agent"
            ((failed++))
        fi
    fi
done
print_success "Agents: ${#AGENTS[@]} files"

# Update commands
print_status "Updating commands..."
mkdir -p "$CLAUDE_DIR/commands"
for cmd in "${COMMANDS[@]}"; do
    if [ "$DRY_RUN" = true ]; then
        print_verbose "Would update: commands/$cmd"
        ((updated++))
    else
        if curl -sf "$REPO_URL/commands/$cmd" -o "$CLAUDE_DIR/commands/$cmd" 2>/dev/null; then
            print_verbose "Updated: commands/$cmd"
            ((updated++))
        else
            print_verbose "Failed: commands/$cmd"
            ((failed++))
        fi
    fi
done
print_success "Commands: ${#COMMANDS[@]} files"

# Update statusline
print_status "Updating statusline..."
if [ "$DRY_RUN" = true ]; then
    print_verbose "Would update: flying-dutchman-statusline.sh"
    ((updated++))
else
    if curl -sf "$REPO_URL/statusline/flying-dutchman-statusline.sh" -o "$CLAUDE_DIR/flying-dutchman-statusline.sh" 2>/dev/null; then
        chmod +x "$CLAUDE_DIR/flying-dutchman-statusline.sh"
        print_verbose "Updated: flying-dutchman-statusline.sh"
        ((updated++))
    else
        print_verbose "Failed: flying-dutchman-statusline.sh"
        ((failed++))
    fi
fi
print_success "Statusline: 1 file"

# Update Linear skill if installed
if [ -d "$CLAUDE_DIR/skills/linear" ]; then
    print_status "Updating Linear skill..."
    mkdir -p "$CLAUDE_DIR/skills/linear/scripts"

    if [ "$DRY_RUN" = true ]; then
        print_verbose "Would update: skills/linear/SKILL.md"
        print_verbose "Would update: skills/linear/scripts/linear.ts"
        ((updated+=2))
    else
        skill_updated=0
        if curl -sf "$REPO_URL/skills/linear/SKILL.md" -o "$CLAUDE_DIR/skills/linear/SKILL.md" 2>/dev/null; then
            print_verbose "Updated: skills/linear/SKILL.md"
            ((skill_updated++))
            ((updated++))
        fi
        if curl -sf "$REPO_URL/skills/linear/scripts/linear.ts" -o "$CLAUDE_DIR/skills/linear/scripts/linear.ts" 2>/dev/null; then
            print_verbose "Updated: skills/linear/scripts/linear.ts"
            ((skill_updated++))
            ((updated++))
        fi

        # Reinstall npm dependencies if needed
        if [ $skill_updated -gt 0 ] && [ -f "$CLAUDE_DIR/skills/linear/package.json" ]; then
            print_verbose "Updating npm dependencies..."
            (cd "$CLAUDE_DIR/skills/linear" && npm install --silent 2>/dev/null) || true
        fi
    fi
    print_success "Linear skill: 2 files"
else
    print_verbose "Linear skill not installed, skipping"
fi

echo
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN complete - no files were modified"
else
    if [ $failed -eq 0 ]; then
        print_success "Update complete ($updated files)"
    else
        print_warning "Update complete with errors ($updated updated, $failed failed)"
    fi
fi
echo
print_status "Restart Claude Code to load updates"
echo
