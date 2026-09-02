#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$REPO_DIR/README.md"

if [ ! -f "$README" ]; then
    echo "no README at $README" >&2
    exit 1
fi

# README is the only inventory a user reads before installing, and nothing tied
# it to what the repo ships. The Rules section drifted to "(1)" while rules/
# grew to three files, so `cp rules/*.md ~/.claude/rules/` -- the README's own
# instruction -- copied two files the README never mentions.

failures=0

fail() {
    echo "$1" >&2
    failures=$((failures + 1))
}

# The count declared in "### <Section> (N)" must match what the repo ships.
declared_count() {
    local section="$1"
    sed -n "s/^### ${section} (\([0-9]*\))\$/\1/p" "$README"
}

check_count() {
    local section="$1"
    local shipped="$2"
    local declared

    declared=$(declared_count "$section")

    if [ -z "$declared" ]; then
        fail "README has no '### $section (N)' heading"
        return
    fi

    if [ "$(printf '%s\n' "$declared" | wc -l)" -ne 1 ]; then
        fail "README declares '### $section (N)' more than once"
        return
    fi

    if [ "$declared" != "$shipped" ]; then
        fail "README says $section ($declared) but the repo ships $shipped"
    fi
}

count_files() {
    # ls exits non-zero on an empty glob; an empty component is a failure the
    # count check reports rather than something that should abort the run.
    ls -1 $1 2>/dev/null | wc -l | tr -d ' '
}

cd "$REPO_DIR"

check_count "Agents" "$(count_files 'agents/*.md')"
check_count "Skills" "$(ls -1d skills/*/ 2>/dev/null | wc -l | tr -d ' ')"
check_count "Hooks" "$(count_files 'hooks/*.sh')"
check_count "Rules" "$(count_files 'rules/*.md')"

# Every component the repo ships must be named in the README. A component that
# installs but is never documented is indistinguishable from one that is not
# shipped at all.
check_named() {
    local label="$1"
    local name="$2"

    if ! grep -Fq "\`$name\`" "$README"; then
        fail "README does not document the $label it ships: $name"
    fi
}

for agent_file in agents/*.md; do
    [ -f "$agent_file" ] || continue
    check_named "agent" "$(basename "$agent_file" .md)"
done

for skill_dir in skills/*/; do
    [ -d "$skill_dir" ] || continue
    check_named "skill" "$(basename "$skill_dir")"
done

for hook_file in hooks/*.sh; do
    [ -f "$hook_file" ] || continue
    check_named "hook" "$(basename "$hook_file")"
done

for rule_file in rules/*.md; do
    [ -f "$rule_file" ] || continue
    check_named "rule" "$(basename "$rule_file")"
done

if [ "$failures" -ne 0 ]; then
    echo "README inventory tests failed ($failures)" >&2
    exit 1
fi

echo "readme inventory tests passed"
