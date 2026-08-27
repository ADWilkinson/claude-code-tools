#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

UPDATE_DIR="$TEST_DIR/update-target"
UNINSTALL_DIR="$TEST_DIR/uninstall-target"
AGENT_NAME="backend-developer.md"

mkdir -p "$UPDATE_DIR/agents" "$UNINSTALL_DIR/agents"
cp "$REPO_DIR/agents/$AGENT_NAME" "$UPDATE_DIR/agents/$AGENT_NAME"
cp "$REPO_DIR/agents/$AGENT_NAME" "$UNINSTALL_DIR/agents/$AGENT_NAME"

update_output=$(cd "$REPO_DIR" && ./update.sh --dry-run -v --claude-dir "$UPDATE_DIR")

grep -Fq "DRY RUN - No files will be modified" <<< "$update_output"
grep -Fq "Updating agents..." <<< "$update_output"
grep -Fq "DRY RUN complete - no files were modified" <<< "$update_output"
grep -Fq "Would update: $UPDATE_DIR/agents/$AGENT_NAME" <<< "$update_output"

# An installed agent must keep its on-disk contents during a dry run.
if ! cmp -s "$REPO_DIR/agents/$AGENT_NAME" "$UPDATE_DIR/agents/$AGENT_NAME"; then
    echo "update dry-run modified an installed agent" >&2
    exit 1
fi

# update.sh refreshes what is installed; it must never add components the user
# declined at install time (./install.sh --skills-only leaves no agents/ dir).
SKILLS_ONLY_DIR="$TEST_DIR/skills-only-target"
mkdir -p "$SKILLS_ONLY_DIR/skills"

skills_only_output=$(cd "$REPO_DIR" && ./update.sh -v --claude-dir "$SKILLS_ONLY_DIR")

grep -Fq "Agents directory not found, skipping" <<< "$skills_only_output"
if [ -e "$SKILLS_ONLY_DIR/agents" ]; then
    echo "update created an agents directory that was never installed" >&2
    exit 1
fi

# An agent the user deleted on purpose must not be resurrected by an update.
PARTIAL_DIR="$TEST_DIR/partial-target"
OTHER_AGENT="debugger.md"
mkdir -p "$PARTIAL_DIR/agents"
cp "$REPO_DIR/agents/$AGENT_NAME" "$PARTIAL_DIR/agents/$AGENT_NAME"

partial_output=$(cd "$REPO_DIR" && ./update.sh -v --claude-dir "$PARTIAL_DIR")

grep -Fq "Agent not installed, skipping: $OTHER_AGENT" <<< "$partial_output"
if [ -e "$PARTIAL_DIR/agents/$OTHER_AGENT" ]; then
    echo "update installed an agent that was not present" >&2
    exit 1
fi
if [ ! -f "$PARTIAL_DIR/agents/$AGENT_NAME" ]; then
    echo "update removed an installed agent" >&2
    exit 1
fi

uninstall_output=$(cd "$REPO_DIR" && ./uninstall.sh --dry-run --claude-dir "$UNINSTALL_DIR")

grep -Fq "DRY RUN - No files will be deleted" <<< "$uninstall_output"
grep -Fq "Would remove: agents/$AGENT_NAME" <<< "$uninstall_output"
grep -Fq "DRY RUN complete - no files were deleted" <<< "$uninstall_output"
if [ ! -f "$UNINSTALL_DIR/agents/$AGENT_NAME" ]; then
    echo "uninstall dry-run deleted the destination agent" >&2
    exit 1
fi

# Uninstall must clear the statusLine entry it installed, or Claude Code keeps
# invoking a script that is no longer on disk.
if command -v jq >/dev/null 2>&1; then
    STATUSLINE_DIR="$TEST_DIR/statusline-uninstall"
    mkdir -p "$STATUSLINE_DIR"
    touch "$STATUSLINE_DIR/flying-dutchman-statusline.sh"
    jq -n --arg dest "$STATUSLINE_DIR/flying-dutchman-statusline.sh" \
        '{model: "opus", statusLine: {type: "command", command: $dest}}' \
        > "$STATUSLINE_DIR/settings.json"

    statusline_dry_output=$(cd "$REPO_DIR" && ./uninstall.sh --dry-run --force \
        --claude-dir "$STATUSLINE_DIR")

    grep -Fq "Would remove: statusLine from settings.json" <<< "$statusline_dry_output"
    if ! jq -e 'has("statusLine")' "$STATUSLINE_DIR/settings.json" >/dev/null; then
        echo "uninstall dry-run edited settings.json" >&2
        exit 1
    fi

    (cd "$REPO_DIR" && ./uninstall.sh --force --claude-dir "$STATUSLINE_DIR" >/dev/null)

    if jq -e 'has("statusLine")' "$STATUSLINE_DIR/settings.json" >/dev/null; then
        echo "uninstall left a statusLine pointing at a deleted script" >&2
        exit 1
    fi
    if ! jq -e '.model == "opus"' "$STATUSLINE_DIR/settings.json" >/dev/null; then
        echo "uninstall clobbered unrelated settings.json keys" >&2
        exit 1
    fi

    # A statusLine the user pointed at their own script is not ours to remove.
    FOREIGN_DIR="$TEST_DIR/statusline-foreign"
    mkdir -p "$FOREIGN_DIR"
    touch "$FOREIGN_DIR/flying-dutchman-statusline.sh"
    jq -n '{statusLine: {type: "command", command: "~/my-own-statusline.sh"}}' \
        > "$FOREIGN_DIR/settings.json"

    (cd "$REPO_DIR" && ./uninstall.sh --force --claude-dir "$FOREIGN_DIR" >/dev/null)

    if ! jq -e '.statusLine.command == "~/my-own-statusline.sh"' \
         "$FOREIGN_DIR/settings.json" >/dev/null; then
        echo "uninstall removed a statusLine it did not install" >&2
        exit 1
    fi
fi

# uninstall.sh must remove what it installed no matter where it is called from.
# Building the removal list from $PWD made an out-of-tree invocation print
# "Uninstall complete" while leaving every agent and hook on disk.
CWD_DIR="$TEST_DIR/uninstall-from-elsewhere"
HOOK_NAME="auto-format.sh"
mkdir -p "$CWD_DIR/agents" "$CWD_DIR/hooks"
cp "$REPO_DIR/agents/$AGENT_NAME" "$CWD_DIR/agents/$AGENT_NAME"
cp "$REPO_DIR/hooks/$HOOK_NAME" "$CWD_DIR/hooks/$HOOK_NAME"

(cd "$TEST_DIR" && "$REPO_DIR/uninstall.sh" --force --claude-dir "$CWD_DIR" >/dev/null)

if [ -e "$CWD_DIR/agents/$AGENT_NAME" ]; then
    echo "uninstall run outside the repo left an agent installed" >&2
    exit 1
fi
if [ -e "$CWD_DIR/hooks/$HOOK_NAME" ]; then
    echo "uninstall run outside the repo left a hook installed" >&2
    exit 1
fi

# A copy of the script with no source tree beside it cannot know what to remove.
# It must say so rather than exit 0 on an empty list.
DETACHED_DIR="$TEST_DIR/detached"
DETACHED_TARGET="$TEST_DIR/detached-target"
mkdir -p "$DETACHED_DIR" "$DETACHED_TARGET/agents"
cp "$REPO_DIR/uninstall.sh" "$DETACHED_DIR/uninstall.sh"
cp "$REPO_DIR/agents/$AGENT_NAME" "$DETACHED_TARGET/agents/$AGENT_NAME"

detached_status=0
detached_output=$("$DETACHED_DIR/uninstall.sh" --force --claude-dir "$DETACHED_TARGET" 2>&1) \
    || detached_status=$?

if [ "$detached_status" -eq 0 ]; then
    echo "detached uninstall reported success with no source tree" >&2
    exit 1
fi
grep -Fq "Run uninstall.sh from a complete claude-code-tools checkout" <<< "$detached_output"
if [ ! -f "$DETACHED_TARGET/agents/$AGENT_NAME" ]; then
    echo "detached uninstall deleted files it could not identify" >&2
    exit 1
fi

echo "update/uninstall tests passed"
