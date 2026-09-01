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

# Uninstall must clear the hook entries it deletes the scripts for, exactly as it
# does for statusLine. Claude Code runs every configured hook command, so a
# settings.json left addressing a removed hooks/auto-format.sh reports a missing
# file on every Edit, Write and MultiEdit, and the UserPromptSubmit entry does
# the same on every turn.
if command -v jq >/dev/null 2>&1; then
    HOOK_SETTINGS_DIR="$TEST_DIR/hook-settings"
    mkdir -p "$HOOK_SETTINGS_DIR/hooks"
    cp "$REPO_DIR/hooks/auto-format.sh" "$HOOK_SETTINGS_DIR/hooks/auto-format.sh"
    cp "$REPO_DIR/hooks/constraint-persistence.sh" \
        "$HOOK_SETTINGS_DIR/hooks/constraint-persistence.sh"
    jq -n --arg dir "$HOOK_SETTINGS_DIR" '{
        model: "opus",
        hooks: {
            PostToolUse: [{
                matcher: "Edit|Write|MultiEdit",
                hooks: [
                    {type: "command", command: ($dir + "/hooks/auto-format.sh")},
                    {type: "command", command: ($dir + "/hooks/my-own.sh")}
                ]
            }],
            UserPromptSubmit: [{
                hooks: [{type: "command",
                         command: "~/.claude/hooks/constraint-persistence.sh"}]
            }],
            SessionStart: [{
                hooks: [{type: "command", command: "~/bin/auto-format.sh"}]
            }]
        }
    }' > "$HOOK_SETTINGS_DIR/settings.json"

    hook_settings_dry=$(cd "$REPO_DIR" && ./uninstall.sh --dry-run --force \
        --claude-dir "$HOOK_SETTINGS_DIR")

    grep -Fq "Would remove: hook entries from settings.json" <<< "$hook_settings_dry"
    if ! jq -e '.hooks.PostToolUse[0].hooks | length == 2' \
         "$HOOK_SETTINGS_DIR/settings.json" >/dev/null; then
        echo "uninstall dry-run edited the hooks in settings.json" >&2
        exit 1
    fi

    (cd "$REPO_DIR" && ./uninstall.sh --force --claude-dir "$HOOK_SETTINGS_DIR" >/dev/null)

    if jq -e '[.. | objects | .command? // empty]
              | any(test("hooks/(auto-format|constraint-persistence)\\.sh"))' \
         "$HOOK_SETTINGS_DIR/settings.json" >/dev/null; then
        echo "uninstall left a hook pointing at a deleted script" >&2
        exit 1
    fi
    # A hook the user added beside ours, and one merely sharing a filename
    # outside hooks/, are not ours to remove.
    if ! jq -e --arg dir "$HOOK_SETTINGS_DIR" '.hooks.PostToolUse[0].hooks
                == [{type: "command", command: ($dir + "/hooks/my-own.sh")}]' \
         "$HOOK_SETTINGS_DIR/settings.json" >/dev/null; then
        echo "uninstall removed a hook it did not install" >&2
        exit 1
    fi
    if ! jq -e '.hooks.SessionStart[0].hooks[0].command == "~/bin/auto-format.sh"' \
         "$HOOK_SETTINGS_DIR/settings.json" >/dev/null; then
        echo "uninstall removed a hook outside hooks/ that shares a filename" >&2
        exit 1
    fi
    # An event left with no hook groups is dropped rather than kept empty.
    if jq -e 'has("hooks") and (.hooks | has("UserPromptSubmit"))' \
         "$HOOK_SETTINGS_DIR/settings.json" >/dev/null; then
        echo "uninstall left an empty UserPromptSubmit event behind" >&2
        exit 1
    fi
    if ! jq -e '.model == "opus"' "$HOOK_SETTINGS_DIR/settings.json" >/dev/null; then
        echo "uninstall clobbered unrelated settings.json keys" >&2
        exit 1
    fi

    # With nothing but our hooks configured, the whole "hooks" key goes away.
    ONLY_HOOKS_DIR="$TEST_DIR/hook-settings-only"
    mkdir -p "$ONLY_HOOKS_DIR/hooks"
    cp "$REPO_DIR/hooks/auto-format.sh" "$ONLY_HOOKS_DIR/hooks/auto-format.sh"
    jq -n --arg dir "$ONLY_HOOKS_DIR" '{
        hooks: {PostToolUse: [{
            matcher: "Edit",
            hooks: [{type: "command", command: ($dir + "/hooks/auto-format.sh")}]
        }]}
    }' > "$ONLY_HOOKS_DIR/settings.json"

    (cd "$REPO_DIR" && ./uninstall.sh --force --claude-dir "$ONLY_HOOKS_DIR" >/dev/null)

    if jq -e 'has("hooks")' "$ONLY_HOOKS_DIR/settings.json" >/dev/null; then
        echo "uninstall left an empty hooks object behind" >&2
        exit 1
    fi
fi

# settings.json entries outlive the files they name, so uninstall must clear them
# even when the scripts are already gone. An install predating the settings
# cleanup, removed by the older uninstall.sh, leaves exactly that state: Claude
# Code reports a missing hooks/auto-format.sh on every Edit, Write and MultiEdit
# and a missing constraint-persistence.sh on every turn, while the statusLine
# points at a deleted script. Gating the cleanup on the files still being present
# made uninstall.sh print "No Claude Code Tools found to uninstall" and exit 0,
# so the documented fix was a no-op and the breakage had no supported remedy.
if command -v jq >/dev/null 2>&1; then
    STALE_DIR="$TEST_DIR/stale-settings-only"
    mkdir -p "$STALE_DIR"
    jq -n --arg dir "$STALE_DIR" '{
        model: "opus",
        statusLine: {type: "command",
                     command: ($dir + "/flying-dutchman-statusline.sh")},
        hooks: {
            PostToolUse: [{
                matcher: "Edit|Write|MultiEdit",
                hooks: [{type: "command", command: ($dir + "/hooks/auto-format.sh")}]
            }],
            UserPromptSubmit: [{
                hooks: [{type: "command",
                         command: ($dir + "/hooks/constraint-persistence.sh")}]
            }]
        }
    }' > "$STALE_DIR/settings.json"

    stale_dry=$(cd "$REPO_DIR" && ./uninstall.sh --dry-run --force \
        --claude-dir "$STALE_DIR")

    # The stale entries are what is left to remove, so they must be reported.
    grep -Fq "hook entries in settings.json" <<< "$stale_dry"
    grep -Fq "statusLine in settings.json" <<< "$stale_dry"
    grep -Fq "Would remove: hook entries from settings.json" <<< "$stale_dry"
    grep -Fq "Would remove: statusLine from settings.json" <<< "$stale_dry"
    if grep -Fq "No Claude Code Tools found to uninstall" <<< "$stale_dry"; then
        echo "uninstall ignored settings.json left behind by a removed install" >&2
        exit 1
    fi
    if ! jq -e 'has("hooks") and has("statusLine")' \
         "$STALE_DIR/settings.json" >/dev/null; then
        echo "uninstall dry-run edited stale settings.json" >&2
        exit 1
    fi

    (cd "$REPO_DIR" && ./uninstall.sh --force --claude-dir "$STALE_DIR" >/dev/null)

    if jq -e 'has("hooks")' "$STALE_DIR/settings.json" >/dev/null; then
        echo "uninstall left hook entries for scripts already deleted" >&2
        exit 1
    fi
    if jq -e 'has("statusLine")' "$STALE_DIR/settings.json" >/dev/null; then
        echo "uninstall left a statusLine for a script already deleted" >&2
        exit 1
    fi
    if ! jq -e '.model == "opus"' "$STALE_DIR/settings.json" >/dev/null; then
        echo "uninstall clobbered unrelated settings.json keys" >&2
        exit 1
    fi

    # With nothing of ours installed and nothing of ours configured, uninstall
    # still says so and leaves the user's own entries alone.
    FOREIGN_ONLY_DIR="$TEST_DIR/foreign-settings-only"
    mkdir -p "$FOREIGN_ONLY_DIR"
    jq -n '{
        statusLine: {type: "command", command: "~/my-own-statusline.sh"},
        hooks: {PostToolUse: [{
            matcher: "Edit",
            hooks: [{type: "command", command: "~/bin/auto-format.sh"}]
        }]}
    }' > "$FOREIGN_ONLY_DIR/settings.json"
    cp "$FOREIGN_ONLY_DIR/settings.json" "$TEST_DIR/foreign-settings-before.json"

    foreign_only_output=$(cd "$REPO_DIR" && ./uninstall.sh --force \
        --claude-dir "$FOREIGN_ONLY_DIR")

    grep -Fq "No Claude Code Tools found to uninstall" <<< "$foreign_only_output"
    if ! diff -q <(jq -S . "$TEST_DIR/foreign-settings-before.json") \
                 <(jq -S . "$FOREIGN_ONLY_DIR/settings.json") >/dev/null; then
        echo "uninstall edited a settings.json holding only the user's own entries" >&2
        exit 1
    fi
fi

# Without jq the stale entries cannot be edited safely, so uninstall must still
# notice them and say so rather than reporting a clean run. The warning is the
# only thing standing between the user and a settings.json that keeps failing.
NO_JQ_PATH="$TEST_DIR/no-jq-bin"
mkdir -p "$NO_JQ_PATH"
IFS=':' read -ra PATH_DIRS <<< "$PATH"
for path_dir in "${PATH_DIRS[@]}"; do
    [ -d "$path_dir" ] || continue
    for candidate in "$path_dir"/*; do
        [ -e "$candidate" ] || continue
        name="$(basename "$candidate")"
        [ "$name" = "jq" ] && continue
        [ -e "$NO_JQ_PATH/$name" ] || ln -s "$candidate" "$NO_JQ_PATH/$name" 2>/dev/null || true
    done
done

if ! PATH="$NO_JQ_PATH" command -v jq >/dev/null 2>&1; then
    NO_JQ_DIR="$TEST_DIR/stale-settings-no-jq"
    mkdir -p "$NO_JQ_DIR"
    cat > "$NO_JQ_DIR/settings.json" <<JSON
{
  "statusLine": {
    "type": "command",
    "command": "$NO_JQ_DIR/flying-dutchman-statusline.sh"
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {"type": "command", "command": "$NO_JQ_DIR/hooks/auto-format.sh"}
        ]
      }
    ]
  }
}
JSON
    cp "$NO_JQ_DIR/settings.json" "$TEST_DIR/no-jq-settings-before.json"

    no_jq_output=$(cd "$REPO_DIR" && PATH="$NO_JQ_PATH" bash ./uninstall.sh --force \
        --claude-dir "$NO_JQ_DIR")

    grep -Fq "Remember to remove the cct hooks" <<< "$no_jq_output"
    grep -Fq "Remember to remove 'statusLine'" <<< "$no_jq_output"
    if grep -Fq "No Claude Code Tools found to uninstall" <<< "$no_jq_output"; then
        echo "uninstall reported a clean run over stale settings without jq" >&2
        exit 1
    fi
    # It cannot rewrite the file safely without jq, so it must not try.
    if ! diff -q "$TEST_DIR/no-jq-settings-before.json" \
                 "$NO_JQ_DIR/settings.json" >/dev/null; then
        echo "uninstall edited settings.json without jq" >&2
        exit 1
    fi

    # Nothing installed and nothing configured stays quiet, with no stray
    # warning about a settings.json that holds none of our entries.
    NO_JQ_CLEAN_DIR="$TEST_DIR/clean-no-jq"
    mkdir -p "$NO_JQ_CLEAN_DIR"
    echo '{"model": "opus"}' > "$NO_JQ_CLEAN_DIR/settings.json"

    no_jq_clean=$(cd "$REPO_DIR" && PATH="$NO_JQ_PATH" bash ./uninstall.sh --force \
        --claude-dir "$NO_JQ_CLEAN_DIR")

    grep -Fq "No Claude Code Tools found to uninstall" <<< "$no_jq_clean"
    if grep -Fq "Remember to remove" <<< "$no_jq_clean"; then
        echo "uninstall warned about a settings.json holding none of our entries" >&2
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

# install.sh no longer copies hooks/README.md or hooks/hooks.json, but earlier
# versions did. uninstall.sh is the only thing that can clear them, so its
# removal list must stay wider than the set install.sh writes today.
LEGACY_DIR="$TEST_DIR/legacy-hooks-target"
mkdir -p "$LEGACY_DIR/hooks"
cp "$REPO_DIR/hooks/$HOOK_NAME" "$LEGACY_DIR/hooks/$HOOK_NAME"
cp "$REPO_DIR/hooks/README.md" "$LEGACY_DIR/hooks/README.md"
cp "$REPO_DIR/hooks/hooks.json" "$LEGACY_DIR/hooks/hooks.json"

(cd "$REPO_DIR" && ./uninstall.sh --force --claude-dir "$LEGACY_DIR" >/dev/null)

for leftover in "$HOOK_NAME" README.md hooks.json; do
    if [ -e "$LEGACY_DIR/hooks/$leftover" ]; then
        echo "uninstall left hooks/$leftover from a pre-fix install" >&2
        exit 1
    fi
done

# update.sh must refresh the same hooks install.sh writes. The offline fallback
# list is the contract; the fetched listing has to agree with it.
UPDATE_HOOKS_DIR="$TEST_DIR/update-hooks-target"
mkdir -p "$UPDATE_HOOKS_DIR/hooks"
cp "$REPO_DIR/hooks/README.md" "$UPDATE_HOOKS_DIR/hooks/README.md"

update_hooks_output=$(cd "$REPO_DIR" && ./update.sh --dry-run -v \
    --claude-dir "$UPDATE_HOOKS_DIR")

if grep -Fq "Would update: $UPDATE_HOOKS_DIR/hooks/README.md" <<< "$update_hooks_output"; then
    echo "update treated hooks/README.md as a hook" >&2
    exit 1
fi
grep -Fq "Hook not installed, skipping: $HOOK_NAME" <<< "$update_hooks_output"

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

# A failed download must not end the run. Every download_file call returns
# non-zero on failure, and under `set -e` a bare call aborted update.sh on the
# first 404 or network blip: later agents, all skills, all hooks and the
# statusline were skipped, no summary printed, and without -v the run died
# silently on exit 1. Stub curl so every request fails offline and assert the
# updater walks the whole set and reports the failures instead.
OFFLINE_BIN="$TEST_DIR/offline-bin"
mkdir -p "$OFFLINE_BIN"
cat > "$OFFLINE_BIN/curl" <<'STUB'
#!/bin/bash
# 22 is curl's exit code for an HTTP error under --fail.
exit 22
STUB
chmod +x "$OFFLINE_BIN/curl"

OFFLINE_DIR="$TEST_DIR/offline-target"
SKILL_NAME="deslop"
mkdir -p "$OFFLINE_DIR/agents" "$OFFLINE_DIR/skills/$SKILL_NAME" "$OFFLINE_DIR/hooks"
cp "$REPO_DIR/agents/$AGENT_NAME" "$OFFLINE_DIR/agents/$AGENT_NAME"
cp "$REPO_DIR/agents/$OTHER_AGENT" "$OFFLINE_DIR/agents/$OTHER_AGENT"
cp "$REPO_DIR/skills/$SKILL_NAME/SKILL.md" "$OFFLINE_DIR/skills/$SKILL_NAME/SKILL.md"
cp "$REPO_DIR/hooks/$HOOK_NAME" "$OFFLINE_DIR/hooks/$HOOK_NAME"
cp "$REPO_DIR/statusline/flying-dutchman-statusline.sh" "$OFFLINE_DIR/"

offline_status=0
offline_output=$(cd "$REPO_DIR" && PATH="$OFFLINE_BIN:$PATH" ./update.sh -v \
    --claude-dir "$OFFLINE_DIR" 2>&1) || offline_status=$?

if [ "$offline_status" -ne 0 ]; then
    echo "update aborted on a failed download instead of continuing" >&2
    echo "$offline_output" >&2
    exit 1
fi

# The first agent failing must not stop the components queued behind it.
for phase in "Updating skills..." "Updating hooks..." "Updating statusline..."; do
    if ! grep -Fq "$phase" <<< "$offline_output"; then
        echo "update skipped phase after a failed download: $phase" >&2
        exit 1
    fi
done

grep -Fq "Failed: $OFFLINE_DIR/agents/$OTHER_AGENT" <<< "$offline_output"
grep -Fq "Update complete with errors" <<< "$offline_output"
grep -Fq "Restart Claude Code to load updates" <<< "$offline_output"

# A failed refresh leaves the installed copy exactly as it was.
if ! cmp -s "$REPO_DIR/agents/$AGENT_NAME" "$OFFLINE_DIR/agents/$AGENT_NAME"; then
    echo "a failed download damaged an installed agent" >&2
    exit 1
fi
if ! cmp -s "$REPO_DIR/skills/$SKILL_NAME/SKILL.md" "$OFFLINE_DIR/skills/$SKILL_NAME/SKILL.md"; then
    echo "a failed download damaged an installed skill" >&2
    exit 1
fi

echo "update/uninstall tests passed"
