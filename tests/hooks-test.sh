#!/bin/bash

# Exercises the two shipped hooks the way Claude Code runs them: JSON on stdin,
# exit status and stdout are the contract. A hook that exits non-zero surfaces
# its stderr to the user on every matching tool call, so the no-jq path below is
# the case that matters most - jq ships with neither macOS nor the mainstream
# Linux distributions.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

AUTO_FORMAT="$REPO_DIR/hooks/auto-format.sh"
CONSTRAINT="$REPO_DIR/hooks/constraint-persistence.sh"

fail() {
    echo "$1" >&2
    exit 1
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

# Both hooks must stay quiet and succeed when jq is missing. stderr is checked
# too: on a non-zero exit Claude Code shows it to the user verbatim.
run_without_jq() {
    local script="$1"
    local payload="$2"
    local label="$3"

    local stdout_file="$TEST_DIR/stdout"
    local stderr_file="$TEST_DIR/stderr"
    local status=0

    printf '%s' "$payload" \
        | PATH="$NO_JQ_PATH" bash "$script" >"$stdout_file" 2>"$stderr_file" || status=$?

    if [ "$status" -ne 0 ]; then
        fail "$label exited $status without jq: $(cat "$stderr_file")"
    fi
    if [ -s "$stderr_file" ]; then
        fail "$label wrote to stderr without jq: $(cat "$stderr_file")"
    fi
    if [ -s "$stdout_file" ]; then
        fail "$label wrote to stdout without jq: $(cat "$stdout_file")"
    fi
}

SAMPLE="$TEST_DIR/sample.json"
echo '{"a":1}' > "$SAMPLE"

run_without_jq "$AUTO_FORMAT" \
    "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$SAMPLE\"}}" \
    "auto-format.sh"

run_without_jq "$CONSTRAINT" \
    '{"prompt":"from now on always use tabs"}' \
    "constraint-persistence.sh"

# With jq available the hooks must still do their job, so the guard above cannot
# be mistaken for the hooks having been turned off.
if command -v jq >/dev/null 2>&1; then
    status=0
    printf '%s' "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$SAMPLE\"}}" \
        | bash "$AUTO_FORMAT" >/dev/null 2>"$TEST_DIR/stderr" || status=$?
    [ "$status" -eq 0 ] || fail "auto-format.sh exited $status with jq: $(cat "$TEST_DIR/stderr")"

    # A file the hook must ignore: no matching tool, so nothing may run.
    status=0
    printf '%s' '{"tool_name":"Read","tool_input":{"file_path":"/nonexistent"}}' \
        | bash "$AUTO_FORMAT" >/dev/null 2>&1 || status=$?
    [ "$status" -eq 0 ] || fail "auto-format.sh exited $status on a non-edit tool"

    constraint_out=$(printf '%s' '{"prompt":"from now on always use tabs"}' | bash "$CONSTRAINT")
    grep -Fq '<constraint-detected>' <<< "$constraint_out" \
        || fail "constraint-persistence.sh did not flag a constraint prompt"

    constraint_out=$(printf '%s' '{"prompt":"what does this function do"}' | bash "$CONSTRAINT")
    [ -z "$constraint_out" ] \
        || fail "constraint-persistence.sh flagged an ordinary prompt: $constraint_out"
else
    echo "jq not installed, skipping the with-jq hook checks" >&2
fi

echo "hook tests passed"
