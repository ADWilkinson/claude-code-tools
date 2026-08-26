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

echo "update/uninstall tests passed"
