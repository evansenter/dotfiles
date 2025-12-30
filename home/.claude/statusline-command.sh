#!/usr/bin/env bash

# Claude Code status line script
# Usage: Called automatically by Claude Code with JSON on stdin
# Example: echo '{"workspace":{"current_dir":"/path"},"context_window":{"current_usage":{...},"context_window_size":200000}}' | ~/.claude/statusline-command.sh

# Read JSON input from stdin and extract all values in one jq call
input=$(cat)
if [[ -z "$input" ]]; then
    exit 1
fi

read -r cwd current size < <(
    echo "$input" | jq -r '[
        .workspace.current_dir,
        (.context_window.current_usage | .input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens // 0),
        (.context_window.context_window_size // 0)
    ] | @tsv'
)

# ANSI color codes
CYAN=$'\e[36m'
GRAY=$'\e[90m'
YELLOW=$'\e[33m'
GREEN=$'\e[32m'
RESET=$'\e[0m'

# Git dirty status indicator
git_status=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    if ! git -C "$cwd" diff --quiet 2>/dev/null || \
       ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
        git_status=" ${YELLOW}●${RESET}"
    fi
fi

# Context window percentage
context_display=""
if [[ "$size" =~ ^[0-9]+$ ]] && [[ "$current" =~ ^[0-9]+$ ]] && [ "$size" -gt 0 ]; then
    pct=$((current * 100 / size))
    context_display=" ${GRAY}${pct}%${RESET}"
fi

# Model name from settings.json
model_display=""
if [[ -f ~/.claude/settings.json ]]; then
    model_name=$(jq -r '.model // empty' ~/.claude/settings.json 2>/dev/null)
    if [[ -n "$model_name" ]]; then
        model_display="${GRAY}${model_name}${RESET}"
    fi
fi

# Build status line: directory model git_status context
printf "%s%s%s %s%s%s" \
    "$CYAN" "$cwd" "$RESET" \
    "$model_display" \
    "$git_status" "$context_display"
