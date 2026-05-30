#!/usr/bin/env bash

# Source user's environment for AGENT_EVENT_BUS_URL (suppress any output)
[[ -f ~/.extra ]] && source ~/.extra >/dev/null 2>&1

# Claude Code status line script
# Usage: Called automatically by Claude Code with JSON on stdin
# Example: echo '{"workspace":{"current_dir":"/path"},"context_window":{"current_usage":{"input_tokens":50000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":1000000},"model":{"id":"claude-opus-4-6"}}' | ~/.claude/statusline-command.sh

# Collect all output in a buffer to avoid interleaving with CC status messages
exec 3>&1  # Save stdout
exec 1>/dev/null 2>/dev/null  # Silence all output during computation

# Read JSON input from stdin (<&0 explicit since stdout/stderr are redirected above)
input=$(cat <&0)
if [[ -z "$input" ]]; then
    exec 1>&3 3>&-  # Restore stdout
    exit 1
fi

IFS=$'\t' read -r cwd session_id model_id model_name input_tokens cache_create_tokens cache_read_tokens context_size < <(
    echo "$input" | jq -r '[
        .workspace.current_dir,
        (.session_id // ""),
        (.model.id // ""),
        (.model.display_name // ""),
        (.context_window.current_usage.input_tokens // 0),
        (.context_window.current_usage.cache_creation_input_tokens // 0),
        (.context_window.current_usage.cache_read_input_tokens // 0),
        (.context_window.context_window_size // 0)
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

        nosession_sentinel="${cache_file}.miss"
        if [[ -f "$cache_file" ]]; then
            session_name=$(cat "$cache_file")
        elif find "$nosession_sentinel" -mmin -1 2>/dev/null | grep -q .; then
            # Recently failed to find this session; skip the retry loop so an
            # unregistered/bus-down session doesn't pay ~0.6s on every render.
            session_name=""
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

            mkdir -p "$cache_dir" && chmod 700 "$cache_dir" 2>/dev/null
            if [[ -n "$session_name" ]]; then
                echo "$session_name" > "$cache_file" 2>/dev/null
            else
                # Negative-cache the miss (~60s) to avoid re-running the retry loop every render.
                : > "$nosession_sentinel" 2>/dev/null
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

# Atomic cache write: temp + rename, so a concurrent render never reads a torn file.
cache_write() {
    local file="$1" val="$2"
    printf '%s' "$val" > "${file}.tmp.$$" 2>/dev/null && mv -f "${file}.tmp.$$" "$file" 2>/dev/null
}

# Bounded GitHub calls: the statusline renders on every prompt, so a hung gh
# (unauthenticated, offline, slow DNS/TLS) must never block. Wrap calls with a
# timeout (timeout on Linux, gtimeout from coreutils on macOS; no-op if neither)
# and short-circuit the whole GitHub section unless gh is installed AND authed.
if command -v timeout >/dev/null 2>&1; then
    GH_TIMEOUT=(timeout 3)
elif command -v gtimeout >/dev/null 2>&1; then
    GH_TIMEOUT=(gtimeout 3)
else
    GH_TIMEOUT=()
fi

gh_ok=false
if command -v gh >/dev/null 2>&1; then
    gh_auth_cache="${gh_cache_dir}/gh_auth_ok"
    if cache_fresh "$gh_auth_cache" 300; then
        [[ "$(cat "$gh_auth_cache" 2>/dev/null)" == "yes" ]] && gh_ok=true
    elif "${GH_TIMEOUT[@]}" gh auth status >/dev/null 2>&1; then
        gh_ok=true
        cache_write "$gh_auth_cache" "yes"
    else
        cache_write "$gh_auth_cache" "no"
    fi
fi

# Get repo URL for hyperlinks (cached per cwd — never changes within a session)
repo_url=""
if [[ -n "$cwd" ]] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    repo_cache_key=$(echo "$cwd" | tr '/' '_')
    repo_cache_file="${gh_cache_dir}/repo_${repo_cache_key}"

    if cache_fresh "$repo_cache_file" 3600; then
        repo_url=$(cat "$repo_cache_file")
        [[ "$repo_url" == "none" ]] && repo_url=""
    elif [[ "$gh_ok" == true ]]; then
        repo_url=$(cd "$cwd" && "${GH_TIMEOUT[@]}" gh repo view --json url -q .url 2>/dev/null)
        # Negative-cache empties so a transient failure doesn't re-block every render.
        cache_write "$repo_cache_file" "${repo_url:-none}"
    fi
fi

# Repo slug (owner_repo) for cache keys that must not collide across repos —
# PR #5 exists in nearly every repo, so body_/ci_ keyed on pr_num alone would
# serve repo A's PR data for repo B.
repo_slug="${repo_cache_key:-$(echo "${cwd:-}" | tr '/' '_')}"
if [[ -n "$repo_url" ]]; then
    repo_slug=$(echo "$repo_url" | sed -E 's#^https?://[^/]+/##; s#/#_#g')
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
        pr_cache_file="${gh_cache_dir}/pr_${repo_slug}_${branch_key}"
        if cache_fresh "$pr_cache_file" 60; then
            cached_val=$(cat "$pr_cache_file")
            [[ "$cached_val" != "none" ]] && pr_num="$cached_val"
        elif [[ "$gh_ok" == true ]]; then
            pr_num=$(cd "$cwd" && "${GH_TIMEOUT[@]}" gh pr list --head "$branch" --json number -q '.[0].number' 2>/dev/null)
            cache_write "$pr_cache_file" "${pr_num:-none}"
        fi
    fi

    # Check for linked issues - from PR body (cached with PR) or branch name
    if [[ -n "$pr_num" ]]; then
        body_cache_file="${gh_cache_dir}/body_${repo_slug}_${pr_num}"
        pr_body=""
        if cache_fresh "$body_cache_file" 60; then
            pr_body=$(cat "$body_cache_file")
            [[ "$pr_body" == "__EMPTY__" ]] && pr_body=""
        elif [[ "$gh_ok" == true ]]; then
            pr_body=$(cd "$cwd" && "${GH_TIMEOUT[@]}" gh pr view "$pr_num" --json body -q '.body' 2>/dev/null)
            # Negative-cache empty bodies (PR may legitimately have none) so we don't refetch every render.
            cache_write "$body_cache_file" "${pr_body:-__EMPTY__}"
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
        ci_cache_file="${gh_cache_dir}/ci_${repo_slug}_${pr_num}"

        ci_status=""
        if cache_fresh "$ci_cache_file" 30; then
            ci_status=$(cat "$ci_cache_file")
        elif [[ "$gh_ok" == true ]]; then
            checks_output=$(cd "$cwd" && "${GH_TIMEOUT[@]}" gh pr checks "$pr_num" 2>/dev/null || true)
            if [[ -n "$checks_output" ]]; then
                if echo "$checks_output" | awk -F'\t' '{print $2}' | grep -q "fail"; then
                    ci_status="fail"
                elif echo "$checks_output" | awk -F'\t' '{print $2}' | grep -q "pending"; then
                    ci_status="pending"
                else
                    ci_status="pass"
                fi
                cache_write "$ci_cache_file" "$ci_status"
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

# Model name — prefer the friendly display_name (e.g. "Opus 4.8") over the raw id
model_display="${model_name:-$model_id}"

# Context window usage percentage
context_display=""
if [[ "${context_size:-0}" -gt 0 ]]; then
    total_tokens=$(( ${input_tokens:-0} + ${cache_create_tokens:-0} + ${cache_read_tokens:-0} ))
    context_pct=$(( total_tokens * 100 / context_size ))
    # Color by usage: green <50%, yellow 50-79%, red 80%+
    if [[ "$context_pct" -ge 80 ]]; then
        context_display=" ${RED}${context_pct}%${RESET}"
    elif [[ "$context_pct" -ge 50 ]]; then
        context_display=" ${YELLOW}${context_pct}%${RESET}"
    else
        context_display=" ${GRAY}${context_pct}%${RESET}"
    fi
fi

# Combine model + context
model_context=""
if [[ -n "$model_display" ]]; then
    model_context=" ${GRAY}${model_display}${RESET}${context_display}"
fi

# Build the statusline (single line)
# Shows: [repo/session]:branch ✓/✗/↻ →#issues ● model context%
output=$(printf "%s%s%s%s%s%s%s" \
    "$repo_session_display" "$branch_display" \
    "$ci_display" "$issue_display" \
    "$git_status" "$model_context" "$LINK_RESET")

# Restore stdout and print atomically
exec 1>&3 3>&-
printf "%s" "$output"
