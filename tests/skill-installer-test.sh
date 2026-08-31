#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

INSTALLER="$REPO_DIR/skills/linear/install.sh"

if [ ! -x "$INSTALLER" ]; then
    echo "linear skill installer missing or not executable: $INSTALLER" >&2
    exit 1
fi

# `./install.sh` hands the linear skill its own installer, so anything that
# installer writes lands in the user's real ~/.claude. Stub the package manager
# so the suite stays hermetic and offline, and have the stub reproduce what
# `bun init -y` actually does: scaffold a project, CLAUDE.md included. If the
# installer ever asks a package manager to initialise the directory again, that
# CLAUDE.md reappears and the assertions below fail.
STUB_BIN="$TEST_DIR/stub-bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/bun" <<'STUB'
#!/bin/bash
if [ "${1:-}" = "init" ]; then
    printf 'Default to using Bun instead of Node.js.\n' > CLAUDE.md
    printf 'console.log("Hello via Bun!");' > index.ts
    printf '# linear\n' > README.md
    printf '{"compilerOptions":{}}\n' > tsconfig.json
    printf 'node_modules\n' > .gitignore
    printf '{"name":"linear","module":"index.ts"}\n' > package.json
    exit 0
fi
if [ "${1:-}" = "add" ]; then
    mkdir -p node_modules/@linear/sdk
    exit 0
fi
exit 0
STUB
chmod +x "$STUB_BIN/bun"

TARGET="$TEST_DIR/claude"
(PATH="$STUB_BIN:$PATH" "$INSTALLER" --claude-dir "$TARGET" >/dev/null)

SKILL_DIR="$TARGET/skills/linear"

# The skill itself has to arrive.
test -f "$SKILL_DIR/SKILL.md"
test -f "$SKILL_DIR/scripts/linear.ts"
test -x "$SKILL_DIR/scripts/linear.ts"
test -d "$SKILL_DIR/node_modules/@linear/sdk"

# A manifest is all the dependency needs, and the installer must write it itself.
test -f "$SKILL_DIR/package.json"
grep -Fq '"private": true' "$SKILL_DIR/package.json"

# Nothing else belongs in a directory under the user's ~/.claude. CLAUDE.md is
# the one that does real damage: Claude Code reads it as instructions, so an
# installer for a Linear skill would be telling every session that loads it to
# prefer Bun over Node.
for stray in CLAUDE.md index.ts README.md tsconfig.json .gitignore; do
    if [ -e "$SKILL_DIR/$stray" ]; then
        echo "installer scaffolded $stray into $SKILL_DIR" >&2
        exit 1
    fi
done

# An existing package.json is the user's, not ours to overwrite.
KEEP_DIR="$TEST_DIR/keep"
mkdir -p "$KEEP_DIR/skills/linear"
printf '{"name":"mine","dependencies":{"left-pad":"1.0.0"}}\n' > "$KEEP_DIR/skills/linear/package.json"
(PATH="$STUB_BIN:$PATH" "$INSTALLER" --claude-dir "$KEEP_DIR" >/dev/null)
grep -Fq 'left-pad' "$KEEP_DIR/skills/linear/package.json"

# Residue from an install that predates the fix is reported rather than ignored,
# so the stray CLAUDE.md does not keep steering sessions unnoticed.
STALE_DIR="$TEST_DIR/stale"
mkdir -p "$STALE_DIR/skills/linear"
printf 'Default to using Bun instead of Node.js.\n' > "$STALE_DIR/skills/linear/CLAUDE.md"
stale_output=$(PATH="$STUB_BIN:$PATH" "$INSTALLER" --claude-dir "$STALE_DIR")
grep -Fq "$STALE_DIR/skills/linear/CLAUDE.md" <<< "$stale_output"

# With no package manager on PATH the skill still installs; only the dependency
# is skipped. Build a PATH holding just the utilities the installer calls.
MIN_BIN="$TEST_DIR/min-bin"
mkdir -p "$MIN_BIN"
for util in mkdir cp chmod cat dirname; do
    util_path=$(command -v "$util")
    ln -s "$util_path" "$MIN_BIN/$util"
done

BARE_DIR="$TEST_DIR/bare"
bare_output=$(PATH="$MIN_BIN" "$INSTALLER" --claude-dir "$BARE_DIR")

test -f "$BARE_DIR/skills/linear/SKILL.md"
test -f "$BARE_DIR/skills/linear/package.json"
grep -Fq "No package manager found" <<< "$bare_output"

# A package manager that fails to add the SDK used to be treated as success:
# stderr was discarded, `|| true` kept the installer at exit 0, and the
# summary still said "Skill installed". The CLI fallback imports
# `@linear/sdk`, so that report was false. The parent ./install.sh runs
# under `set -e`, so this installer must still exit 0 — otherwise a
# network blip rolls back every other skill and agent.
FAIL_BIN="$TEST_DIR/fail-bin"
mkdir -p "$FAIL_BIN"
for util in mkdir cp chmod cat dirname; do
    ln -s "$(command -v "$util")" "$FAIL_BIN/$util"
done
cat > "$FAIL_BIN/bun" <<'STUB'
#!/bin/bash
if [ "${1:-}" = "add" ]; then
    exit 1
fi
exit 0
STUB
chmod +x "$FAIL_BIN/bun"

FAIL_DIR="$TEST_DIR/fail-sdk"
fail_status=0
fail_output=$(PATH="$FAIL_BIN" "$INSTALLER" --claude-dir "$FAIL_DIR") || fail_status=$?

if [ "$fail_status" -ne 0 ]; then
    echo "installer exited $fail_status when @linear/sdk failed to install" >&2
    exit 1
fi
test -f "$FAIL_DIR/skills/linear/SKILL.md"
if [ -d "$FAIL_DIR/skills/linear/node_modules/@linear/sdk" ]; then
    echo "failing bun add still produced @linear/sdk" >&2
    exit 1
fi
grep -Fq "Could not install @linear/sdk using bun" <<< "$fail_output"
if grep -Fq "Skill installed to" <<< "$fail_output"; then
    echo "installer reported success without @linear/sdk" >&2
    exit 1
fi

echo "skill installer tests passed"
