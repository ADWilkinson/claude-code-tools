#!/bin/bash

# Claude Code Statusline - Flying Dutchman Theme
# Author: Andrew Wilkinson (github.com/ADWilkinson)
#
# Layout: [where + what] | [health] | [spend + meta]
# Example: my-project main* [edit] +42 -7 | ctx:63% | $1.47 12m Opus@2.0.80

input=$(cat)

# --- Single jq call for all JSON extraction ---
eval "$(echo "$input" | jq -r '
  @sh "model_name=\(.model.display_name // "Claude")",
  @sh "current_dir=\(.workspace.current_dir // "~")",
  @sh "project_dir=\(.workspace.project_dir // "")",
  @sh "version=\(.version // "")",
  @sh "total_cost=\(.cost.total_cost_usd // 0)",
  @sh "total_duration_ms=\(.cost.total_duration_ms // 0)",
  @sh "lines_added=\(.cost.total_lines_added // 0)",
  @sh "lines_removed=\(.cost.total_lines_removed // 0)",
  @sh "ctx_used_pct=\(.context_window.used_percentage // "")",
  @sh "ctx_size=\(.context_window.context_window_size // "")",
  @sh "current_input=\(.context_window.current_usage.input_tokens // "")",
  @sh "exceeds_200k=\(.exceeds_200k_tokens // false)",
  @sh "vim_mode=\(.vim.mode // "")",
  @sh "agent_name=\(.agent.name // "")",
  @sh "current_activity=\(.current_activity // "")",
  @sh "active_tools=\((.active_tools // []) | join(","))"
' 2>/dev/null)"

# --- Format helpers (pure bash, no subprocesses) ---

format_tokens() {
    local n="$1"
    [ -z "$n" ] || [ "$n" = "null" ] && return
    if [ "$n" -ge 1000000 ] 2>/dev/null; then
        echo "$((n / 1000000)).$((n % 1000000 / 100000))M"
    elif [ "$n" -ge 1000 ] 2>/dev/null; then
        echo "$((n / 1000)).$((n % 1000 / 100))k"
    else
        echo "$n"
    fi
}

format_duration() {
    local ms="$1"
    [ "$ms" = "0" ] || [ -z "$ms" ] || [ "$ms" = "null" ] && return
    local s=$((ms / 1000))
    local h=$((s / 3600)) m=$(( (s % 3600) / 60 )) sec=$((s % 60))
    if [ "$h" -gt 0 ]; then echo "${h}h${m}m"
    elif [ "$m" -gt 0 ]; then echo "${m}m${sec}s"
    else echo "${sec}s"
    fi
}

# --- Derived values ---

current_folder=$(basename "$current_dir")

# Show relative path if we've cd'd into a subdirectory of the project
display_path="$current_folder"
if [ -n "$project_dir" ] && [ "$current_dir" != "$project_dir" ]; then
    relative="${current_dir#"$project_dir"}"
    if [ "$relative" != "$current_dir" ]; then
        display_path="$(basename "$project_dir")${relative}"
    fi
fi

# Git info (branch + dirty indicator + staged indicator)
git_info=""
if command -v git >/dev/null 2>&1 && git -C "$current_dir" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$current_dir" branch --show-current 2>/dev/null || git -C "$current_dir" rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        dirty=""
        ! git -C "$current_dir" diff-index --quiet HEAD -- 2>/dev/null && dirty="*"
        ! git -C "$current_dir" diff --cached --quiet 2>/dev/null && dirty="${dirty}+"
        git_info="${branch}${dirty}"
    fi
fi

# Activity detection (case statements, zero subprocesses)
activity=""
case "$active_tools" in
    *Bash*)
        case "$current_activity" in
            *dev*|*start*|*serve*)                   activity="dev" ;;
            *build*|*compile*)                        activity="build" ;;
            *test*|*spec*|*pytest*|*vitest*|*jest*)   activity="test" ;;
            *deploy*)                                 activity="deploy" ;;
            *install*|*add*)                          activity="install" ;;
            *lint*|*format*|*prettier*|*eslint*)      activity="lint" ;;
            *git*)                                    activity="git" ;;
            *)                                        activity="bash" ;;
        esac ;;
    *Edit*|*Write*|*MultiEdit*)  activity="edit" ;;
    *Read*)                      activity="read" ;;
    *Grep*|*Glob*)               activity="search" ;;
    *Task*)                      activity="agent" ;;
    *WebSearch*|*WebFetch*)      activity="web" ;;
    *SendMessage*)               activity="msg" ;;
    *Notebook*)                  activity="notebook" ;;
esac

duration_str=$(format_duration "$total_duration_ms")

# --- Colors ---
GRN="\033[32m" BLU="\033[34m" CYN="\033[36m" MAG="\033[35m"
YEL="\033[33m" RED="\033[31m" GRY="\033[90m" WHT="\033[97m"
BLD="\033[1m" DIM="\033[2m" RST="\033[0m"

# Context color: green < 50%, yellow 50-79%, red 80%+
ctx_color="$GRN"
if [ -n "$ctx_used_pct" ] && [ "$ctx_used_pct" != "null" ]; then
    [ "$ctx_used_pct" -ge 80 ] 2>/dev/null && ctx_color="$RED"
    [ "$ctx_used_pct" -ge 50 ] 2>/dev/null && [ "$ctx_used_pct" -lt 80 ] 2>/dev/null && ctx_color="$YEL"
fi

sep=" ${GRY}|${RST} "

# ============================================================
# GROUP 1: Where + What
# ============================================================
out="${BLU}${BLD}${display_path}${RST}"

[ -n "$git_info" ] && out="${out} ${MAG}${git_info}${RST}"

[ -n "$activity" ] && out="${out} ${WHT}[${activity}]${RST}"

# Vim mode (only when enabled)
if [ -n "$vim_mode" ] && [ "$vim_mode" != "null" ]; then
    case "$vim_mode" in
        INSERT) out="${out} ${GRN}INS${RST}" ;;
        *)      out="${out} ${CYN}NOR${RST}" ;;
    esac
fi

# Agent name (only when running as/with agent)
[ -n "$agent_name" ] && [ "$agent_name" != "null" ] && \
    out="${out} ${DIM}agent:${RST}${CYN}${agent_name}${RST}"

# Lines changed (only when non-zero)
if [ "$lines_added" != "0" ] || [ "$lines_removed" != "0" ]; then
    out="${out} ${GRN}+${lines_added}${RST} ${RED}-${lines_removed}${RST}"
fi

# ============================================================
# GROUP 2: Context Health
# ============================================================
ctx_section=""
if [ -n "$ctx_used_pct" ] && [ "$ctx_used_pct" != "null" ]; then
    ctx_section="${ctx_color}ctx:${ctx_used_pct}%${RST}"

    # Show raw token counts only when context is getting full (>= 50%)
    if [ "$ctx_used_pct" -ge 50 ] 2>/dev/null && [ -n "$current_input" ] && [ "$current_input" != "null" ]; then
        tok_str=$(format_tokens "$current_input")
        size_str=$(format_tokens "$ctx_size")
        [ -n "$size_str" ] && ctx_section="${ctx_section}${GRY}(${tok_str}/${size_str})${RST}"
    fi

    # Exceeds 200k warning
    [ "$exceeds_200k" = "true" ] && ctx_section="${ctx_section} ${RED}${BLD}!200k${RST}"
fi

[ -n "$ctx_section" ] && out="${out}${sep}${ctx_section}"

# ============================================================
# GROUP 3: Cost + Time + Model
# ============================================================
meta=""

# Cost
if [ "$total_cost" != "0" ] && [ -n "$total_cost" ]; then
    formatted_cost=$(printf "%.2f" "$total_cost" 2>/dev/null || echo "$total_cost")
    meta="${YEL}\$${formatted_cost}${RST}"
fi

# Duration
if [ -n "$duration_str" ]; then
    [ -n "$meta" ] && meta="${meta} "
    meta="${meta}${DIM}${duration_str}${RST}"
fi

# Model + version
model_section="${CYN}${model_name}${RST}"
[ -n "$version" ] && [ "$version" != "null" ] && \
    model_section="${model_section}${GRY}@${version}${RST}"

[ -n "$meta" ] && meta="${meta} "
meta="${meta}${model_section}"

out="${out}${sep}${meta}"

echo -e "$out"
