#!/usr/bin/env bash

# Source user's environment for AGENT_EVENT_BUS_URL (suppress any output)
[[ -f ~/.extra ]] && source ~/.extra >/dev/null 2>&1

# Claude Code status line script
# Usage: Called automatically by Claude Code with JSON on stdin
# Example: echo '{"workspace":{"current_dir":"/path"},"context_window":{"used_percentage":42},"model":{"id":"claude-opus-4-6"}}' | ~/.claude/statusline-command.sh

# Collect all output in a buffer to avoid interleaving with CC status messages
exec 3>&1  # Save stdout
exec 1>/dev/null 2>/dev/null  # Silence all output during computation

# Read JSON input from stdin (<&0 explicit since stdout/stderr are redirected above)
input=$(cat <&0)
if [[ -z "$input" ]]; then
    exec 1>&3 3>&-  # Restore stdout
    exit 1
fi

IFS=$'\t' read -r cwd session_id < <(
    echo "$input" | jq -r '[
        .workspace.current_dir,
        (.session_id // "")
    ] | @tsv'
)

# ANSI color codes
CYAN=$'\e[36m'
RED=$'\e[31m'
GRAY=$'\e[90m'
YELLOW=$'\e[33m'
GREEN=$'\e[32m'
MAGENTA=$'\e[35m'
BLUE=$'\e[34m'
RESET=$'\e[0m'

# Hyperlink toggle - set STATUSLINE_NO_LINKS=1 to disable (debug CC injection issues)
NO_LINKS="${STATUSLINE_NO_LINKS:-}"

# Event bus session name (cached per session_id to avoid repeated queries)
# Uses Claude's session UUID to look up the nice-named event bus session
EVENT_BUS_CLI="${HOME}/.local/bin/agent-event-bus-cli"
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
            # Retry briefly: statusline can fire before session-start hook registers
            for _attempt in 1 2 3; do
                session_name=$("$EVENT_BUS_CLI" sessions 2>/dev/null | \
                    sed 's/\x1b\[[0-9;]*m//g' | \
                    grep -B2 "client_id: ${session_id}" | \
                    head -1 | \
                    awk '{print $1}')
                [[ -n "$session_name" ]] && break
                sleep 0.2
            done

            # Cache only successful lookups (empty = session not registered yet)
            if [[ -n "$session_name" ]]; then
                mkdir -p "$cache_dir" && chmod 700 "$cache_dir" 2>/dev/null
                echo "$session_name" > "$cache_file" 2>/dev/null
            fi
        fi

        if [[ -z "$session_name" ]]; then
            # Session not found after retries
            session_warning="no-session"
        fi
    else
        # agent-event-bus-cli not installed - show warning
        session_warning="no-cli"
    fi
fi

# Git dirty status indicator
git_status=""
git_dirty=false
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    if ! git -C "$cwd" diff --quiet 2>/dev/null || \
       ! git -C "$cwd" diff --cached --quiet 2>/dev/null; then
        git_status=" ${YELLOW}●${RESET}"
        git_dirty=true
    fi
fi

# GitHub API cache (repo URL, PR number, PR body, CI status)
gh_cache_dir="${TMPDIR:-/tmp}/claude-statusline-gh"
mkdir -p "$gh_cache_dir" && chmod 700 "$gh_cache_dir" 2>/dev/null
find "$gh_cache_dir" -type f -mtime +1 -delete 2>/dev/null

# Helper: check if cache file is fresh (returns 0 if fresh, 1 if stale/missing)
cache_fresh() {
    local file="$1" ttl="$2"
    [[ -f "$file" ]] || return 1
    local mtime
    if [[ "$(uname)" == "Darwin" ]]; then
        mtime=$(stat -f %m "$file" 2>/dev/null || echo 0)
    else
        mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
    fi
    (( $(date +%s) - mtime < ttl ))
}

# Get repo URL for hyperlinks (cached per cwd — never changes within a session)
repo_url=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    repo_cache_key=$(echo "$cwd" | tr '/' '_')
    repo_cache_file="${gh_cache_dir}/repo_${repo_cache_key}"

    if [[ -f "$repo_cache_file" ]]; then
        repo_url=$(cat "$repo_cache_file")
    else
        repo_url=$(cd "$cwd" && gh repo view --json url -q .url 2>/dev/null)
        if [[ -n "$repo_url" ]]; then
            echo "$repo_url" > "$repo_cache_file" 2>/dev/null
        fi
    fi
fi

# Build combined [repo/session] display
# Handle worktrees: if in .worktrees/<branch>, show "branch (repo)"
# Note: This assumes the /parallel-work convention (.worktrees/ directory),
# not arbitrary git worktrees which can be placed anywhere.
dir_name="${cwd##*/}"
if [[ "$cwd" == */.worktrees/* ]]; then
    # Extract repo name from parent of .worktrees
    worktree_parent="${cwd%/.worktrees/*}"
    repo_name="${worktree_parent##*/}"
    worktree_branch="${cwd##*/}"
    dir_name="${repo_name} (${worktree_branch})"
fi
link_end=$'\e]8;;\e\\'

# Build repo part (cyan, with link if available)
if [[ -n "$repo_url" ]] && [[ -z "$NO_LINKS" ]]; then
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

# PR, issue, and CI indicators
# PR links are shown natively by Claude Code on line 3, so we only show CI status and issues
issue_display=""
ci_display=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)

    # Check for associated PRs (cached per branch, 60s TTL)
    pr_num=""
    if [[ -n "$branch" ]]; then
        branch_key=$(echo "$branch" | tr '/' '_')
        pr_cache_file="${gh_cache_dir}/pr_${branch_key}"
        if cache_fresh "$pr_cache_file" 60; then
            cached_val=$(cat "$pr_cache_file")
            [[ "$cached_val" != "none" ]] && pr_num="$cached_val"
        else
            pr_num=$(cd "$cwd" && gh pr list --head "$branch" --json number -q '.[0].number' 2>/dev/null)
            echo "${pr_num:-none}" > "$pr_cache_file" 2>/dev/null
        fi
    fi

    # Check for linked issues - from PR body (cached with PR) or branch name
    if [[ -n "$pr_num" ]]; then
        body_cache_file="${gh_cache_dir}/body_${pr_num}"
        pr_body=""
        if cache_fresh "$body_cache_file" 60; then
            pr_body=$(cat "$body_cache_file")
        fi
        if [[ -z "$pr_body" ]]; then
            pr_body=$(cd "$cwd" && gh pr view "$pr_num" --json body -q '.body' 2>/dev/null)
            if [[ -n "$pr_body" ]]; then
                echo "$pr_body" > "$body_cache_file" 2>/dev/null
            fi
        fi
        if [[ -n "$pr_body" ]]; then
            issue_nums=$(echo "$pr_body" | grep -oiE '(fixes|closes|resolves|addresses) #[0-9]+' | grep -oE '[0-9]+' | sort -u)
        fi
    fi

    if [[ -z "${issue_nums:-}" ]] && [[ -n "$branch" ]]; then
        issue_nums=$(echo "$branch" | grep -oE '(issue|fix|bug|feat|feature|closes|resolves)[-/][0-9]+' | grep -oE '[0-9]+' | sort -u)
    fi

    if [[ -n "${issue_nums:-}" ]] && [[ -n "$repo_url" ]]; then
        issue_links=""
        link_end=$'\e]8;;\e\\'
        for issue_num in $issue_nums; do
            [[ -z "$issue_num" || ! "$issue_num" =~ ^[0-9]+$ ]] && continue
            if [[ -z "$NO_LINKS" ]]; then
                issue_url="${repo_url}/issues/${issue_num}"
                link_start=$'\e]8;;'"${issue_url}"$'\e\\'
                issue_links="${issue_links:+${issue_links},}${link_start}#${issue_num}${link_end}"
            else
                issue_links="${issue_links:+${issue_links},}#${issue_num}"
            fi
        done
        [[ -n "$issue_links" ]] && issue_display=" ${CYAN}→${issue_links}${RESET}"
    fi

    # CI status indicator (cached for 30s, hidden when dirty — result is stale)
    if [[ -n "$pr_num" ]] && [[ "$git_dirty" == false ]]; then
        ci_cache_file="${gh_cache_dir}/ci_${pr_num}"

        ci_status=""
        if cache_fresh "$ci_cache_file" 30; then
            ci_status=$(cat "$ci_cache_file")
        fi

        if [[ -z "$ci_status" ]]; then
            checks_output=$(cd "$cwd" && gh pr checks "$pr_num" 2>/dev/null || true)
            if [[ -n "$checks_output" ]]; then
                if echo "$checks_output" | awk -F'\t' '{print $2}' | grep -q "fail"; then
                    ci_status="fail"
                elif echo "$checks_output" | awk -F'\t' '{print $2}' | grep -q "pending"; then
                    ci_status="pending"
                else
                    ci_status="pass"
                fi
                echo "$ci_status" > "$ci_cache_file" 2>/dev/null
            fi
        fi

        case "$ci_status" in
            pass)    ci_display=" ${GREEN}✓${RESET}" ;;
            fail)    ci_display=" ${RED}✗${RESET}" ;;
            pending) ci_display=" ${YELLOW}↻${RESET}" ;;
        esac
    fi
fi

# Branch display (show if not on default branch)
branch_display=""
if [[ -n "$branch" ]] && [[ "$branch" != "main" ]] && [[ "$branch" != "master" ]]; then
    branch_display=":${BLUE}${branch}${RESET}"
fi

# Final hyperlink reset to ensure no unclosed hyperlinks leak
LINK_RESET=$'\e]8;;\e\\'

# Build the statusline (single line)
# Shows: [repo/session]:branch ✓/✗/↻ →#issues ●
output=$(printf "%s%s%s%s%s%s" \
    "$repo_session_display" "$branch_display" \
    "$ci_display" "$issue_display" \
    "$git_status" "$LINK_RESET")

# Restore stdout and print atomically
exec 1>&3 3>&-
printf "%s" "$output"
