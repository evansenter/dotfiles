#!/bin/bash
# Event Bus Background Watcher
#
# Launched by session-start.sh as a background process.
# Polls the event bus every few seconds and writes new events to an inbox file.
# The prompt hook reads this file to inject events into CC's context.
#
# This bridges the gap between "fire-and-forget" polling on user prompt
# and true real-time notification support (blocked on CC #3174).
#
# Usage: event-bus-watcher.sh <session_id> <inbox_path> [poll_interval_seconds]

set -euo pipefail

SESSION_ID="${1:?session_id required}"
INBOX_PATH="${2:?inbox_path required}"
POLL_INTERVAL="${3:-5}"

# Source environment for AGENT_EVENT_BUS_URL
[[ -f ~/.extra ]] && source ~/.extra

# Ensure CLI is available
if ! command -v agent-event-bus-cli &>/dev/null; then
    exit 1
fi

# Create inbox directory
mkdir -p "$(dirname "$INBOX_PATH")"

# PID file for cleanup
PID_FILE="${INBOX_PATH}.pid"
echo $$ > "$PID_FILE"

# Cleanup on exit
cleanup() {
    rm -f "$PID_FILE"
}
trap cleanup EXIT INT TERM

# Main poll loop
while true; do
    # Fetch new events (incremental via --resume)
    EVENTS=$(agent-event-bus-cli events \
        --resume \
        --session-id "$SESSION_ID" \
        --order asc \
        --exclude session_registered,session_unregistered,ci_watching,task_started,ci_rerun,parallel_work_started \
        --timeout 200 \
        --limit 20 \
        2>/dev/null) || true

    # Append new events to inbox (if any)
    if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
        {
            echo "--- $(date -u +%Y-%m-%dT%H:%M:%SZ) ---"
            echo "$EVENTS"
            echo ""
        } >> "$INBOX_PATH"
    fi

    sleep "$POLL_INTERVAL"
done
