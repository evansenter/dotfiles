#!/bin/bash
# Prompt events hook: Fetches new events from the event bus on every prompt
#
# Input (via stdin): JSON with session_id, transcript_path, cwd
# Output: Event updates for Claude to see (if any new events)
#
# Uses --resume for incremental polling: only shows events since last prompt.
# The server tracks cursor position per session, so each prompt only sees NEW events.

set -euo pipefail

# Source user's environment for AGENT_EVENT_BUS_URL
[[ -f ~/.extra ]] && source ~/.extra

# Read session info (always consume stdin to avoid broken pipe)
INPUT=$(cat)

# Check for agent-event-bus-cli
if ! command -v agent-event-bus-cli &>/dev/null; then
    # Graceful degradation: skip if CLI not installed
    exit 0
fi

# Build URL args if AGENT_EVENT_BUS_URL is set (e.g., remote Tailscale endpoint)
URL_ARGS=()
[[ -n "${AGENT_EVENT_BUS_URL:-}" ]] && URL_ARGS=(--url "$AGENT_EVENT_BUS_URL")

# Parse session-id - required for cursor tracking
SESSION_ID=""
if command -v jq &>/dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
fi

# Without session_id, we can't do incremental polling
if [[ -z "$SESSION_ID" ]]; then
    exit 0
fi

# Fetch only NEW events since last prompt using --resume
# --resume: incremental polling - server tracks cursor, only returns new events
# --order asc: chronological order (oldest first, new events at end)
EVENTS=$(agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} events \
    --resume \
    --session-id "$SESSION_ID" \
    --order asc \
    --exclude session_registered,session_unregistered,ci_watching,task_started,ci_rerun,parallel_work_started \
    --timeout 200 \
    --limit 20 \
    2>/dev/null) || true

# Output events in XML tags (interpretation guidance is in CLAUDE.md)
if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
    echo "<recent-events>"
    echo "$EVENTS"
    echo "</recent-events>"
fi
