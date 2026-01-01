#!/bin/bash
# Prompt events hook: Fetches new events from the event bus on every prompt
#
# Input (via stdin): JSON with session_id, transcript_path, cwd
# Output: Event updates for Claude to see (if any new events)
#
# Uses server-side cursor tracking via session_id. The event bus server
# automatically saves cursor position per session, enabling seamless resume.

set -euo pipefail

# Read session info (always consume stdin to avoid broken pipe)
INPUT=$(cat)

# Check for event-bus-cli
if ! command -v event-bus-cli &>/dev/null; then
    # Graceful degradation: skip if CLI not installed
    exit 0
fi

# Parse session-id - required for server-side cursor tracking
SESSION_ID=""
if command -v jq &>/dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
fi

# Without session_id, we can't do incremental polling
if [[ -z "$SESSION_ID" ]]; then
    exit 0
fi

# Fetch events using server-side cursor tracking
# --session-id enables auto-tracking: server saves cursor per session
# --order asc for chronological order when catching up
# Higher limit (20) than session-start (10) since active sessions benefit from more context
EVENTS=$(event-bus-cli events \
    --session-id "$SESSION_ID" \
    --order asc \
    --exclude-types session_registered,session_unregistered \
    --timeout 200 \
    --limit 20 \
    2>/dev/null) || true

# Only output if there are actual events (not empty or "No events" / "No new events")
if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
    cat <<EOF
<event-bus-updates>
$EVENTS
</event-bus-updates>
EOF
fi

exit 0
