#!/bin/bash
# UserPromptSubmit hook - detects constraints and prompts Claude to persist them
# Reads JSON from stdin, outputs reminder context to stdout

input=$(cat)
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
