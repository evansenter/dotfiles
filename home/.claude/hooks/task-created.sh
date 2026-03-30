#!/bin/bash
# Agent Teams hook: Publishes task_created event for cross-agent visibility
#
# Input (via stdin): JSON with session_id, task_id, task_subject, task_description,
#                    teammate_name, team_name, cwd, etc.
# Output: None (side-effect only — publishes to event bus)
#
# CRITICAL: Must exit 0. Exit code 2 would prevent the task from being created.

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

# Build URL args if AGENT_EVENT_BUS_URL is set
URL_ARGS=()
[[ -n "${AGENT_EVENT_BUS_URL:-}" ]] && URL_ARGS=(--url "$AGENT_EVENT_BUS_URL")

# Parse input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
TASK_SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // ""')
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

[[ -z "$SESSION_ID" ]] && exit 0
[[ -z "$CWD" ]] && CWD="$PWD"

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

# Build payload
PAYLOAD="Task created: ${TASK_SUBJECT:-<no subject>}"
[[ -n "$TEAMMATE_NAME" ]] && PAYLOAD="${PAYLOAD} (by: ${TEAMMATE_NAME})"

# Publish to event bus (|| true ensures exit 0)
agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} publish \
    --type "task_created" \
    --payload "$PAYLOAD" \
    --session-id "$SESSION_ID" \
    --channel "repo:${REPO_NAME}" \
    2>/dev/null || true
