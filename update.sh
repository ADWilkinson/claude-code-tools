#!/bin/bash

# Claude Code Tools Update Script
# Author: Andrew Wilkinson (github.com/ADWilkinson)
# Updates installed tools to the latest version

set -e
set -o pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

REPO_OWNER="ADWilkinson"
REPO_NAME="claude-code-tools"
REPO_BRANCH="main"
REPO_RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"
REPO_API_BASE="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents"
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
    echo "  --claude-dir DIR    Custom Claude directory (default: ~/.claude)"
    echo "  --dry-run           Preview what would be updated"
    echo "  -v, --verbose       Verbose output"
    echo "  -h, --help          Show this help message"
    echo
}

DEFAULT_AGENTS=(
    "backend-developer.md"
    "blockchain-specialist.md"
    "database-manager.md"
    "debugger.md"
    "devops-engineer.md"
    "extension-developer.md"
    "firebase-specialist.md"
    "frontend-developer.md"
    "indexer-developer.md"
    "mcp-developer.md"
    "mobile-developer.md"
    "performance-engineer.md"
    "refactoring-specialist.md"
    "testing-specialist.md"
)

DEFAULT_COMMANDS=(
    "deslop.md"
    "generate-precommit-hooks.md"
    "lighthouse.md"
    "minimize-ui.md"
    "repo-polish.md"
    "update-claudes.md"
    "xml.md"
)

DEFAULT_SKILLS=(
    "clarify-before-implementing"
    "linear"
    "verify-changes"
)

DEFAULT_HOOKS=(
    "auto-format.sh"
    "constraint-persistence.sh"
)

fetch_repo_list() {
    local path="$1"
    local type="$2"

    if command -v python3 >/dev/null 2>&1; then
        curl -sf "${REPO_API_BASE}/${path}" 2>/dev/null | python3 -c 'import json,sys; data=json.load(sys.stdin); want=sys.argv[1] if len(sys.argv)>1 else "file"; import sys as _sys; isinstance(data,list) or _sys.exit(1); [print(item.get("name")) for item in data if item.get("type")==want and item.get("name")]' "$type" || return 1
    elif command -v jq >/dev/null 2>&1; then
        curl -sf "${REPO_API_BASE}/${path}" 2>/dev/null | jq -r ".[] | select(.type==\"${type}\") | .name" || return 1
    else
        return 1
    fi
}

download_file() {
    local url="$1"
    local dest="$2"

    if [ "$DRY_RUN" = true ]; then
        print_verbose "Would update: $dest"
        updated=$((updated + 1))
        return 0
    fi

    mkdir -p "$(dirname "$dest")"
    if curl -sf "$url" -o "$dest" 2>/dev/null; then
        print_verbose "Updated: $dest"
        updated=$((updated + 1))
        return 0
    fi

    print_verbose "Failed: $dest"
    failed=$((failed + 1))
    return 1
}

update_skill() {
    local skill="$1"
    local skill_dir="$CLAUDE_DIR/skills/$skill"

    if [ ! -d "$skill_dir" ]; then
        print_verbose "Skill not installed, skipping: $skill"
        return 0
    fi

    local root_files
    local subdirs

    root_files=$(fetch_repo_list "skills/$skill" "file" 2>/dev/null || true)
    if [ -z "$root_files" ]; then
        root_files="SKILL.md"
    fi

    local IFS=$'\n'
    for file in $root_files; do
        [ -z "$file" ] && continue
        download_file "$REPO_RAW_BASE/skills/$skill/$file" "$skill_dir/$file"
        if [ "$file" = "install.sh" ] && [ "$DRY_RUN" = false ]; then
            chmod +x "$skill_dir/$file"
        fi
    done

    subdirs=$(fetch_repo_list "skills/$skill" "dir" 2>/dev/null || true)
    if [ -n "$subdirs" ]; then
        for subdir in $subdirs; do
            [ -z "$subdir" ] && continue
            local sub_files
            sub_files=$(fetch_repo_list "skills/$skill/$subdir" "file" 2>/dev/null || true)
            if [ -n "$sub_files" ]; then
                for file in $sub_files; do
                    [ -z "$file" ] && continue
                    download_file "$REPO_RAW_BASE/skills/$skill/$subdir/$file" "$skill_dir/$subdir/$file"
                done
            fi
        done
    fi

    if [ "$DRY_RUN" = false ] && [ -f "$skill_dir/package.json" ]; then
        # Detect available package manager
        if command -v bun >/dev/null 2>&1; then
            PM="bun install"
        elif command -v pnpm >/dev/null 2>&1; then
            PM="pnpm install"
        elif command -v yarn >/dev/null 2>&1; then
            PM="yarn install"
        elif command -v npm >/dev/null 2>&1; then
            PM="npm install"
        else
            PM=""
        fi
        if [ -n "$PM" ]; then
            print_verbose "Updating dependencies for skill: $skill (using ${PM%% *})"
            (cd "$skill_dir" && $PM --silent 2>/dev/null) || true
        fi
    fi
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

CLAUDE_DIR="${CLAUDE_DIR/#\~/$HOME}"

AGENTS_RAW=$(fetch_repo_list "agents" "file" 2>/dev/null || true)
COMMANDS_RAW=$(fetch_repo_list "commands" "file" 2>/dev/null || true)
SKILLS_RAW=$(fetch_repo_list "skills" "dir" 2>/dev/null || true)
HOOKS_RAW=$(fetch_repo_list "hooks" "file" 2>/dev/null || true)

if [ -n "$AGENTS_RAW" ]; then
    IFS=$'\n' AGENTS=($AGENTS_RAW)
else
    AGENTS=("${DEFAULT_AGENTS[@]}")
fi

if [ -n "$COMMANDS_RAW" ]; then
    IFS=$'\n' COMMANDS=($COMMANDS_RAW)
else
    COMMANDS=("${DEFAULT_COMMANDS[@]}")
fi

if [ -n "$SKILLS_RAW" ]; then
    IFS=$'\n' SKILLS=($SKILLS_RAW)
else
    SKILLS=("${DEFAULT_SKILLS[@]}")
fi

if [ -n "$HOOKS_RAW" ]; then
    IFS=$'\n' HOOKS=($HOOKS_RAW)
else
    HOOKS=("${DEFAULT_HOOKS[@]}")
fi

unset IFS

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
    [ -z "$agent" ] && continue
    download_file "$REPO_RAW_BASE/agents/$agent" "$CLAUDE_DIR/agents/$agent"
done
print_success "Agents: ${#AGENTS[@]} files"

# Update commands
print_status "Updating commands..."
mkdir -p "$CLAUDE_DIR/commands"
for cmd in "${COMMANDS[@]}"; do
    [ -z "$cmd" ] && continue
    download_file "$REPO_RAW_BASE/commands/$cmd" "$CLAUDE_DIR/commands/$cmd"
done
print_success "Commands: ${#COMMANDS[@]} files"

# Update skills (only if installed)
print_status "Updating skills..."
if [ -d "$CLAUDE_DIR/skills" ]; then
    for skill in "${SKILLS[@]}"; do
        [ -z "$skill" ] && continue
        update_skill "$skill"
    done
else
    print_verbose "Skills directory not found, skipping"
fi
print_success "Skills: ${#SKILLS[@]} listed"

# Update hooks (only if installed)
print_status "Updating hooks..."
if [ -d "$CLAUDE_DIR/hooks" ]; then
    for hook in "${HOOKS[@]}"; do
        [ -z "$hook" ] && continue
        if [ -f "$CLAUDE_DIR/hooks/$hook" ]; then
            download_file "$REPO_RAW_BASE/hooks/$hook" "$CLAUDE_DIR/hooks/$hook"
            if [ "$DRY_RUN" = false ]; then
                chmod +x "$CLAUDE_DIR/hooks/$hook" || true
            fi
        else
            print_verbose "Hook not installed, skipping: $hook"
        fi
    done
else
    print_verbose "Hooks directory not found, skipping"
fi
print_success "Hooks: ${#HOOKS[@]} listed"

# Update statusline (only if installed)
print_status "Updating statusline..."
if [ -f "$CLAUDE_DIR/flying-dutchman-statusline.sh" ]; then
    download_file "$REPO_RAW_BASE/statusline/flying-dutchman-statusline.sh" "$CLAUDE_DIR/flying-dutchman-statusline.sh"
    if [ "$DRY_RUN" = false ]; then
        chmod +x "$CLAUDE_DIR/flying-dutchman-statusline.sh"
    fi
    print_success "Statusline: 1 file"
else
    print_verbose "Statusline not installed, skipping"
    print_success "Statusline: 0 files"
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
