#!/bin/bash
# Prompt events hook: Fetches new events from the event bus on every prompt
#
# Input (via stdin): JSON with session_id, transcript_path, cwd
# Output: Event updates for Claude to see (if any new events)
#
# Uses event-bus-cli with --track-state for automatic incremental polling.
# The state file tracks the last event ID to only show new events.

set -euo pipefail

# Read session info (always consume stdin to avoid broken pipe)
INPUT=$(cat)

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude"
STATE_FILE="$STATE_DIR/last_event_id"

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Check for event-bus-cli
if ! command -v event-bus-cli &>/dev/null; then
    # Graceful degradation: skip if CLI not installed
    exit 0
fi

# Parse session-id if jq available (enables heartbeat refresh)
SESSION_ID=""
if command -v jq &>/dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
fi

# Build the command with optional session-id
# Higher limit (20) than session-start (10) since active sessions benefit from more context
CMD=(event-bus-cli events
    --track-state "$STATE_FILE"
    --exclude-types session_registered,session_unregistered
    --timeout 200
    --limit 20
)

# Add session-id if available (refreshes heartbeat)
[[ -n "$SESSION_ID" ]] && CMD+=(--session-id "$SESSION_ID")

# Fetch events - capture output and exit code separately
EVENTS=$("${CMD[@]}" 2>/dev/null) || true

# Only output if there are actual events (not empty or "No events" / "No new events")
if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
    cat <<EOF
<event-bus-updates>
$EVENTS
</event-bus-updates>
EOF
fi

exit 0
