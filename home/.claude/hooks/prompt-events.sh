#!/bin/bash
# Prompt events hook: Reads pre-staged events from the background watcher's inbox
#
# Input (via stdin): JSON with session_id, transcript_path, cwd
# Output: Event updates for Claude to see (if any new events)
#
# The background watcher (event-bus-watcher.sh) polls the bus every 5s and
# appends events to an inbox file. This hook reads and drains that file on
# each prompt, so CC always sees the latest events without blocking on a
# network call.
#
# Falls back to direct polling if the watcher isn't running.

set -euo pipefail

# Source user's environment for AGENT_EVENT_BUS_URL
[[ -f ~/.extra ]] && source ~/.extra

# Read session info (always consume stdin to avoid broken pipe)
INPUT=$(cat)

# Parse session-id
SESSION_ID=""
if command -v jq &>/dev/null; then
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
fi

if [[ -z "$SESSION_ID" ]]; then
    exit 0
fi

# Check for inbox file from background watcher
INBOX_DIR="${TMPDIR:-/tmp}/claude-event-inbox"
INBOX_PATH="$INBOX_DIR/$SESSION_ID.inbox"

if [[ -s "$INBOX_PATH" ]]; then
    # Read and drain the inbox atomically
    EVENTS=$(cat "$INBOX_PATH")
    : > "$INBOX_PATH"  # truncate

    echo "<recent-events source=\"watcher\">"
    echo "$EVENTS"
    echo "</recent-events>"
    exit 0
fi

# Fallback: direct poll if watcher isn't running or inbox is empty
if ! command -v agent-event-bus-cli &>/dev/null; then
    exit 0
fi

EVENTS=$(agent-event-bus-cli events \
    --resume \
    --session-id "$SESSION_ID" \
    --order asc \
    --exclude session_registered,session_unregistered,ci_watching,task_started,ci_rerun,parallel_work_started \
    --timeout 200 \
    --limit 20 \
    2>/dev/null) || true

if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
    echo "<recent-events source=\"poll\">"
    echo "$EVENTS"
    echo "</recent-events>"
fi
