#!/bin/bash

# Exercises the statusline the way Claude Code runs it: JSON on stdin, one line
# on stdout. The whole line is derived from a single jq pass, and jq ships with
# neither macOS nor the mainstream Linux distributions, so the no-jq path is the
# case that matters most - without a guard it still printed a line, just a
# hollow one with no project, no model and a bare "+ -" diff.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

STATUSLINE="$REPO_DIR/statusline/flying-dutchman-statusline.sh"

fail() {
    echo "$1" >&2
    exit 1
}

# Colours are part of the output, so every assertion runs against the plain text.
strip_ansi() {
    sed $'s/\033\\[[0-9;]*m//g'
}

# A PATH identical to the caller's except that jq is not on it. Dropping the
# directories that contain jq would also drop bash, so link every other
# executable into one directory instead.
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

if PATH="$NO_JQ_PATH" command -v jq >/dev/null 2>&1; then
    fail "could not build a PATH without jq"
fi

WORK_DIR="$TEST_DIR/my-project"
mkdir -p "$WORK_DIR"

PAYLOAD=$(cat <<JSON
{
  "model": {"display_name": "Opus"},
  "workspace": {"current_dir": "$WORK_DIR", "project_dir": "$WORK_DIR"},
  "version": "2.0.80",
  "cost": {
    "total_cost_usd": 1.47,
    "total_duration_ms": 720000,
    "total_lines_added": 42,
    "total_lines_removed": 7
  },
  "context_window": {
    "used_percentage": 63,
    "context_window_size": 200000,
    "current_usage": {"input_tokens": 126000}
  }
}
JSON
)

# Runs the statusline and enforces the parts of the contract that hold for every
# payload: exit 0, nothing on stderr, exactly one line on stdout. A non-zero
# exit or stderr noise is what Claude Code surfaces as a broken statusline.
run_statusline() {
    local label="$1"
    local payload="$2"
    local path_override="${3:-$PATH}"

    local stderr_file="$TEST_DIR/stderr"
    local status=0

    STATUSLINE_OUT=$(printf '%s' "$payload" \
        | PATH="$path_override" bash "$STATUSLINE" 2>"$stderr_file") || status=$?

    if [ "$status" -ne 0 ]; then
        fail "$label exited $status: $(cat "$stderr_file")"
    fi
    if [ -s "$stderr_file" ]; then
        fail "$label wrote to stderr: $(cat "$stderr_file")"
    fi
    if [ "$(printf '%s\n' "$STATUSLINE_OUT" | wc -l | tr -d ' ')" != "1" ]; then
        fail "$label printed more than one line: $STATUSLINE_OUT"
    fi

    STATUSLINE_TEXT=$(printf '%s' "$STATUSLINE_OUT" | strip_ansi)
}

# Without jq the line must name the missing dependency instead of rendering the
# hollow "+ -" diff that a payload nobody could read used to produce.
run_statusline "statusline without jq" "$PAYLOAD" "$NO_JQ_PATH"
grep -Fq "jq" <<< "$STATUSLINE_TEXT" \
    || fail "statusline without jq did not mention jq: $STATUSLINE_TEXT"
if grep -Fq "+ -" <<< "$STATUSLINE_TEXT"; then
    fail "statusline without jq still rendered an empty diff: $STATUSLINE_TEXT"
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq not installed, skipping the with-jq statusline checks" >&2
    echo "statusline tests passed"
    exit 0
fi

# A payload jq cannot parse leaves the same empty variables as a missing jq, so
# it has to be reported rather than rendered.
for bad_payload in "not json" ""; do
    run_statusline "statusline on an unreadable payload" "$bad_payload"
    grep -Fq "payload" <<< "$STATUSLINE_TEXT" \
        || fail "unreadable payload was rendered instead of reported: $STATUSLINE_TEXT"
    if grep -Fq "+ -" <<< "$STATUSLINE_TEXT"; then
        fail "unreadable payload still rendered an empty diff: $STATUSLINE_TEXT"
    fi
done

# The real payload: every field the layout promises has to reach the line, so
# the guards above cannot be mistaken for the statusline having been silenced.
run_statusline "statusline" "$PAYLOAD"
for expected in "my-project" "+42" "-7" "ctx:63%" "126.0k/200.0k" "\$1.47" "12m0s" "Opus@2.0.80"; do
    grep -Fq -- "$expected" <<< "$STATUSLINE_TEXT" \
        || fail "statusline dropped '$expected': $STATUSLINE_TEXT"
done

# Git state comes from the working directory, not the payload.
git -C "$WORK_DIR" init -q
git -C "$WORK_DIR" checkout -q -b statusline-branch 2>/dev/null || true
echo "hello" > "$WORK_DIR/file.txt"
git -C "$WORK_DIR" add file.txt
git -C "$WORK_DIR" \
    -c user.name="Statusline Test" \
    -c user.email="statusline@example.com" \
    -c commit.gpgsign=false \
    commit -q -m "initial"

run_statusline "statusline in a clean repo" "$PAYLOAD"
grep -Fq "statusline-branch" <<< "$STATUSLINE_TEXT" \
    || fail "statusline did not show the git branch: $STATUSLINE_TEXT"
if grep -Fq "statusline-branch*" <<< "$STATUSLINE_TEXT"; then
    fail "statusline marked a clean tree dirty: $STATUSLINE_TEXT"
fi

echo "modified" > "$WORK_DIR/file.txt"
run_statusline "statusline in a dirty repo" "$PAYLOAD"
grep -Fq "statusline-branch*" <<< "$STATUSLINE_TEXT" \
    || fail "statusline did not mark a dirty tree: $STATUSLINE_TEXT"

echo "statusline tests passed"
