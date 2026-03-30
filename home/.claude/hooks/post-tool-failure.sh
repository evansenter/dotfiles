#!/bin/bash
# PostToolUseFailure hook: Detects recurring error patterns via event bus
#
# Input (via stdin): JSON with session_id, cwd, tool_name, tool_input, error, is_interrupt
# Output: JSON with additionalContext when recurring pattern detected (≥3 in 24h)
#
# Uses event bus as a cross-session error tally. Publishes error_pattern events,
# then queries for matches. If threshold met, injects context back to Claude.

set -euo pipefail

# Source user's environment for AGENT_EVENT_BUS_URL
[[ -f ~/.extra ]] && source ~/.extra

# Read input (must consume stdin before any exit)
INPUT=$(cat)

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    exit 0
fi

if ! command -v agent-event-bus-cli &>/dev/null; then
    exit 0
fi

# Parse input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
ERROR=$(echo "$INPUT" | jq -r '.error // ""')
IS_INTERRUPT=$(echo "$INPUT" | jq -r '.is_interrupt // false')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

[[ -z "$SESSION_ID" ]] && exit 0
[[ -z "$TOOL_NAME" ]] && exit 0
[[ -z "$ERROR" ]] && exit 0
[[ -z "$CWD" ]] && CWD="$PWD"

# Skip benign errors
[[ "$IS_INTERRUPT" == "true" ]] && exit 0

# Skip expected exploration errors
case "$TOOL_NAME:$ERROR" in
    Grep:*"No files found"*|Grep:*"No matches"*) exit 0 ;;
    Glob:*"No files found"*|Glob:*"No matches"*) exit 0 ;;
    Read:*"does not exist"*|Read:*"No such file"*) exit 0 ;;
esac

# Build URL args if AGENT_EVENT_BUS_URL is set
URL_ARGS=()
[[ -n "${AGENT_EVENT_BUS_URL:-}" ]] && URL_ARGS=(--url "$AGENT_EVENT_BUS_URL")

# Derive repo name
REPO_NAME=""
if command -v git &>/dev/null && git -C "$CWD" rev-parse --git-dir &>/dev/null; then
    GIT_COMMON=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null || echo "")
    if [[ -n "$GIT_COMMON" ]]; then
        REPO_NAME=$(basename "$(dirname "$GIT_COMMON")")
    else
        REPO_NAME=$(basename "$CWD")
    fi
else
    REPO_NAME=$(basename "$CWD")
fi

# Build pattern signature: tool_name + first 80 chars of error
ERROR_PREFIX="${ERROR:0:80}"
SIGNATURE="${TOOL_NAME}:${ERROR_PREFIX}"

# Publish error_pattern event to event bus
agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} publish \
    --type "error_pattern" \
    --payload "$SIGNATURE" \
    --session-id "$SESSION_ID" \
    --channel "repo:${REPO_NAME}" \
    2>/dev/null || true

# Query event bus for matching error_pattern events in last 24h
EVENTS=$(agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} events \
    --session-id "$SESSION_ID" \
    --include "error_pattern" \
    --limit 50 \
    --timeout 200 \
    2>/dev/null) || true

# Count matches for this signature
MATCH_COUNT=0
if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
    MATCH_COUNT=$(echo "$EVENTS" | grep -cF "$SIGNATURE" || true)
fi

# If threshold met, inject additionalContext
THRESHOLD=3
if [[ "$MATCH_COUNT" -ge "$THRESHOLD" ]]; then
    # Output JSON that Claude Code reads as additionalContext
    cat <<CONTEXT_JSON
{
  "hookSpecificOutput": {
    "additionalContext": "⚠️ Recurring error (${MATCH_COUNT} occurrences in recent sessions): ${TOOL_NAME} — ${ERROR_PREFIX}. This pattern keeps happening. Consider investigating the root cause or creating a memory entry to prevent it."
  }
}
CONTEXT_JSON
fi
