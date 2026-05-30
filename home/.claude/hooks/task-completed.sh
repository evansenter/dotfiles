#!/bin/bash
# Agent Teams hook: Publishes task_completed event for coordination
#
# Input (via stdin): JSON with session_id, task_id, task_subject, task_description,
#                    teammate_name, team_name, cwd, etc.
# Output: None (side-effect only — publishes to event bus)
#
# CRITICAL: Must exit 0. Exit code 2 would prevent the task from being marked complete.

set -euo pipefail

# Source user's environment for AGENT_EVENT_BUS_URL
if [[ -f ~/.extra ]]; then
    # ~/.extra is user-edited and untracked; a stray unset var or non-zero
    # line must not abort the hook under set -euo pipefail.
    set +eu
    # shellcheck source=/dev/null
    source ~/.extra
    set -eu
fi

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

# Derive repo name (git-common-dir returns absolute path in worktrees, relative in regular repos)
if command -v git &>/dev/null && git -C "$CWD" rev-parse --git-dir &>/dev/null; then
    COMMON_DIR=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null)
    if [[ "$COMMON_DIR" == /* ]]; then
        REPO_NAME=$(basename "$(dirname "$COMMON_DIR")")
    else
        REPO_NAME=$(basename "$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)")
    fi
else
    REPO_NAME=$(basename "$CWD")
fi

# Build payload
PAYLOAD="Task completed: ${TASK_SUBJECT:-<no subject>}"
[[ -n "$TEAMMATE_NAME" ]] && PAYLOAD="${PAYLOAD} (by: ${TEAMMATE_NAME})"

# Publish to event bus (|| true ensures exit 0)
agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} publish \
    --type "task_completed" \
    --payload "$PAYLOAD" \
    --session-id "$SESSION_ID" \
    --channel "repo:${REPO_NAME}" \
    2>/dev/null || true
