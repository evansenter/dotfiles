#!/bin/bash
# Agent Teams hook: Publishes teammate_idle event when a teammate has no work
#
# Input (via stdin): JSON with session_id, teammate_name, team_name, cwd, etc.
# Output: None (side-effect only — publishes to event bus)
#
# CRITICAL: Must exit 0. Exit code 2 would keep the teammate working instead of going idle.

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
TEAMMATE_NAME=$(echo "$INPUT" | jq -r '.teammate_name // ""')
TEAM_NAME=$(echo "$INPUT" | jq -r '.team_name // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

[[ -z "$SESSION_ID" ]] && exit 0
[[ -z "$CWD" ]] && CWD="$PWD"

# Derive repo name (--show-toplevel always returns absolute path, works in worktrees too)
if command -v git &>/dev/null && git -C "$CWD" rev-parse --git-dir &>/dev/null; then
    REPO_NAME=$(basename "$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)")
else
    REPO_NAME=$(basename "$CWD")
fi

# Build payload
PAYLOAD="Teammate idle"
[[ -n "$TEAMMATE_NAME" ]] && PAYLOAD="Teammate '${TEAMMATE_NAME}' is idle"
[[ -n "$TEAM_NAME" ]] && PAYLOAD="${PAYLOAD} (team: ${TEAM_NAME})"

# Publish to event bus (|| true ensures exit 0)
agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} publish \
    --type "teammate_idle" \
    --payload "$PAYLOAD" \
    --session-id "$SESSION_ID" \
    --channel "repo:${REPO_NAME}" \
    2>/dev/null || true
