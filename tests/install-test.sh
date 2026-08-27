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

# Claude Code only reads the statusLine object form; a bare "statusline" string
# is ignored, so the installer must write the schema the app actually parses.
if command -v jq >/dev/null 2>&1; then
    STATUSLINE_DIR="$TEST_DIR/statusline-target"
    mkdir -p "$STATUSLINE_DIR"
    echo '{"model": "opus"}' > "$STATUSLINE_DIR/settings.json"

    (cd "$REPO_DIR" && HOME="$FAKE_HOME" ./install.sh \
        --no-skills \
        --no-hooks \
        --claude-dir "$STATUSLINE_DIR" >/dev/null)

    test -x "$STATUSLINE_DIR/flying-dutchman-statusline.sh"

    if ! jq -e '.statusLine.type == "command"' "$STATUSLINE_DIR/settings.json" >/dev/null; then
        echo "install did not write a statusLine command entry" >&2
        exit 1
    fi
    if ! jq -e --arg dest "$STATUSLINE_DIR/flying-dutchman-statusline.sh" \
         '.statusLine.command == $dest' "$STATUSLINE_DIR/settings.json" >/dev/null; then
        echo "statusLine.command does not point at the installed script" >&2
        exit 1
    fi
    if jq -e 'has("statusline")' "$STATUSLINE_DIR/settings.json" >/dev/null; then
        echo "install wrote the legacy lowercase statusline key" >&2
        exit 1
    fi
    # Unrelated settings must survive the rewrite.
    if ! jq -e '.model == "opus"' "$STATUSLINE_DIR/settings.json" >/dev/null; then
        echo "install clobbered unrelated settings.json keys" >&2
        exit 1
    fi

    # A fresh install with no settings.json must still end up configured.
    FRESH_SETTINGS_DIR="$TEST_DIR/statusline-fresh"
    (cd "$REPO_DIR" && HOME="$FAKE_HOME" ./install.sh \
        --no-skills \
        --no-hooks \
        --claude-dir "$FRESH_SETTINGS_DIR" >/dev/null)

    if ! jq -e --arg dest "$FRESH_SETTINGS_DIR/flying-dutchman-statusline.sh" \
         '.statusLine.command == $dest' "$FRESH_SETTINGS_DIR/settings.json" >/dev/null; then
        echo "install did not create settings.json with a statusLine entry" >&2
        exit 1
    fi
fi

echo "install tests passed"
