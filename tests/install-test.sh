#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

FAKE_HOME="$TEST_DIR/home"
DETECTED_DIR="$FAKE_HOME/.claude"
CUSTOM_DIR="$TEST_DIR/custom"
MISSING_DIR="$TEST_DIR/missing"

mkdir -p "$DETECTED_DIR" "$CUSTOM_DIR"

explicit_output=$(cd "$REPO_DIR" && HOME="$FAKE_HOME" ./install.sh \
    --dry-run \
    --agents-only \
    --claude-dir "$CUSTOM_DIR")

grep -Fq "Using custom directory at $CUSTOM_DIR" <<< "$explicit_output"
grep -Fq "Would create directories: $CUSTOM_DIR/agents" <<< "$explicit_output"
if grep -Fq "$DETECTED_DIR/agents" <<< "$explicit_output"; then
    echo "explicit --claude-dir was replaced by auto-detection" >&2
    exit 1
fi

missing_output=$(cd "$REPO_DIR" && HOME="$FAKE_HOME" ./install.sh \
    --dry-run \
    --agents-only \
    --claude-dir "$MISSING_DIR")

grep -Fq "Would create directory at $MISSING_DIR" <<< "$missing_output"
if [ -e "$MISSING_DIR" ]; then
    echo "dry-run created the custom destination" >&2
    exit 1
fi

FRESH_HOME="$TEST_DIR/fresh-home"
mkdir -p "$FRESH_HOME"

fallback_output=$(cd "$REPO_DIR" && HOME="$FRESH_HOME" ./install.sh \
    --dry-run \
    --agents-only)

grep -Fq "Would create directory at $FRESH_HOME/.claude" <<< "$fallback_output"
if [ -e "$FRESH_HOME/.claude" ]; then
    echo "dry-run created the fallback destination" >&2
    exit 1
fi

INSTALL_DIR="$TEST_DIR/installed"
(cd "$REPO_DIR" && HOME="$FAKE_HOME" ./install.sh \
    --agents-only \
    --claude-dir "$INSTALL_DIR" >/dev/null)

test -f "$INSTALL_DIR/agents/backend-developer.md"
if [ -e "$DETECTED_DIR/agents/backend-developer.md" ]; then
    echo "install wrote to the auto-detected directory" >&2
    exit 1
fi

echo "install tests passed"
