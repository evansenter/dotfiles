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
# --order desc for most recent first (natural reading order)
EVENTS=$(event-bus-cli events \
    --session-id "$SESSION_ID" \
    --order desc \
    --exclude-types session_registered,session_unregistered,ci_watching,task_started,ci_rerun,parallel_work_started \
    --timeout 200 \
    --limit 20 \
    2>/dev/null) || true

# Output events using shared template
if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
    TEMPLATE_FILE="$HOME/.claude/contrib/prompts/recent-events.md"
    if [[ -f "$TEMPLATE_FILE" ]]; then
        # Read template and substitute {{EVENTS}} with actual events
        TEMPLATE=$(<"$TEMPLATE_FILE")
        echo "${TEMPLATE//\{\{EVENTS\}\}/$EVENTS}"
    else
        # Fallback if template missing
        echo "<recent-events>"
        echo "$EVENTS"
        echo "</recent-events>"
    fi
fi

exit 0
