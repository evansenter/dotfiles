#!/usr/bin/env bash

# Claude Code status line script
# Usage: Called automatically by Claude Code with JSON on stdin
# Example: echo '{"workspace":{"current_dir":"/path"},"context_window":{"current_usage":{...},"context_window_size":200000}}' | ~/.claude/statusline-command.sh

# Read JSON input from stdin and extract all values in one jq call
input=$(cat)
if [[ -z "$input" ]]; then
    exit 1
fi

read -r cwd current size model_id transcript_path < <(
    echo "$input" | jq -r '[
        .workspace.current_dir,
        (.context_window.current_usage | .input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens // 0),
        (.context_window.context_window_size // 0),
        (.model.id // ""),
        (.transcript_path // "")
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

# Last user message context (truncated to ~10 words)
user_context=""
if [[ -n "$transcript_path" ]] && [[ -r "$transcript_path" ]]; then
    # Get last user message with string content (not tool result)
    # User messages are infrequent (mostly tool results), so scan more lines
    # but still limit for performance on very long sessions
    last_user_msg=$(tail -n 500 "$transcript_path" 2>/dev/null | \
        jq -r 'select(.type == "user") | .message.content | select(type == "string")' 2>/dev/null | \
        tail -1)

    if [[ -n "$last_user_msg" ]]; then
        # Truncate to ~10 words, lowercase, add ellipsis if truncated
        truncated=$(echo "$last_user_msg" | awk '{
            gsub(/\n/, " ")
            words = ""
            for (i=1; i<=NF && i<=10; i++) {
                words = words (i>1 ? " " : "") tolower($i)
            }
            if (NF > 10) words = words "..."
            print words
        }')
        user_context=" ${GRAY}(${truncated})${RESET}"
    fi
fi

# Model display from input JSON
if [[ -n "$model_id" ]]; then
    model_display="${GRAY}${model_id}${RESET}"
else
    model_display="${GRAY}(unknown model)${RESET}"
fi

# Build status line: directory model git_status context user_context
dir_name="${cwd##*/}"
printf "%s%s%s %s%s%s%s" \
    "$CYAN" "$dir_name" "$RESET" \
    "$model_display" \
    "$git_status" "$context_display" "$user_context"
