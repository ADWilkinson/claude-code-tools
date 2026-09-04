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
REPO_TREE_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/trees/${REPO_BRANCH}?recursive=1"
CLAUDE_DIR="$HOME/.claude"
DRY_RUN=false
VERBOSE=false
# Blob paths from one git trees request. Empty means the listing failed and the
# DEFAULT_* lists plus the SKILL.md-only fallback apply.
TREE_PATHS=""

print_status() { echo -e "${BLUE}→${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo -e "  $1"
    fi
}

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

DEFAULT_SKILLS=(
    "clarify-before-implementing"
    "deslop"
    "design-audit"
    "generate-precommit-hooks"
    "lighthouse"
    "linear"
    "minimize-ui"
    "repo-polish"
    "update-claudes"
    "verify-changes"
    "xml"
)

DEFAULT_HOOKS=(
    "auto-format.sh"
    "constraint-persistence.sh"
)

# One request lists every blob. The contents API needs a call per directory and
# a current run spends 26 of the 60 unauthenticated requests allowed per hour,
# so the ordinary failure is a mid-walk 403 while raw.githubusercontent.com
# still serves. Trees and contents share that quota, so a trees miss falls
# through to the DEFAULT lists rather than walking contents.
fetch_repo_tree() {
    local payload

    payload=$(curl -sf "$REPO_TREE_URL" 2>/dev/null) || return 1

    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json,sys
data=json.load(sys.stdin)
if not isinstance(data, dict) or data.get("truncated") is True:
    sys.exit(1)
tree=data.get("tree")
if not isinstance(tree, list):
    sys.exit(1)
for item in tree:
    path=item.get("path")
    if item.get("type")=="blob" and path:
        print(path)
' <<< "$payload" || return 1
    elif command -v jq >/dev/null 2>&1; then
        echo "$payload" | jq -e '.truncated != true and (.tree | type == "array")' >/dev/null || return 1
        echo "$payload" | jq -r '.tree[] | select(.type=="blob" and .path) | .path' || return 1
    else
        return 1
    fi
}

# Print files a skill ships, relative to skills/<name>/, from TREE_PATHS.
skill_files_from_tree() {
    local skill="$1"
    local prefix="skills/${skill}/"
    local path

    while IFS= read -r path; do
        [ -z "$path" ] && continue
        case "$path" in
            "$prefix"*)
                printf '%s\n' "${path#"$prefix"}"
                ;;
        esac
    done <<< "$TREE_PATHS"
}

list_contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

# Returns non-zero on a failed download and counts it in $failed. Callers must
# tolerate that status: under `set -e` a bare call aborted the whole updater on
# the first 404 or network blip, so every later agent, skill, hook and the
# statusline were skipped, the summary never printed, and without -v the run
# ended silently on exit 1.
#
# The download lands in a temporary file and is moved into place only once curl
# reports success. Writing straight to $dest let a connection dropped mid-body
# (curl exit 18) leave the installed agent, skill, hook or statusline holding a
# truncated copy of itself; the run still reported "complete with errors" while
# the hooks and statusline were chmod +x'd and executed on every tool call.
download_file() {
    local url="$1"
    local dest="$2"

    if [ "$DRY_RUN" = true ]; then
        print_verbose "Would update: $dest"
        updated=$((updated + 1))
        return 0
    fi

    mkdir -p "$(dirname "$dest")"

    local tmp
    if ! tmp=$(mktemp "$dest.download.XXXXXX" 2>/dev/null); then
        print_verbose "Failed: $dest"
        failed=$((failed + 1))
        return 1
    fi

    # Seed the temporary file from the copy already installed so the replacement
    # keeps its mode; mktemp alone would hand every updated file 0600.
    if [ -f "$dest" ]; then
        cp -p "$dest" "$tmp" 2>/dev/null || true
    fi

    if curl -sf "$url" -o "$tmp" 2>/dev/null && mv "$tmp" "$dest"; then
        print_verbose "Updated: $dest"
        updated=$((updated + 1))
        return 0
    fi

    rm -f "$tmp"
    print_verbose "Failed: $dest"
    failed=$((failed + 1))
    return 1
}

# A skill is more than its SKILL.md: skills/linear also ships install.sh and the
# scripts/linear.ts the skill executes, including files more than one directory
# deep. Which files those are is known from the git tree. When that listing is
# missing the fallback narrows the skill to SKILL.md alone: the run refreshes
# the documentation, leaves the executable stale, and must not look like a
# clean success. Record the skill instead so the summary says the update was
# partial and names what to re-run.
update_skill() {
    local skill="$1"
    local skill_dir="$CLAUDE_DIR/skills/$skill"

    if [ ! -d "$skill_dir" ]; then
        print_verbose "Skill not installed, skipping: $skill"
        return 0
    fi

    local files
    local listed=true

    if [ -n "$TREE_PATHS" ]; then
        files=$(skill_files_from_tree "$skill")
        if [ -z "$files" ]; then
            listed=false
            files="SKILL.md"
        fi
    else
        listed=false
        files="SKILL.md"
    fi

    local IFS=$'\n'
    for file in $files; do
        [ -z "$file" ] && continue
        download_file "$REPO_RAW_BASE/skills/$skill/$file" "$skill_dir/$file" || continue
        if [ "$file" = "install.sh" ] && [ "$DRY_RUN" = false ]; then
            chmod +x "$skill_dir/$file"
        fi
    done

    if [ "$listed" = false ]; then
        print_verbose "Partial: $skill (could not list its files, refreshed SKILL.md only)"
        INCOMPLETE_SKILLS+=("$skill")
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

TREE_PATHS=$(fetch_repo_tree 2>/dev/null || true)

AGENTS=()
SKILLS=()
HOOKS=()

if [ -n "$TREE_PATHS" ]; then
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        case "$path" in
            agents/*.md)
                name="${path#agents/}"
                case "$name" in
                    */*) ;;
                    *) AGENTS+=("$name") ;;
                esac
                ;;
            skills/*/*)
                name="${path#skills/}"
                skill="${name%%/*}"
                if [ -n "$skill" ]; then
                    if [ ${#SKILLS[@]} -eq 0 ] || ! list_contains "$skill" "${SKILLS[@]}"; then
                        SKILLS+=("$skill")
                    fi
                fi
                ;;
            hooks/*.sh)
                name="${path#hooks/}"
                case "$name" in
                    */*) ;;
                    *) HOOKS+=("$name") ;;
                esac
                ;;
        esac
    done <<< "$TREE_PATHS"
fi

# A successful tree can legitimately list no agents (or no skills, or no
# hooks). Only fall back when the listing itself failed.
if [ -z "$TREE_PATHS" ]; then
    AGENTS=("${DEFAULT_AGENTS[@]}")
    SKILLS=("${DEFAULT_SKILLS[@]}")
    # hooks/ also holds README.md and hooks.json, which are documentation and a
    # settings.json template rather than hooks. The DEFAULT list is already the
    # shell scripts, matching the filter applied when the tree is reachable.
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
# Skills whose file listing could not be read, so only SKILL.md was refreshed.
INCOMPLETE_SKILLS=()

# Update agents (only if installed)
print_status "Updating agents..."
if [ -d "$CLAUDE_DIR/agents" ]; then
    for agent in "${AGENTS[@]}"; do
        [ -z "$agent" ] && continue
        if [ -f "$CLAUDE_DIR/agents/$agent" ]; then
            download_file "$REPO_RAW_BASE/agents/$agent" "$CLAUDE_DIR/agents/$agent" || true
        else
            print_verbose "Agent not installed, skipping: $agent"
        fi
    done
else
    print_verbose "Agents directory not found, skipping"
fi
print_success "Agents: ${#AGENTS[@]} listed"

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
            download_file "$REPO_RAW_BASE/hooks/$hook" "$CLAUDE_DIR/hooks/$hook" || true
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
    download_file "$REPO_RAW_BASE/statusline/flying-dutchman-statusline.sh" "$CLAUDE_DIR/flying-dutchman-statusline.sh" || true
    if [ "$DRY_RUN" = false ]; then
        chmod +x "$CLAUDE_DIR/flying-dutchman-statusline.sh"
    fi
    print_success "Statusline: 1 file"
else
    print_verbose "Statusline not installed, skipping"
    print_success "Statusline: 0 files"
fi

echo
if [ ${#INCOMPLETE_SKILLS[@]} -gt 0 ]; then
    print_warning "Could not list the files for these skills, so only SKILL.md was refreshed: ${INCOMPLETE_SKILLS[*]}"
    print_warning "The GitHub git trees API is rate limited to 60 requests an hour; re-run update.sh later to finish them"
    echo
fi

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN complete - no files were modified"
else
    if [ $failed -eq 0 ] && [ ${#INCOMPLETE_SKILLS[@]} -eq 0 ]; then
        print_success "Update complete ($updated files)"
    elif [ $failed -eq 0 ]; then
        print_warning "Update partially complete ($updated files)"
    else
        print_warning "Update complete with errors ($updated updated, $failed failed)"
    fi
fi
echo
print_status "Restart Claude Code to load updates"
echo
