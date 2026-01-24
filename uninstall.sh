#!/bin/bash

# Claude Code Tools Uninstall Script
# Author: Andrew Wilkinson (github.com/ADWilkinson)
# Removes installed agents, commands, skills, hooks, and statusline

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
    echo "  --claude-dir DIR    Custom Claude directory (default: ~/.claude)"
    echo "  --dry-run           Preview what would be removed without deleting"
    echo "  --force             Skip confirmation prompt"
    echo "  -h, --help          Show this help message"
    echo
}

# Parse arguments
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

CLAUDE_DIR="${CLAUDE_DIR/#\~/$HOME}"

echo
echo -e "${BOLD}Claude Code Tools Uninstaller${NC}"
echo "=============================="
echo

if [ ! -d "$CLAUDE_DIR" ]; then
    print_error "Claude Code directory not found at $CLAUDE_DIR"
    exit 1
fi

AGENTS=()
SKILLS=()
HOOKS=()

if [ -d "agents" ]; then
    for agent_file in agents/*.md; do
        [ -f "$agent_file" ] && AGENTS+=("$(basename "$agent_file")")
    done
fi

if [ -d "skills" ]; then
    for skill_dir in skills/*; do
        [ -d "$skill_dir" ] && SKILLS+=("$(basename "$skill_dir")")
    done
fi

if [ -d "hooks" ]; then
    for hook_file in hooks/*; do
        [ -f "$hook_file" ] && HOOKS+=("$(basename "$hook_file")")
    done
fi

# Count what will be removed
agent_count=0
skill_count=0
hook_count=0
statusline_exists=false

for agent in "${AGENTS[@]}"; do
    [ -f "$CLAUDE_DIR/agents/$agent" ] && ((agent_count++))
done

for skill in "${SKILLS[@]}"; do
    [ -d "$CLAUDE_DIR/skills/$skill" ] && ((skill_count++))
done

for hook in "${HOOKS[@]}"; do
    [ -f "$CLAUDE_DIR/hooks/$hook" ] && ((hook_count++))
done

[ -f "$CLAUDE_DIR/flying-dutchman-statusline.sh" ] && statusline_exists=true

total=$((agent_count + skill_count + hook_count))
[ "$statusline_exists" = true ] && ((total++))

if [ $total -eq 0 ]; then
    print_warning "No Claude Code Tools found to uninstall"
    exit 0
fi

# Show what will be removed
echo "Found:"
[ $agent_count -gt 0 ] && echo "  • $agent_count agents"
[ $skill_count -gt 0 ] && echo "  • $skill_count skills"
[ $hook_count -gt 0 ] && echo "  • $hook_count hooks"
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

# Remove skills
if [ $skill_count -gt 0 ]; then
    print_status "Removing skills..."
    for skill in "${SKILLS[@]}"; do
        if [ -d "$CLAUDE_DIR/skills/$skill" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "  Would remove: skills/$skill/"
            else
                rm -rf "$CLAUDE_DIR/skills/$skill"
                echo "  Removed: skills/$skill/"
            fi
        fi
    done
fi

# Remove hooks
if [ $hook_count -gt 0 ]; then
    print_status "Removing hooks..."
    for hook in "${HOOKS[@]}"; do
        if [ -f "$CLAUDE_DIR/hooks/$hook" ]; then
            if [ "$DRY_RUN" = true ]; then
                echo "  Would remove: hooks/$hook"
            else
                rm -f "$CLAUDE_DIR/hooks/$hook"
                echo "  Removed: hooks/$hook"
            fi
        fi
    done
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
    print_warning "Remember to remove 'statusline' from $CLAUDE_DIR/settings.json"
fi

echo
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN complete - no files were deleted"
else
    print_success "Uninstall complete"
fi
echo
