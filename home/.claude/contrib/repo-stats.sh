#!/usr/bin/env bash
# repo-stats.sh - Show code stats across repositories
#
# Usage: repo-stats.sh [--days N] [--session-stats] [repo1 repo2 ...]
#
# Examples:
#   repo-stats.sh                    # Default repos, last 30 days
#   repo-stats.sh --days 28          # Last 28 days
#   repo-stats.sh --session-stats    # Include Claude session analytics
#   repo-stats.sh myrepo otherrepo   # Custom repos

set -euo pipefail

# Defaults
DAYS=30
SESSION_STATS=0
OWNER="evansenter"
LOCAL_DIR="$HOME/projects"
DEFAULT_REPOS="dotfiles gemicro agent-event-bus agent-session-analytics rust-genai"
REPOS=""

# Check for scc
HAS_SCC=$(command -v scc >/dev/null 2>&1 && echo "1" || echo "0")

# Check for session-analytics CLI
SESSION_CLI=""
if [[ -x "$HOME/projects/agent-session-analytics/.venv/bin/agent-session-analytics-cli" ]]; then
    SESSION_CLI="$HOME/projects/agent-session-analytics/.venv/bin/agent-session-analytics-cli"
elif command -v agent-session-analytics-cli >/dev/null 2>&1; then
    SESSION_CLI="agent-session-analytics-cli"
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --days)
            DAYS="$2"
            shift 2
            ;;
        --owner)
            OWNER="$2"
            shift 2
            ;;
        --local-dir)
            LOCAL_DIR="$2"
            shift 2
            ;;
        --session-stats)
            SESSION_STATS=1
            shift
            ;;
        --help|-h)
            echo "Usage: repo-stats.sh [--days N] [--owner OWNER] [--local-dir DIR] [--session-stats] [repo1 repo2 ...]"
            echo ""
            echo "Options:"
            echo "  --days N          Look back N days (default: 30)"
            echo "  --owner NAME      GitHub owner (default: evansenter)"
            echo "  --local-dir DIR   Local repos directory (default: ~/projects)"
            echo "  --session-stats   Include Agent Session Analytics"
            echo ""
            echo "If repos are specified, uses those instead of defaults."
            echo "Uses 'scc' for accurate LoC if installed and repos exist locally."
            echo "Uses 'agent-session-analytics-cli' for session stats if available."
            exit 0
            ;;
        *)
            REPOS="$REPOS $1"
            shift
            ;;
    esac
done

REPOS="${REPOS:-$DEFAULT_REPOS}"

# Calculate date for API query
if [[ "$(uname)" == "Darwin" ]]; then
    SINCE=$(date -v-${DAYS}d '+%Y-%m-%dT00:00:00Z')
else
    SINCE=$(date -d "-${DAYS} days" '+%Y-%m-%dT00:00:00Z')
fi

echo "## Repository Statistics"
echo ""
echo "**Period:** Last $DAYS days (since ${SINCE:0:10})"
echo "**Owner:** $OWNER"
echo ""

# Helper function to print a table data row
# Args: column widths..., then values
print_row() {
    local widths=("$@")
    local values_start=0

    # Find where values start (after all numeric widths)
    for i in "${!widths[@]}"; do
        if [[ ! "${widths[$i]}" =~ ^[0-9]+$ ]]; then
            values_start=$i
            break
        fi
    done

    local col_widths=("${widths[@]:0:$values_start}")
    local values=("${widths[@]:$values_start}")

    printf "│"
    for i in "${!col_widths[@]}"; do
        local w="${col_widths[$i]}"
        printf " %-${w}s │" "${values[$i]}"
    done
    printf "\n"
}

# Print project stats table
echo "### Project Stats"
echo ""

# Column widths for project stats
pw1=26  # Repo
pw2=12  # Issues (open/closed)
pw3=12  # PRs (open/closed)
pw4=8   # Commits

printf "┌%s┬%s┬%s┬%s┐\n" \
    "$(printf '─%.0s' $(seq 1 $((pw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw3 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw4 + 2))))"
print_row $pw1 $pw2 $pw3 $pw4 "Repository" "Issues" "PRs" "Commits"
printf "├%s┼%s┼%s┼%s┤\n" \
    "$(printf '─%.0s' $(seq 1 $((pw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw3 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw4 + 2))))"

# Totals for project stats
total_open_issues=0
total_closed_issues=0
total_open_prs=0
total_closed_prs=0
total_proj_commits=0

for repo in $REPOS; do
    # Get open issues (excluding PRs)
    open_issues_total=$(gh api "repos/$OWNER/$repo" --jq '.open_issues_count // 0' 2>/dev/null) || open_issues_total="0"
    open_prs=$(gh api "repos/$OWNER/$repo/pulls?state=open" --jq 'length' 2>/dev/null) || open_prs="0"
    open_issues=$((open_issues_total - open_prs))

    # Get closed issues in period (search API filters out PRs with is:issue)
    closed_issues=$(gh api "search/issues?q=repo:$OWNER/$repo+is:issue+is:closed+closed:>=$SINCE&per_page=1" --jq '.total_count // 0' 2>/dev/null) || closed_issues="0"

    # Get closed PRs in period
    closed_prs=$(gh api "search/issues?q=repo:$OWNER/$repo+is:pr+is:closed+closed:>=$SINCE&per_page=1" --jq '.total_count // 0' 2>/dev/null) || closed_prs="0"

    # Get commits in period (paginate for full count)
    commits=0
    page=1
    while true; do
        page_count=$(gh api "repos/$OWNER/$repo/commits?since=$SINCE&per_page=100&page=$page" --jq 'length' 2>/dev/null) || page_count="0"
        commits=$((commits + page_count))
        # Stop if we got fewer than 100 (last page)
        [[ "$page_count" -lt 100 ]] && break
        page=$((page + 1))
    done

    # Accumulate totals
    total_open_issues=$((total_open_issues + open_issues))
    total_closed_issues=$((total_closed_issues + closed_issues))
    total_open_prs=$((total_open_prs + open_prs))
    total_closed_prs=$((total_closed_prs + closed_prs))
    total_proj_commits=$((total_proj_commits + commits))

    issues_fmt="${open_issues}/${closed_issues}"
    prs_fmt="${open_prs}/${closed_prs}"

    print_row $pw1 $pw2 $pw3 $pw4 "$repo" "$issues_fmt" "$prs_fmt" "$commits"
done

printf "├%s┼%s┼%s┼%s┤\n" \
    "$(printf '─%.0s' $(seq 1 $((pw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw3 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw4 + 2))))"
print_row $pw1 $pw2 $pw3 $pw4 "TOTAL" "${total_open_issues}/${total_closed_issues}" "${total_open_prs}/${total_closed_prs}" "$total_proj_commits"
printf "└%s┴%s┴%s┴%s┘\n" \
    "$(printf '─%.0s' $(seq 1 $((pw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw3 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw4 + 2))))"
echo ""
echo "_Format: open/closed (closed in last ${DAYS}d)_"

echo ""

# Print codebase sizes table
echo "### Codebase Size"
echo ""

# Column widths for codebase size
cw1=26  # Repo
cw2=8   # Language
cw3=8   # Code
cw4=8   # Comments
cw5=8   # Blanks
cw6=8   # Total

total_code=0
total_comments=0
total_blanks=0
total_lines=0

if [[ "$HAS_SCC" == "1" ]]; then
    printf "┌%s┬%s┬%s┬%s┬%s┬%s┐\n" \
        "$(printf '─%.0s' $(seq 1 $((cw1 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw2 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw3 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw4 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw5 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw6 + 2))))"
    print_row $cw1 $cw2 $cw3 $cw4 $cw5 $cw6 "Repository" "Language" "Code" "Comments" "Blanks" "Total"
    printf "├%s┼%s┼%s┼%s┼%s┼%s┤\n" \
        "$(printf '─%.0s' $(seq 1 $((cw1 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw2 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw3 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw4 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw5 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw6 + 2))))"
else
    printf "┌%s┬%s┬%s┐\n" \
        "$(printf '─%.0s' $(seq 1 $((cw1 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw2 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw3 + 2))))"
    print_row $cw1 $cw2 $cw3 "Repository" "Language" "LoC (est.)"
    printf "├%s┼%s┼%s┤\n" \
        "$(printf '─%.0s' $(seq 1 $((cw1 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw2 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw3 + 2))))"
fi

for repo in $REPOS; do
    lang=$(gh api "repos/$OWNER/$repo" --jq '.language // "Unknown"' 2>/dev/null || echo "Unknown")
    local_path="$LOCAL_DIR/$repo"

    if [[ "$HAS_SCC" == "1" && -d "$local_path" ]]; then
        # Use scc for accurate counts, excluding build artifacts and worktrees
        scc_output=$(scc --no-cocomo --no-complexity --exclude-dir .worktrees,target,node_modules,vendor,dist,build,.git -f json "$local_path" 2>/dev/null | jq -r '[.[] | select(.Name != "Total")] | map({code: .Code, comments: .Comment, blanks: .Blank, lines: .Lines}) | {code: (map(.code) | add), comments: (map(.comments) | add), blanks: (map(.blanks) | add), lines: (map(.lines) | add)} | "\(.code) \(.comments) \(.blanks) \(.lines)"')
        code=$(echo "$scc_output" | awk '{print $1}')
        comments=$(echo "$scc_output" | awk '{print $2}')
        blanks=$(echo "$scc_output" | awk '{print $3}')
        lines=$(echo "$scc_output" | awk '{print $4}')

        total_code=$((total_code + code))
        total_comments=$((total_comments + comments))
        total_blanks=$((total_blanks + blanks))
        total_lines=$((total_lines + lines))

        # Format numbers with commas
        code_fmt=$(printf "%'d" "$code")
        comments_fmt=$(printf "%'d" "$comments")
        blanks_fmt=$(printf "%'d" "$blanks")
        lines_fmt=$(printf "%'d" "$lines")

        print_row $cw1 $cw2 $cw3 $cw4 $cw5 $cw6 "$repo" "$lang" "$code_fmt" "$comments_fmt" "$blanks_fmt" "$lines_fmt"
    else
        # Fall back to API estimate
        total_bytes=$(gh api "repos/$OWNER/$repo/languages" --jq 'to_entries | map(.value) | add // 0' 2>/dev/null || echo "0")
        loc=$((total_bytes / 35))
        total_code=$((total_code + loc))

        if [[ $loc -ge 1000 ]]; then
            loc_fmt="~$(echo "scale=1; $loc / 1000" | bc)K"
        else
            loc_fmt="~$loc"
        fi

        print_row $cw1 $cw2 $cw3 "$repo" "$lang" "$loc_fmt"
    fi
done

if [[ "$HAS_SCC" == "1" ]]; then
    printf "├%s┼%s┼%s┼%s┼%s┼%s┤\n" \
        "$(printf '─%.0s' $(seq 1 $((cw1 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw2 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw3 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw4 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw5 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw6 + 2))))"
    code_fmt=$(printf "%'d" "$total_code")
    comments_fmt=$(printf "%'d" "$total_comments")
    blanks_fmt=$(printf "%'d" "$total_blanks")
    lines_fmt=$(printf "%'d" "$total_lines")
    print_row $cw1 $cw2 $cw3 $cw4 $cw5 $cw6 "TOTAL" "" "$code_fmt" "$comments_fmt" "$blanks_fmt" "$lines_fmt"
    printf "└%s┴%s┴%s┴%s┴%s┴%s┘\n" \
        "$(printf '─%.0s' $(seq 1 $((cw1 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw2 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw3 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw4 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw5 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw6 + 2))))"
else
    printf "├%s┼%s┼%s┤\n" \
        "$(printf '─%.0s' $(seq 1 $((cw1 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw2 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw3 + 2))))"
    if [[ $total_code -ge 1000 ]]; then
        total_fmt="~$(echo "scale=1; $total_code / 1000" | bc)K"
    else
        total_fmt="~$total_code"
    fi
    print_row $cw1 $cw2 $cw3 "TOTAL" "" "$total_fmt"
    printf "└%s┴%s┴%s┘\n" \
        "$(printf '─%.0s' $(seq 1 $((cw1 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw2 + 2))))" \
        "$(printf '─%.0s' $(seq 1 $((cw3 + 2))))"
fi
echo ""

# Print activity table
echo "### Recent Activity"
echo ""

# Column widths for activity
aw1=26  # Repo
aw2=7   # Commits
aw3=10  # Additions
aw4=10  # Deletions
aw5=10  # Net

printf "┌%s┬%s┬%s┬%s┬%s┐\n" \
    "$(printf '─%.0s' $(seq 1 $((aw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw3 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw4 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw5 + 2))))"
print_row $aw1 $aw2 $aw3 $aw4 $aw5 "Repository" "Commits" "Additions" "Deletions" "Net"
printf "├%s┼%s┼%s┼%s┼%s┤\n" \
    "$(printf '─%.0s' $(seq 1 $((aw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw3 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw4 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw5 + 2))))"

total_commits=0
total_add=0
total_del=0

for repo in $REPOS; do
    # Paginate to get full commit count
    commits=0
    page=1
    while true; do
        page_count=$(gh api "repos/$OWNER/$repo/commits?since=$SINCE&per_page=100&page=$page" --jq 'length' 2>/dev/null) || page_count="0"
        commits=$((commits + page_count))
        [[ "$page_count" -lt 100 ]] && break
        page=$((page + 1))
    done

    if [[ "$commits" -gt 0 ]]; then
        stats=$(gh api "repos/$OWNER/$repo/commits?since=$SINCE&per_page=30" --jq '.[].sha' 2>/dev/null | \
            while read -r sha; do
                gh api "repos/$OWNER/$repo/commits/$sha" --jq '.stats | "\(.additions // 0) \(.deletions // 0)"' 2>/dev/null || echo "0 0"
            done | awk '{add+=$1; del+=$2} END {print add" "del}')
        add=$(echo "$stats" | awk '{print $1}')
        del=$(echo "$stats" | awk '{print $2}')
    else
        add=0
        del=0
    fi

    net=$((add - del))
    total_commits=$((total_commits + commits))
    total_add=$((total_add + add))
    total_del=$((total_del + del))

    # Format with +/- signs
    add_fmt="+$add"
    del_fmt="-$del"
    if [[ $net -ge 0 ]]; then
        net_fmt="+$net"
    else
        net_fmt="$net"
    fi

    print_row $aw1 $aw2 $aw3 $aw4 $aw5 "$repo" "$commits" "$add_fmt" "$del_fmt" "$net_fmt"
done

total_net=$((total_add - total_del))
printf "├%s┼%s┼%s┼%s┼%s┤\n" \
    "$(printf '─%.0s' $(seq 1 $((aw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw3 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw4 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw5 + 2))))"
if [[ $total_net -ge 0 ]]; then
    total_net_fmt="+$total_net"
else
    total_net_fmt="$total_net"
fi
print_row $aw1 $aw2 $aw3 $aw4 $aw5 "TOTAL" "$total_commits" "+$total_add" "-$total_del" "$total_net_fmt"
printf "└%s┴%s┴%s┴%s┴%s┘\n" \
    "$(printf '─%.0s' $(seq 1 $((aw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw3 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw4 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((aw5 + 2))))"

# Print combined language breakdown if scc available and local repos exist
if [[ "$HAS_SCC" == "1" ]]; then
    # Build list of existing local paths
    local_paths=""
    for repo in $REPOS; do
        local_path="$LOCAL_DIR/$repo"
        if [[ -d "$local_path" ]]; then
            local_paths="$local_paths $local_path"
        fi
    done

    if [[ -n "$local_paths" ]]; then
        echo ""
        echo "### Language Breakdown"
        echo ""
        echo '```'
        scc --exclude-dir .worktrees,target,node_modules,vendor,dist,build,.git $local_paths
        echo '```'
    fi
fi

# Print session analytics if requested and CLI available
if [[ "$SESSION_STATS" == "1" ]]; then
    if [[ -z "$SESSION_CLI" ]]; then
        echo ""
        echo "### Session Analytics"
        echo ""
        echo "_agent-session-analytics-cli not found. Install from agent-session-analytics repo._"
    else
        echo ""
        echo "### Session Analytics"
        echo ""

        # Get status for date range
        status_json=$("$SESSION_CLI" --json status 2>/dev/null)
        earliest=$(echo "$status_json" | jq -r '.earliest_event // "unknown"' | cut -d'T' -f1)
        latest=$(echo "$status_json" | jq -r '.latest_event // "unknown"' | cut -d'T' -f1)

        echo "**Data range:** $earliest to $latest"
        echo ""

        # Get token usage
        tokens_json=$("$SESSION_CLI" --json tokens --days "$DAYS" 2>/dev/null)
        sessions=$("$SESSION_CLI" --json sessions --days "$DAYS" 2>/dev/null | jq 'if type == "array" then length else .session_count // 0 end')
        input_tokens=$(echo "$tokens_json" | jq -r '.total_input_tokens // 0')
        output_tokens=$(echo "$tokens_json" | jq -r '.total_output_tokens // 0')
        cache_read=$(echo "$tokens_json" | jq -r '.total_cache_read_tokens // 0')
        cache_create=$(echo "$tokens_json" | jq -r '.total_cache_creation_tokens // 0')

        # Get tool frequency
        freq_json=$("$SESSION_CLI" --json frequency --days "$DAYS" 2>/dev/null)
        tool_calls=$(echo "$freq_json" | jq -r '.total_tool_calls // 0')

        # Get top sequences
        seq_json=$("$SESSION_CLI" --json sequences --days "$DAYS" 2>/dev/null)
        top_seq=$(echo "$seq_json" | jq -r '.sequences[0] | "\(.pattern): \(.count)"' 2>/dev/null || echo "N/A")

        # Format large numbers
        format_num() {
            local n=$1
            if [[ $n -ge 1000000000 ]]; then
                printf "%.1fB" "$(echo "scale=1; $n / 1000000000" | bc)"
            elif [[ $n -ge 1000000 ]]; then
                printf "%.1fM" "$(echo "scale=1; $n / 1000000" | bc)"
            elif [[ $n -ge 1000 ]]; then
                printf "%.1fK" "$(echo "scale=1; $n / 1000" | bc)"
            else
                echo "$n"
            fi
        }

        # Calculate cache ratio
        if [[ "$cache_create" -gt 0 ]]; then
            cache_ratio=$(echo "scale=0; $cache_read / $cache_create" | bc)
        else
            cache_ratio="N/A"
        fi

        # Column widths for session stats
        sw1=20  # Metric
        sw2=25  # Value (wider to accommodate long sequences)

        printf "┌%s┬%s┐\n" \
            "$(printf '─%.0s' $(seq 1 $((sw1 + 2))))" \
            "$(printf '─%.0s' $(seq 1 $((sw2 + 2))))"
        print_row $sw1 $sw2 "Metric" "Value"
        printf "├%s┼%s┤\n" \
            "$(printf '─%.0s' $(seq 1 $((sw1 + 2))))" \
            "$(printf '─%.0s' $(seq 1 $((sw2 + 2))))"
        print_row $sw1 $sw2 "Sessions" "$sessions"
        print_row $sw1 $sw2 "Tool invocations" "$tool_calls"
        print_row $sw1 $sw2 "Input tokens" "$(format_num "$input_tokens")"
        print_row $sw1 $sw2 "Output tokens" "$(format_num "$output_tokens")"
        print_row $sw1 $sw2 "Cache read" "$(format_num "$cache_read")"
        print_row $sw1 $sw2 "Cache creation" "$(format_num "$cache_create")"
        print_row $sw1 $sw2 "Cache ratio" "${cache_ratio}:1"
        print_row $sw1 $sw2 "Top sequence" "$top_seq"
        printf "└%s┴%s┘\n" \
            "$(printf '─%.0s' $(seq 1 $((sw1 + 2))))" \
            "$(printf '─%.0s' $(seq 1 $((sw2 + 2))))"

        echo ""
        echo "_Source: agent-session-analytics-cli (last ${DAYS}d)_"
    fi
fi
