#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

MANIFEST="$REPO_DIR/hooks/hooks.json"

if [ ! -f "$MANIFEST" ]; then
    echo "no plugin hook manifest at $MANIFEST" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to read $MANIFEST" >&2
    exit 1
fi

# Print one command per line, and fail on malformed JSON or a hook entry that is
# missing its command.
read_commands() {
    python3 - "$MANIFEST" <<'PY'
import json, sys

with open(sys.argv[1]) as fh:
    manifest = json.load(fh)

commands = []
for event, matchers in manifest["hooks"].items():
    for matcher in matchers:
        for hook in matcher["hooks"]:
            if hook.get("type") != "command":
                sys.exit(f"{event}: only command hooks are supported")
            command = hook.get("command")
            if not command:
                sys.exit(f"{event}: hook entry has no command")
            commands.append(command)

if not commands:
    sys.exit("manifest declares no hook commands")

print("\n".join(commands))
PY
}

COMMANDS=$(read_commands)

# Claude Code spawns plugin hooks with the session's working directory, which is
# the user's project, not the plugin. A relative command like
# ./hooks/auto-format.sh therefore resolves against whatever the user happens to
# be working in and silently fails for every plugin install. ${CLAUDE_PLUGIN_ROOT}
# is substituted for the plugin directory and is only available in this file.
while IFS= read -r command; do
    [ -z "$command" ] && continue
    if ! grep -Fq '${CLAUDE_PLUGIN_ROOT}' <<< "$command"; then
        echo "hook command does not resolve from the plugin root: $command" >&2
        exit 1
    fi
    if grep -Eq '(^|[[:space:]"])\./' <<< "$command"; then
        echo "hook command uses a working-directory-relative path: $command" >&2
        exit 1
    fi
done <<< "$COMMANDS"

# Every script the manifest names must ship in the plugin, and every shell hook
# the plugin ships must be wired into the manifest. Either half drifting leaves a
# hook that never runs.
referenced=$(grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^"]+' <<< "$COMMANDS" \
    | while IFS= read -r match; do echo "${match#\$\{CLAUDE_PLUGIN_ROOT\}/}"; done | sort -u)

for path in $referenced; do
    if [ ! -f "$REPO_DIR/$path" ]; then
        echo "manifest references a file the plugin does not ship: $path" >&2
        exit 1
    fi
done

shipped=$(cd "$REPO_DIR" && ls -1 hooks/*.sh | sort)
if [ "$referenced" != "$shipped" ]; then
    echo "manifest wires up:" >&2
    echo "$referenced" >&2
    echo "plugin ships:" >&2
    echo "$shipped" >&2
    exit 1
fi

# Run the manifest the way Claude Code does: substitute the plugin root, then
# execute from an unrelated working directory. This is what caught the relative
# paths - the hooks exited 127 instead of running.
if command -v jq >/dev/null 2>&1; then
    PLUGIN_ROOT="$TEST_DIR/plugin"
    FOREIGN_CWD="$TEST_DIR/some-user-project"
    mkdir -p "$PLUGIN_ROOT" "$FOREIGN_CWD"
    (cd "$REPO_DIR" && tar -cf - hooks) | (cd "$PLUGIN_ROOT" && tar -xf -)

    while IFS= read -r command; do
        [ -z "$command" ] && continue
        resolved=${command//\$\{CLAUDE_PLUGIN_ROOT\}/$PLUGIN_ROOT}
        status=0
        (cd "$FOREIGN_CWD" && eval "$resolved" <<< '{"prompt":"hello","tool_name":"Read"}') \
            >/dev/null || status=$?
        if [ "$status" -ne 0 ]; then
            echo "hook exited $status when run from outside the plugin: $resolved" >&2
            exit 1
        fi
    done <<< "$COMMANDS"
fi

echo "plugin manifest tests passed"
