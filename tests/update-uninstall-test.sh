#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

UPDATE_DIR="$TEST_DIR/update-target"
UNINSTALL_DIR="$TEST_DIR/uninstall-target"
AGENT_NAME="backend-developer.md"

mkdir -p "$UPDATE_DIR/agents" "$UNINSTALL_DIR/agents"
cp "$REPO_DIR/agents/$AGENT_NAME" "$UNINSTALL_DIR/agents/$AGENT_NAME"

update_output=$(cd "$REPO_DIR" && ./update.sh --dry-run --claude-dir "$UPDATE_DIR")

grep -Fq "DRY RUN - No files will be modified" <<< "$update_output"
grep -Fq "Updating agents..." <<< "$update_output"
grep -Fq "DRY RUN complete - no files were modified" <<< "$update_output"
if [ -e "$UPDATE_DIR/agents/$AGENT_NAME" ]; then
    echo "update dry-run wrote an agent into the destination" >&2
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
