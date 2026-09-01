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

# settings.json is cleaned up independently of whether the scripts it addresses
# are still on disk. Claude Code reads settings.json, not the filesystem, so a
# stale entry keeps failing on every turn long after the file it names is gone
# -- and an install predating that cleanup, uninstalled by the older script,
# lands in exactly that state. Both helpers below are no-ops unless settings.json
# still addresses something this repo installs, so they are safe to always run.

# True when settings.json still points its statusLine at the script we install.
statusline_setting_present() {
    local settings_file="$CLAUDE_DIR/settings.json"

    [ -f "$settings_file" ] || return 1

    if command -v jq >/dev/null 2>&1; then
        jq -e '(.statusLine.command // "") | test("flying-dutchman-statusline\\.sh")' \
            "$settings_file" >/dev/null 2>&1
    else
        grep -q 'flying-dutchman-statusline\.sh' "$settings_file" 2>/dev/null
    fi
}

# Drop the statusLine block from settings.json, but only when it still points at
# the script we installed. A statusLine the user pointed elsewhere is left alone.
remove_statusline_setting() {
    local settings_file="$CLAUDE_DIR/settings.json"

    [ -f "$settings_file" ] || return 0

    if ! command -v jq >/dev/null 2>&1; then
        if statusline_setting_present; then
            print_warning "Remember to remove 'statusLine' from $settings_file"
        fi
        return
    fi

    if ! statusline_setting_present; then
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  Would remove: statusLine from settings.json"
        return
    fi

    if jq 'del(.statusLine)' "$settings_file" > "${settings_file}.tmp"; then
        mv "${settings_file}.tmp" "$settings_file"
        echo "  Removed: statusLine from settings.json"
    else
        rm -f "${settings_file}.tmp"
        print_warning "Remember to remove 'statusLine' from $settings_file"
    fi
}

# Prune the hook commands addressing our scripts, then any hook group and any
# event array left empty, then .hooks itself. Anything that is not the shape
# Claude Code documents is passed through untouched.
HOOK_SETTINGS_FILTER='
  def prune: .hooks |= map(select((.command // "") | test($p) | not));
  if (.hooks | type) != "object" then .
  else
    .hooks |= (
      with_entries(.value |= (
        if type == "array" then
          map(if (type == "object" and (.hooks | type) == "array") then prune else . end)
          | map(select((.hooks | type) != "array" or (.hooks | length) > 0))
        else . end))
      | with_entries(select((.value | type) != "array" or (.value | length) > 0)))
    | if (.hooks | length) == 0 then del(.hooks) else . end
  end'

# The regex a settings.json command must match to be one of ours. Matching on the
# hooks/<script> path segment rather than the bare filename keeps a user script
# that happens to be called auto-format.sh out of the sweep.
hook_settings_pattern() {
    # Only the shell scripts are hooks. HOOKS also carries hooks/README.md and
    # hooks/hooks.json so pre-fix installs can be cleaned up, and neither is
    # ever named by a settings.json command.
    local pattern=""
    local hook
    for hook in "${HOOKS[@]}"; do
        case "$hook" in
            *.sh) ;;
            *) continue ;;
        esac
        [ -n "$pattern" ] && pattern="$pattern|"
        pattern="$pattern${hook//./\\.}"
    done

    [ -z "$pattern" ] && return 1
    printf 'hooks/(%s)' "$pattern"
}

# Echo the pruned settings.json when it still addresses one of our hook scripts.
# Empty output means there is nothing to clean up, or nothing we can read.
hook_settings_pruned() {
    local settings_file="$CLAUDE_DIR/settings.json"
    local pattern current pruned

    [ -f "$settings_file" ] || return 1
    pattern=$(hook_settings_pattern) || return 1
    command -v jq >/dev/null 2>&1 || return 1

    current=$(jq . "$settings_file" 2>/dev/null) || return 1
    pruned=$(jq --arg p "$pattern" "$HOOK_SETTINGS_FILTER" "$settings_file" 2>/dev/null) || return 1

    [ "$pruned" = "$current" ] && return 1
    printf '%s\n' "$pruned"
}

# True when settings.json still addresses one of the hook scripts we install.
# Falls back to a plain grep so a host without jq can still be warned.
hook_settings_present() {
    local settings_file="$CLAUDE_DIR/settings.json"
    local pattern

    [ -f "$settings_file" ] || return 1
    pattern=$(hook_settings_pattern) || return 1

    if command -v jq >/dev/null 2>&1; then
        hook_settings_pruned >/dev/null
    else
        grep -Eq "$pattern" "$settings_file" 2>/dev/null
    fi
}

# Drop the hook entries from settings.json that address our scripts. Claude Code
# executes every configured hook command, so a settings.json left pointing at a
# removed ~/.claude/hooks/auto-format.sh reports a missing file on every Edit,
# Write and MultiEdit, and the UserPromptSubmit entry does the same on every
# turn. As with statusLine, a hook the user aimed at their own script is left
# alone.
remove_hook_settings() {
    local settings_file="$CLAUDE_DIR/settings.json"
    local pruned

    [ -f "$settings_file" ] || return 0
    hook_settings_pattern >/dev/null || return 0

    if ! command -v jq >/dev/null 2>&1; then
        if hook_settings_present; then
            print_warning "Remember to remove the cct hooks from $settings_file"
        fi
        return
    fi

    if ! pruned=$(hook_settings_pruned); then
        # Either nothing of ours is configured, or settings.json will not parse.
        if ! jq . "$settings_file" >/dev/null 2>&1; then
            print_warning "Remember to remove the cct hooks from $settings_file"
        fi
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "  Would remove: hook entries from settings.json"
        return
    fi

    printf '%s\n' "$pruned" > "${settings_file}.tmp"
    mv "${settings_file}.tmp" "$settings_file"
    echo "  Removed: hook entries from settings.json"
}

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

# The removal list comes from the checkout this script lives in, not from the
# caller's working directory. Resolving it relative to $PWD made
# `bash /path/to/claude-code-tools/uninstall.sh` report a clean uninstall while
# leaving every agent, skill and hook in place.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo
echo -e "${BOLD}Claude Code Tools Uninstaller${NC}"
echo "=============================="
echo

if [ ! -d "$CLAUDE_DIR" ]; then
    print_error "Claude Code directory not found at $CLAUDE_DIR"
    exit 1
fi

# Without the source tree there is nothing to match against, and an empty list
# would look identical to "nothing is installed". Say so instead of exiting 0.
if [ ! -d "$SCRIPT_DIR/agents" ] && [ ! -d "$SCRIPT_DIR/skills" ] && [ ! -d "$SCRIPT_DIR/hooks" ]; then
    print_error "No agents/, skills/ or hooks/ directory found in $SCRIPT_DIR"
    print_error "Run uninstall.sh from a complete claude-code-tools checkout"
    exit 1
fi

AGENTS=()
SKILLS=()
HOOKS=()

if [ -d "$SCRIPT_DIR/agents" ]; then
    for agent_file in "$SCRIPT_DIR"/agents/*.md; do
        [ -f "$agent_file" ] && AGENTS+=("$(basename "$agent_file")")
    done
fi

if [ -d "$SCRIPT_DIR/skills" ]; then
    for skill_dir in "$SCRIPT_DIR"/skills/*; do
        [ -d "$skill_dir" ] && SKILLS+=("$(basename "$skill_dir")")
    done
fi

# Every file under hooks/ stays on the removal list, not just the shell scripts
# install.sh now copies. Installers before that change also dropped README.md
# and hooks.json into $CLAUDE_DIR/hooks/, and only this script can clean them up.
if [ -d "$SCRIPT_DIR/hooks" ]; then
    for hook_file in "$SCRIPT_DIR"/hooks/*; do
        [ -f "$hook_file" ] && HOOKS+=("$(basename "$hook_file")")
    done
fi

# Count what will be removed
agent_count=0
skill_count=0
hook_count=0
statusline_exists=false

for agent in "${AGENTS[@]}"; do
    if [ -f "$CLAUDE_DIR/agents/$agent" ]; then
        agent_count=$((agent_count + 1))
    fi
done

for skill in "${SKILLS[@]}"; do
    if [ -d "$CLAUDE_DIR/skills/$skill" ]; then
        skill_count=$((skill_count + 1))
    fi
done

for hook in "${HOOKS[@]}"; do
    if [ -f "$CLAUDE_DIR/hooks/$hook" ]; then
        hook_count=$((hook_count + 1))
    fi
done

if [ -f "$CLAUDE_DIR/flying-dutchman-statusline.sh" ]; then
    statusline_exists=true
fi

# A settings.json entry outlives the file it names, so it is counted as
# something to remove in its own right. Otherwise a tree whose scripts are
# already gone reports "nothing to uninstall" and leaves Claude Code failing on
# every turn, with no supported way to fix it.
hook_settings_stale=false
statusline_setting_stale=false
hook_settings_present && hook_settings_stale=true
statusline_setting_present && statusline_setting_stale=true

total=$((agent_count + skill_count + hook_count))
if [ "$statusline_exists" = true ]; then
    total=$((total + 1))
fi
if [ "$hook_settings_stale" = true ]; then
    total=$((total + 1))
fi
if [ "$statusline_setting_stale" = true ]; then
    total=$((total + 1))
fi

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
[ "$hook_settings_stale" = true ] && echo "  • hook entries in settings.json"
[ "$statusline_setting_stale" = true ] && echo "  • statusLine in settings.json"
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

# Remove hooks. The settings.json cleanup runs whether or not the scripts were
# still on disk, because the entries break Claude Code on their own.
if [ $hook_count -gt 0 ] || [ "$hook_settings_stale" = true ]; then
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
    remove_hook_settings
fi

# Remove statusline
if [ "$statusline_exists" = true ] || [ "$statusline_setting_stale" = true ]; then
    print_status "Removing statusline..."
    if [ "$statusline_exists" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  Would remove: flying-dutchman-statusline.sh"
        else
            rm -f "$CLAUDE_DIR/flying-dutchman-statusline.sh"
            echo "  Removed: flying-dutchman-statusline.sh"
        fi
    fi
    remove_statusline_setting
fi

echo
if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN complete - no files were deleted"
else
    print_success "Uninstall complete"
fi
echo
