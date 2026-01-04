#!/bin/bash

# Claude Code Statusline - Flying Dutchman Theme
# Author: Andrew Wilkinson (github.com/ADWilkinson)
# Features: Current folder, git branch, model name, activity indicators, cost tracking, and lines changed

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON with error handling
model_display_name=$(echo "$input" | jq -r '.model.display_name // "Claude"' 2>/dev/null || echo "Claude")
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // "~"' 2>/dev/null || pwd)
session_id=$(echo "$input" | jq -r '.session_id // ""' 2>/dev/null)

# Extract cost and metrics
total_cost=$(echo "$input" | jq -r '.cost.total_usd // 0' 2>/dev/null || echo "0")
lines_added=$(echo "$input" | jq -r '.cost.lines_added // 0' 2>/dev/null || echo "0")
lines_removed=$(echo "$input" | jq -r '.cost.lines_removed // 0' 2>/dev/null || echo "0")

# Get just the current folder name
current_folder=$(basename "$current_dir")

# Check for active file being edited (look for recent Edit/Write operations in transcript)
active_file=""
if [ -n "$session_id" ] && [ -f "/tmp/claude_active_file_${session_id}" ]; then
    active_file=$(cat "/tmp/claude_active_file_${session_id}" 2>/dev/null)
    if [ -n "$active_file" ]; then
        active_file=" $(basename "$active_file")"
    fi
fi

# Get git info if in a repository
git_info=""
if command -v git >/dev/null 2>&1 && git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$current_dir" branch --show-current 2>/dev/null || git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        # Check for uncommitted changes and add asterisk if present
        if git -C "$current_dir" diff-index --quiet HEAD -- 2>/dev/null; then
            git_info=" git:${branch}"
        else
            git_info=" git:${branch}*"
        fi
    fi
fi


# Extract Claude's current activity from the input
current_activity=$(echo "$input" | jq -r '.current_activity // ""' 2>/dev/null)
active_tools=$(echo "$input" | jq -r '.active_tools[]? // ""' 2>/dev/null)

# Determine activity icon based on what Claude is currently doing
activity_icon=""
if echo "$active_tools" | grep -q "Bash" 2>/dev/null; then
    # Check what specific bash command is running
    if echo "$current_activity" | grep -E "npm run dev|yarn dev|pnpm dev|bun dev" >/dev/null 2>&1; then
        activity_icon=" [dev]"
    elif echo "$current_activity" | grep -E "npm run build|yarn build|pnpm build|bun build" >/dev/null 2>&1; then
        activity_icon=" [build]"
    elif echo "$current_activity" | grep -E "npm test|yarn test|pnpm test|bun test|pytest" >/dev/null 2>&1; then
        activity_icon=" [test]"
    elif echo "$current_activity" | grep -E "git" >/dev/null 2>&1; then
        activity_icon=" [git]"
    else
        activity_icon=" [bash]"
    fi
elif echo "$active_tools" | grep -q "Edit\|Write\|MultiEdit" 2>/dev/null; then
    activity_icon=" [edit]"
elif echo "$active_tools" | grep -q "Read\|Grep\|Glob" 2>/dev/null; then
    activity_icon=" [search]"
elif echo "$active_tools" | grep -q "Task" 2>/dev/null; then
    activity_icon=" [agent]"
elif echo "$active_tools" | grep -q "WebSearch\|WebFetch" 2>/dev/null; then
    activity_icon=" [web]"
fi

# Define colors using standard ANSI codes for maximum compatibility
GREEN="\033[32m"
BLUE="\033[34m"
CYAN="\033[36m"
MAGENTA="\033[35m"
YELLOW="\033[33m"
GRAY="\033[90m"
RESET="\033[0m"

# Build compact status line
output="${BLUE}${current_folder}${RESET}"

# Add file if editing
if [ -n "$active_file" ]; then
    output="${output}${GRAY}${active_file}${RESET}"
fi

# Add git info
if [ -n "$git_info" ]; then
    output="${output} ${MAGENTA}${git_info}${RESET}"
fi

# Add activity icon if Claude is doing something
if [ -n "$activity_icon" ]; then
    output="${output}${activity_icon}"
fi

# Add lines changed if any modifications made
if [ "$lines_added" != "0" ] || [ "$lines_removed" != "0" ]; then
    output="${output} ${GREEN}+${lines_added}${RESET}/${MAGENTA}-${lines_removed}${RESET}"
fi

# Add cost if non-zero (format to 2 decimal places)
if [ "$total_cost" != "0" ] && [ -n "$total_cost" ]; then
    formatted_cost=$(printf "%.2f" "$total_cost" 2>/dev/null || echo "$total_cost")
    output="${output} ${YELLOW}\$${formatted_cost}${RESET}"
fi

# Add model at the end
output="${output} ${CYAN}[${model_display_name}]${RESET}"

# Use echo with -e flag to interpret escape sequences
echo -e "$output"
