#!/usr/bin/env bash

# Claude Code status line script
# Usage: Called automatically by Claude Code with JSON on stdin
# Example: echo '{"workspace":{"current_dir":"/path"},"context_window":{"current_usage":{...},"context_window_size":200000}}' | ~/.claude/statusline-command.sh

# Collect all output in a buffer to avoid interleaving with CC status messages
exec 3>&1  # Save stdout
exec 1>/dev/null 2>/dev/null  # Silence all output during computation

# Read JSON input from stdin (<&0 explicit since stdout/stderr are redirected above)
input=$(cat <&0)
if [[ -z "$input" ]]; then
    exec 1>&3 3>&-  # Restore stdout
    exit 1
fi

read -r cwd current size model_id transcript_path session_id < <(
    echo "$input" | jq -r '[
        .workspace.current_dir,
        ((.context_window.current_usage.input_tokens // 0) + (.context_window.current_usage.cache_creation_input_tokens // 0) + (.context_window.current_usage.cache_read_input_tokens // 0)),
        (.context_window.context_window_size // 0),
        (.model.id // ""),
        (.transcript_path // ""),
        (.session_id // "")
    ] | @tsv'
)

# ANSI color codes
CYAN=$'\e[36m'
GRAY=$'\e[90m'
YELLOW=$'\e[33m'
GREEN=$'\e[32m'
MAGENTA=$'\e[35m'
BLUE=$'\e[34m'
RESET=$'\e[0m'

# Event bus session name (cached per session_id to avoid repeated queries)
# Uses Claude's session UUID to look up the nice-named event bus session
session_display=""
EVENT_BUS_CLI="${HOME}/.local/bin/event-bus-cli"
if [[ -n "$session_id" ]]; then
    if [[ -x "$EVENT_BUS_CLI" ]]; then
        # Check cache first (session name doesn't change during a session)
        cache_dir="${TMPDIR:-/tmp}/claude-statusline"
        cache_file="${cache_dir}/${session_id}"

        # Clean up stale cache files (older than 24 hours)
        find "$cache_dir" -type f -mtime +1 -delete 2>/dev/null

        if [[ -f "$cache_file" ]]; then
            session_name=$(cat "$cache_file")
        else
            # Query event bus for session matching this client_id
            # Output format: "  session-name  repo/branch" then details on following lines
            # Strip ANSI escape codes (event-bus-cli may output colors for inactive sessions)
            session_name=$("$EVENT_BUS_CLI" sessions 2>/dev/null | \
                sed 's/\x1b\[[0-9;]*m//g' | \
                grep -B2 "client_id: ${session_id}" | \
                head -1 | \
                awk '{print $1}')

            # Cache the result (even if empty, to avoid repeated queries)
            mkdir -p "$cache_dir" && chmod 700 "$cache_dir" 2>/dev/null
            echo "$session_name" > "$cache_file" 2>/dev/null
        fi

        if [[ -z "$session_name" ]]; then
            # Session not found in event bus - show warning
            session_warning="no-session"
        fi
    else
        # event-bus-cli not installed - show warning
        session_warning="no-cli"
    fi
fi

# Git dirty status indicator
git_status=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    if ! git -C "$cwd" diff --quiet 2>/dev/null || \
       ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
        git_status=" ${YELLOW}●${RESET}"
    fi
fi

# Get repo URL for hyperlinks (used by directory, PR, and issues)
repo_url=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    repo_url=$(cd "$cwd" && gh repo view --json url -q .url 2>/dev/null)
fi

# Build combined [repo/session] display
dir_name="${cwd##*/}"
link_end=$'\e]8;;\e\\'

# Build repo part (cyan, with link if available)
if [[ -n "$repo_url" ]]; then
    link_start=$'\e]8;;'"${repo_url}"$'\e\\'
    repo_part="${CYAN}${link_start}${dir_name}${link_end}${RESET}"
else
    repo_part="${CYAN}${dir_name}${RESET}"
fi

# Build session part (magenta, or yellow warning)
if [[ -n "$session_name" ]]; then
    session_part="${MAGENTA}${session_name}${RESET}"
elif [[ -n "$session_warning" ]]; then
    session_part="${YELLOW}${session_warning}${RESET}"
else
    session_part=""
fi

# Combine into [repo/session] display
if [[ -n "$session_part" ]]; then
    repo_session_display="[${repo_part}/${session_part}]"
else
    repo_session_display="[${repo_part}]"
fi

# Associated PR or Issue indicator
pr_display=""
issue_display=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    # Get current branch for PR and issue lookups
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)

    # Check for associated PRs (supports multiple PRs to different bases)
    if [[ -n "$branch" ]]; then
        pr_list=$(cd "$cwd" && gh pr list --head "$branch" --json number,url -q '.[] | [.number, .url] | @tsv' 2>/dev/null)
        if [[ -n "$pr_list" ]]; then
            pr_links=""
            link_end=$'\e]8;;\e\\'
            while IFS=$'\t' read -r pr_number pr_url; do
                # Skip malformed entries
                [[ -z "$pr_number" || -z "$pr_url" ]] && continue
                [[ ! "$pr_number" =~ ^[0-9]+$ ]] && continue
                link_start=$'\e]8;;'"${pr_url}"$'\e\\'
                if [[ -n "$pr_links" ]]; then
                    pr_links="${pr_links},${link_start}#${pr_number}${link_end}"
                else
                    pr_links="${link_start}#${pr_number}${link_end}"
                fi
            done <<< "$pr_list"
            # Only set pr_display if we actually built valid links
            [[ -n "$pr_links" ]] && pr_display=" ${GREEN}${pr_links}${RESET}"
        fi
    fi

    # Check for linked issues - first from PR body, then from branch name
    issue_nums=""

    # 1. If PR exists, check body for issue refs (Fixes #N, Closes #N, etc.)
    if [[ -n "$pr_list" ]]; then
        pr_body=$(cd "$cwd" && gh pr view --json body -q '.body' 2>/dev/null)
        if [[ -n "$pr_body" ]]; then
            issue_nums=$(echo "$pr_body" | grep -oiE '(fixes|closes|resolves|addresses) #[0-9]+' | grep -oE '[0-9]+' | sort -u)
        fi
    fi

    # 2. Fall back to branch name with tight pattern (require issue-related prefix)
    if [[ -z "$issue_nums" ]] && [[ -n "$branch" ]]; then
        # Only match: issue-42, fix-42, bug-42, feat-42, feature-42
        issue_nums=$(echo "$branch" | grep -oE '(issue|fix|bug|feat|feature|closes|resolves)[-/][0-9]+' | grep -oE '[0-9]+' | sort -u)
    fi

    if [[ -n "$issue_nums" ]] && [[ -n "$repo_url" ]]; then
        issue_links=""
        link_end=$'\e]8;;\e\\'
        for issue_num in $issue_nums; do
            # Skip malformed entries
            [[ -z "$issue_num" ]] && continue
            [[ ! "$issue_num" =~ ^[0-9]+$ ]] && continue
            issue_url="${repo_url}/issues/${issue_num}"
            link_start=$'\e]8;;'"${issue_url}"$'\e\\'
            if [[ -n "$issue_links" ]]; then
                issue_links="${issue_links},${link_start}#${issue_num}${link_end}"
            else
                issue_links="${link_start}#${issue_num}${link_end}"
            fi
        done
        # Only set issue_display if we actually built valid links
        [[ -n "$issue_links" ]] && issue_display=" ${CYAN}→${issue_links}${RESET}"
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
    # Get last user message with string content (not tool result or system message)
    # User messages are infrequent (mostly tool results), so scan more lines
    # but still limit for performance on very long sessions
    # Use jq slurp to get the actual last string message, avoiding line-based issues
    # Filter out continuation summaries which start with "This session is being continued"
    last_user_msg=$(tail -n 500 "$transcript_path" 2>/dev/null | \
        jq -rs '[.[] | select(.type == "user") | .message.content | select(type == "string") | select(startswith("This session is being continued") | not)] | last // empty' 2>/dev/null)

    if [[ -n "$last_user_msg" ]]; then
        # Handle slash commands: extract args or command name
        cleaned_msg=""
        if [[ "$last_user_msg" == *"<command-args>"* ]]; then
            # Extract content between <command-args> and </command-args>
            cleaned_msg=$(printf '%s\n' "$last_user_msg" | sed -n 's/.*<command-args>\(.*\)<\/command-args>.*/\1/p')
        fi
        # If no args (empty or missing), try command name
        if [[ -z "$cleaned_msg" ]] && [[ "$last_user_msg" == *"<command-name>"* ]]; then
            cleaned_msg=$(printf '%s\n' "$last_user_msg" | sed -n 's/.*<command-name>\(.*\)<\/command-name>.*/\1/p')
        fi
        # If still empty, use plain message (strip XML tags and system preambles)
        if [[ -z "$cleaned_msg" ]]; then
            cleaned_msg=$(printf '%s\n' "$last_user_msg" | sed 's/<[^>]*>//g' | sed '/^Caveat:/d' | sed '/^$/d' | tail -1)
        fi

        # Truncate to ~10 words, lowercase, add ellipsis if truncated
        truncated=$(printf '%s\n' "$cleaned_msg" | awk '{
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

# Branch display (show if not on default branch)
branch_display=""
if [[ -n "$branch" ]] && [[ "$branch" != "main" ]] && [[ "$branch" != "master" ]]; then
    branch_display=":${BLUE}${branch}${RESET}"
fi

# Final hyperlink reset to ensure no unclosed hyperlinks leak
LINK_RESET=$'\e]8;;\e\\'

# Build the complete statusline
output=$(printf "%s%s%s%s %s%s%s%s%s" \
    "$repo_session_display" "$branch_display" \
    "$pr_display" "$issue_display" \
    "$model_display" \
    "$git_status" "$context_display" "$user_context" \
    "$LINK_RESET")

# Strip any newlines that might have snuck in (causes display issues in tmux)
output="${output//$'\n'/}"

# Restore stdout and print atomically
exec 1>&3 3>&-
printf "%s" "$output"
