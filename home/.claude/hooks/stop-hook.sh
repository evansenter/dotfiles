#!/bin/bash
# Stop hook: Provides context for Claude to decide whether to auto-continue
#
# Outputs JSON with current git/PR state. Claude uses this context to determine
# if there's obvious follow-up work (e.g., CI running, pending feedback).
#
# Degrades gracefully if tools are missing or commands fail.
# Requires: git, gh, jq

# Check for required tools
if ! command -v jq >/dev/null 2>&1; then
    echo '{"context": {"error": "jq not installed"}}' >&2
    exit 0
fi

# Gather git context (fallback to empty strings on failure)
RECENT_PUSH=$(git log --oneline -1 --since="5 minutes ago" 2>/dev/null | head -1 || echo "")
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || echo "")

# Function to check if CI is running or just completed
check_ci_status() {
    if [ -z "$PR_NUMBER" ]; then
        echo ""
        return
    fi

    # Get head SHA from PR to avoid race condition with local git
    HEAD_SHA=$(gh pr view --json headRefOid -q .headRefOid 2>/dev/null || echo "")
    if [ -z "$HEAD_SHA" ]; then
        echo ""
        return
    fi

    # Get check run statuses via API and aggregate: failure > pending > success
    STATUSES=$(gh api "repos/{owner}/{repo}/commits/$HEAD_SHA/check-runs" --jq '.check_runs[] | .status + ":" + (.conclusion // "")' 2>/dev/null || echo "")

    if echo "$STATUSES" | grep -q ":failure"; then
        echo "failure"
    elif echo "$STATUSES" | grep -Eq "^(in_progress|queued)"; then
        echo "pending"
    elif [ -n "$STATUSES" ]; then
        echo "success"
    else
        echo ""
    fi
}

# Function to count all PR feedback (line comments, review comments, issue comments, reviews)
check_pr_feedback() {
    if [ -z "$PR_NUMBER" ]; then
        echo "0"
        return
    fi

    # Count different types of feedback
    # Note: {owner}/{repo} placeholders are auto-resolved by gh CLI from git remote
    LINE_COMMENTS=$(gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments" --jq 'length' 2>/dev/null || echo "0")
    ISSUE_COMMENTS=$(gh api "repos/{owner}/{repo}/issues/$PR_NUMBER/comments" --jq 'length' 2>/dev/null || echo "0")
    REVIEWS=$(gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/reviews" --jq '[.[] | select(.state != "COMMENTED")] | length' 2>/dev/null || echo "0")

    # Sum all feedback types
    TOTAL=$((LINE_COMMENTS + ISSUE_COMMENTS + REVIEWS))
    echo "$TOTAL"
}

# Gather context
CI_STATUS=$(check_ci_status)
FEEDBACK_COUNT=$(check_pr_feedback)

# Output context as properly escaped JSON using jq
# This prevents injection issues from special characters in git output
jq -n \
    --arg recent_push "$RECENT_PUSH" \
    --arg current_branch "$CURRENT_BRANCH" \
    --arg pr_number "$PR_NUMBER" \
    --arg ci_status "$CI_STATUS" \
    --arg feedback_count "$FEEDBACK_COUNT" \
    '{
        context: {
            recent_push: $recent_push,
            current_branch: $current_branch,
            pr_number: $pr_number,
            ci_status: $ci_status,
            feedback_count: $feedback_count
        }
    }'
