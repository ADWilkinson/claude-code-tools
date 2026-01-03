#!/bin/bash
# Auto-Format Hook for Claude Code
# Runs formatters after Edit/Write operations based on file type
# Handles the last 10% of formatting that Claude might miss
#
# Usage: Add to settings.json under hooks.PostToolUse
# {
#   "matcher": "Edit|Write|MultiEdit",
#   "hooks": [{
#     "type": "command",
#     "command": "~/.claude/hooks/auto-format.sh"
#   }]
# }

set -euo pipefail

INPUT_JSON=$(cat)

tool_name=$(echo "$INPUT_JSON" | jq -r '.tool_name // ""')

# Only process Edit and Write tools
if [[ "$tool_name" != "Edit" && "$tool_name" != "Write" && "$tool_name" != "MultiEdit" ]]; then
    exit 0
fi

# Extract file path
file_path=$(echo "$INPUT_JSON" | jq -r '.tool_input.file_path // ""')

if [[ -z "$file_path" || ! -f "$file_path" ]]; then
    exit 0
fi

# Get file extension
ext="${file_path##*.}"

# Find project root (look for package.json, Cargo.toml, pyproject.toml, etc.)
dir=$(dirname "$file_path")
project_root=""
while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" || -f "$dir/Cargo.toml" || -f "$dir/pyproject.toml" || -f "$dir/go.mod" ]]; then
        project_root="$dir"
        break
    fi
    dir=$(dirname "$dir")
done

# Format based on file type
case "$ext" in
    ts|tsx|js|jsx|mjs|cjs|json)
        # Check for prettier in project
        if [[ -n "$project_root" && -f "$project_root/node_modules/.bin/prettier" ]]; then
            "$project_root/node_modules/.bin/prettier" --write "$file_path" 2>/dev/null || true
        elif command -v prettier &>/dev/null; then
            prettier --write "$file_path" 2>/dev/null || true
        fi
        ;;
    py)
        # Use ruff if available (fast), fall back to black
        if command -v ruff &>/dev/null; then
            ruff format "$file_path" 2>/dev/null || true
        elif command -v black &>/dev/null; then
            black --quiet "$file_path" 2>/dev/null || true
        fi
        ;;
    sol)
        # Solidity - use forge fmt if available
        if [[ -n "$project_root" && -f "$project_root/foundry.toml" ]]; then
            (cd "$project_root" && forge fmt "$file_path" 2>/dev/null) || true
        fi
        ;;
    go)
        if command -v gofmt &>/dev/null; then
            gofmt -w "$file_path" 2>/dev/null || true
        fi
        ;;
    rs)
        if command -v rustfmt &>/dev/null; then
            rustfmt "$file_path" 2>/dev/null || true
        fi
        ;;
esac

# Silent success - no output needed
exit 0
