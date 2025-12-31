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

# Print codebase sizes table
echo "### Codebase Size"
echo ""

if [[ "$HAS_SCC" == "1" ]]; then
    echo "| Repo | Language | Code | Comments | Blanks | Total |"
    echo "|------|----------|------|----------|--------|-------|"
else
    echo "| Repo | Language | LoC (est.) |"
    echo "|------|----------|------------|"
fi

total_code=0
total_comments=0
total_blanks=0
total_lines=0

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

        # Format numbers
        code_fmt=$(printf "%'d" "$code")
        comments_fmt=$(printf "%'d" "$comments")
        blanks_fmt=$(printf "%'d" "$blanks")
        lines_fmt=$(printf "%'d" "$lines")

        echo "| **$repo** | $lang | $code_fmt | $comments_fmt | $blanks_fmt | $lines_fmt |"
    else
        # Fall back to API estimate
        total_bytes=$(gh api "repos/$OWNER/$repo/languages" --jq 'to_entries | map(.value) | add // 0' 2>/dev/null || echo "0")
        loc=$((total_bytes / 35))
        total_code=$((total_code + loc))

        if [[ $loc -ge 1000 ]]; then
            loc_fmt="$(echo "scale=1; $loc / 1000" | bc)K"
        else
            loc_fmt="$loc"
        fi

        echo "| **$repo** | $lang | ~$loc_fmt |"
    fi
done

if [[ "$HAS_SCC" == "1" ]]; then
    code_fmt=$(printf "%'d" "$total_code")
    comments_fmt=$(printf "%'d" "$total_comments")
    blanks_fmt=$(printf "%'d" "$total_blanks")
    lines_fmt=$(printf "%'d" "$total_lines")
    echo "| **Total** | | **$code_fmt** | **$comments_fmt** | **$blanks_fmt** | **$lines_fmt** |"
else
    if [[ $total_code -ge 1000 ]]; then
        total_fmt="$(echo "scale=1; $total_code / 1000" | bc)K"
    else
        total_fmt="$total_code"
    fi
    echo "| **Total** | | **~$total_fmt** |"
fi
echo ""

# Print activity table
echo "### Recent Activity"
echo ""
echo "| Repo | Commits | Additions | Deletions | Net |"
echo "|------|---------|-----------|-----------|-----|"

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

    printf "| **%s** | %d | +%d | -%d | %+d |\n" "$repo" "$commits" "$add" "$del" "$net"
done

total_net=$((total_add - total_del))
printf "| **Total** | **%d** | **+%d** | **-%d** | **%+d** |\n" \
    "$total_commits" "$total_add" "$total_del" "$total_net"

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
