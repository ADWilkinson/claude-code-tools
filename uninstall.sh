#!/bin/bash

# Claude Code Tools Uninstall Script
# Author: Andrew Wilkinson (github.com/ADWilkinson)
# Removes installed agents, commands, skills, and statusline

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

CLAUDE_DIR="$HOME/.claude"
DRY_RUN=false
FORCE=false

print_status() { echo -e "${BLUE}→${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

show_help() {
    echo "Claude Code Tools Uninstaller"
    echo
    echo "Usage: ./uninstall.sh [options]"
    echo
    echo "Options:"
    echo "  --dry-run    Preview what would be removed without deleting"
    echo "  --force      Skip confirmation prompt"
    echo "  -h, --help   Show this help message"
    echo
}

# Agents to remove
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

# Commands to remove
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
        --force|-f)
            FORCE=true
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
echo -e "${BOLD}Claude Code Tools Uninstaller${NC}"
echo "=============================="
echo

if [ ! -d "$CLAUDE_DIR" ]; then
    print_error "Claude Code directory not found at $CLAUDE_DIR"
    exit 1
fi

# Count what will be removed
agent_count=0
command_count=0
skill_count=0
statusline_exists=false

for agent in "${AGENTS[@]}"; do
    [ -f "$CLAUDE_DIR/agents/$agent" ] && ((agent_count++))
done

for cmd in "${COMMANDS[@]}"; do
    [ -f "$CLAUDE_DIR/commands/$cmd" ] && ((command_count++))
done

[ -d "$CLAUDE_DIR/skills/linear" ] && skill_count=1
[ -f "$CLAUDE_DIR/flying-dutchman-statusline.sh" ] && statusline_exists=true

total=$((agent_count + command_count + skill_count))
[ "$statusline_exists" = true ] && ((total++))

if [ $total -eq 0 ]; then
    print_warning "No Claude Code Tools found to uninstall"
    exit 0
fi

# Show what will be removed
echo "Found:"
[ $agent_count -gt 0 ] && echo "  • $agent_count agents"
[ $command_count -gt 0 ] && echo "  • $command_count commands"
[ $skill_count -gt 0 ] && echo "  • $skill_count skill (Linear)"
[ "$statusline_exists" = true ] && echo "  • Flying Dutchman statusline"
echo

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN - No files will be deleted"
    echo
fi

# Confirmation
if [ "$FORCE" = false ] && [ "$DRY_RUN" = false ]; then
    read -p "Remove these tools? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Cancelled"
        exit 0
    fi
    echo
fi

# Remove agents
if [ $agent_count -gt 0 ]; then
    print_status "Removing agents..."
    for agent in "${AGENTS[@]}"; do
        if [ -f "$CLAUDE_DIR/agents/$agent" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "  Would remove: agents/$agent"
            else
                rm -f "$CLAUDE_DIR/agents/$agent"
                echo "  Removed: agents/$agent"
            fi
        fi
    done
fi

# Remove commands
if [ $command_count -gt 0 ]; then
    print_status "Removing commands..."
    for cmd in "${COMMANDS[@]}"; do
        if [ -f "$CLAUDE_DIR/commands/$cmd" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "  Would remove: commands/$cmd"
            else
                rm -f "$CLAUDE_DIR/commands/$cmd"
                echo "  Removed: commands/$cmd"
            fi
        fi
    done
fi

# Remove skills
if [ $skill_count -gt 0 ]; then
    print_status "Removing skills..."
    if [ "$DRY_RUN" = true ]; then
        echo "  Would remove: skills/linear/"
    else
        rm -rf "$CLAUDE_DIR/skills/linear"
        echo "  Removed: skills/linear/"
    fi
fi

# Remove statusline
if [ "$statusline_exists" = true ]; then
    print_status "Removing statusline..."
    if [ "$DRY_RUN" = true ]; then
        echo "  Would remove: flying-dutchman-statusline.sh"
    else
        rm -f "$CLAUDE_DIR/flying-dutchman-statusline.sh"
        echo "  Removed: flying-dutchman-statusline.sh"
    fi
    print_warning "Remember to remove 'statusline' from ~/.claude/settings.json"
fi

echo
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN complete - no files were deleted"
else
    print_success "Uninstall complete"
fi
echo
