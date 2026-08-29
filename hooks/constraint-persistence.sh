#!/bin/bash
# UserPromptSubmit hook - detects constraints and prompts Claude to persist them
# Reads JSON from stdin, outputs reminder context to stdout

input=$(cat)

# Without jq the prompt cannot be read, so there is nothing to match on. Say so
# by exiting rather than leaning on `jq -r` failing into an empty $prompt: this
# hook writes to stdout, and stdout is injected into the user's prompt, so a
# missing dependency must stay silent instead of nagging on every turn.
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

prompt=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null)

# Constraint persistence detection - prompt Claude to save rules
if echo "$prompt" | grep -qiE "from now on|always do|never do|don't ever|stop doing|start doing|going forward"; then
    echo ""
    echo "<constraint-detected>"
    echo "The user appears to be setting a persistent constraint or preference."
    echo "After addressing their request, suggest adding this rule to the project's CLAUDE.md"
    echo "(or ~/.claude/CLAUDE.md for global rules) so it persists across sessions."
    echo "</constraint-detected>"
fi

exit 0
