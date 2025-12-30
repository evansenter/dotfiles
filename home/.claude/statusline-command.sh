#!/bin/bash

# Read JSON input from stdin and extract all values in one jq call
read -r cwd current size < <(
    jq -r '[
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
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    if ! git -C "$cwd" diff --no-optional-locks --quiet 2>/dev/null || \
       ! git -C "$cwd" diff --no-optional-locks --cached --quiet 2>/dev/null; then
        git_status=" ${YELLOW}●${RESET}"
    fi
fi

# Context window percentage
context_display=""
if [ "$size" -gt 0 ] 2>/dev/null; then
    pct=$((current * 100 / size))
    context_display=" ${GRAY}${pct}%${RESET}"
fi

# Build status line: directory time git_status context
printf "%s%s%s %s%s%s%s%s %s→%s" \
    "$CYAN" "$cwd" "$RESET" \
    "$GRAY" "$(date +%H:%M:%S)" "$RESET" \
    "$git_status" "$context_display" \
    "$GREEN" "$RESET"
