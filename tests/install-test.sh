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

# install.sh must install the checkout it lives in no matter where it is called
# from. Reading agents/, skills/ and hooks/ from $PWD let an out-of-tree
# invocation copy whatever happened to sit in the caller's directory and still
# print "Installation complete!".
DECOY_DIR="$TEST_DIR/decoy"
OUT_OF_TREE_DIR="$TEST_DIR/out-of-tree-target"
HOOK_NAME="auto-format.sh"
mkdir -p "$DECOY_DIR/agents" "$DECOY_DIR/hooks"
echo "not a real agent" > "$DECOY_DIR/agents/decoy-agent.md"
echo "#!/bin/bash" > "$DECOY_DIR/hooks/decoy-hook.sh"

(cd "$DECOY_DIR" && HOME="$FAKE_HOME" "$REPO_DIR/install.sh" \
    --no-skills \
    --no-statusline \
    --claude-dir "$OUT_OF_TREE_DIR" >/dev/null)

test -f "$OUT_OF_TREE_DIR/agents/backend-developer.md"
test -f "$OUT_OF_TREE_DIR/hooks/$HOOK_NAME"
if [ -e "$OUT_OF_TREE_DIR/agents/decoy-agent.md" ]; then
    echo "install copied an agent from the caller's working directory" >&2
    exit 1
fi
if [ -e "$OUT_OF_TREE_DIR/hooks/decoy-hook.sh" ]; then
    echo "install copied a hook from the caller's working directory" >&2
    exit 1
fi

# hooks/ carries README.md and hooks.json alongside the two hook scripts.
# Installing every file put documentation on the hook path with the exec bit
# set and reported 4 hooks where the plugin manifest declares 2.
HOOKS_ONLY_DIR="$TEST_DIR/hooks-target"

hooks_output=$(cd "$REPO_DIR" && HOME="$FAKE_HOME" ./install.sh \
    --hooks-only \
    --claude-dir "$HOOKS_ONLY_DIR")

test -x "$HOOKS_ONLY_DIR/hooks/auto-format.sh"
test -x "$HOOKS_ONLY_DIR/hooks/constraint-persistence.sh"
if [ -e "$HOOKS_ONLY_DIR/hooks/README.md" ]; then
    echo "install copied hooks/README.md onto the hook path" >&2
    exit 1
fi
if [ -e "$HOOKS_ONLY_DIR/hooks/hooks.json" ]; then
    echo "install copied hooks/hooks.json onto the hook path" >&2
    exit 1
fi

installed_hooks=$(ls -1 "$HOOKS_ONLY_DIR/hooks" | wc -l | tr -d ' ')
declared_hooks=$(ls -1 "$REPO_DIR"/hooks/*.sh | wc -l | tr -d ' ')
if [ "$installed_hooks" != "$declared_hooks" ]; then
    echo "installed $installed_hooks hooks, repo ships $declared_hooks" >&2
    exit 1
fi
grep -Fq "Installed $declared_hooks hooks" <<< "$hooks_output"

# The preview must list the same set the install writes.
hooks_preview=$(cd "$REPO_DIR" && HOME="$FAKE_HOME" ./install.sh \
    --dry-run \
    --hooks-only \
    --claude-dir "$TEST_DIR/hooks-preview")

grep -Fq "Would install hook: auto-format.sh" <<< "$hooks_preview"
if grep -Fq "Would install hook: README.md" <<< "$hooks_preview"; then
    echo "preview advertised hooks/README.md as a hook" >&2
    exit 1
fi

# A copy of the script with no source tree beside it has nothing to install.
# It must say so rather than report a successful empty install.
DETACHED_DIR="$TEST_DIR/detached"
DETACHED_TARGET="$TEST_DIR/detached-install-target"
mkdir -p "$DETACHED_DIR"
cp "$REPO_DIR/install.sh" "$DETACHED_DIR/install.sh"

detached_status=0
detached_output=$(cd "$REPO_DIR" && HOME="$FAKE_HOME" "$DETACHED_DIR/install.sh" \
    --claude-dir "$DETACHED_TARGET" 2>&1) || detached_status=$?

if [ "$detached_status" -eq 0 ]; then
    echo "detached install reported success with no source tree" >&2
    exit 1
fi
grep -Fq "Run install.sh from a complete claude-code-tools checkout" <<< "$detached_output"
if [ -e "$DETACHED_TARGET" ]; then
    echo "detached install created the destination directory" >&2
    exit 1
fi

echo "install tests passed"
