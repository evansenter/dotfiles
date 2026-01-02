#!/usr/bin/env bash
# repo-stats.sh - Show code stats across repositories
#
# Usage: repo-stats.sh [--days N] [repo1 repo2 ...]
#
# Examples:
#   repo-stats.sh                    # Default repos, last 14 days
#   repo-stats.sh --days 7           # Last 7 days
#   repo-stats.sh myrepo otherrepo   # Custom repos

set -euo pipefail

# Defaults
DAYS=14
OWNER="evansenter"
LOCAL_DIR="$HOME/Documents/projects"
DEFAULT_REPOS="dotfiles gemicro claude-event-bus claude-session-analytics rust-genai"
REPOS=""

# Check for scc
HAS_SCC=$(command -v scc >/dev/null 2>&1 && echo "1" || echo "0")

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
        --help|-h)
            echo "Usage: repo-stats.sh [--days N] [--owner OWNER] [--local-dir DIR] [repo1 repo2 ...]"
            echo ""
            echo "Options:"
            echo "  --days N        Look back N days (default: 14)"
            echo "  --owner NAME    GitHub owner (default: evansenter)"
            echo "  --local-dir DIR Local repos directory (default: ~/Documents/projects)"
            echo ""
            echo "If repos are specified, uses those instead of defaults."
            echo "Uses 'scc' for accurate LoC if installed and repos exist locally."
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

# Helper function to print a table row
# Args: column widths..., then "---" for separator or values
print_row() {
    local widths=("$@")
    local values_start=0
    local is_separator=false

    # Find where values start (after all numeric widths)
    for i in "${!widths[@]}"; do
        if [[ ! "${widths[$i]}" =~ ^[0-9]+$ ]]; then
            values_start=$i
            break
        fi
    done

    local col_widths=("${widths[@]:0:$values_start}")
    local values=("${widths[@]:$values_start}")

    if [[ "${values[0]}" == "---" ]]; then
        is_separator=true
    fi

    printf "│"
    for i in "${!col_widths[@]}"; do
        local w="${col_widths[$i]}"
        if $is_separator; then
            printf "%s" "$(printf '─%.0s' $(seq 1 $((w + 2))))"
            if [[ $i -lt $((${#col_widths[@]} - 1)) ]]; then
                printf "┼"
            fi
        else
            printf " %-${w}s │" "${values[$i]}"
        fi
    done
    if $is_separator; then
        printf "│"
    fi
    printf "\n"
}

# Print project stats table
echo "### Project Stats"
echo ""

# Column widths for project stats
pw1=26  # Repo
pw2=6   # Issues
pw3=4   # PRs

printf "┌%s┬%s┬%s┐\n" \
    "$(printf '─%.0s' $(seq 1 $((pw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw3 + 2))))"
print_row $pw1 $pw2 $pw3 "Repository" "Issues" "PRs"
printf "├%s┼%s┼%s┤\n" \
    "$(printf '─%.0s' $(seq 1 $((pw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw3 + 2))))"

for repo in $REPOS; do
    # Get open issues and PRs from GitHub
    open_issues=$(gh api "repos/$OWNER/$repo" --jq '.open_issues_count // 0' 2>/dev/null) || open_issues="0"
    open_prs=$(gh api "repos/$OWNER/$repo/pulls?state=open" --jq 'length' 2>/dev/null) || open_prs="0"
    # open_issues includes PRs, so subtract
    open_issues=$((open_issues - open_prs))

    print_row $pw1 $pw2 $pw3 "$repo" "$open_issues" "$open_prs"
done

printf "└%s┴%s┴%s┘\n" \
    "$(printf '─%.0s' $(seq 1 $((pw1 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw2 + 2))))" \
    "$(printf '─%.0s' $(seq 1 $((pw3 + 2))))"

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
    commits=$(gh api "repos/$OWNER/$repo/commits?since=$SINCE&per_page=100" --jq 'length' 2>/dev/null || echo "0")

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
