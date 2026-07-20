#!/bin/bash
# Prompt events hook: Fetches new events from the event bus on every prompt
#
# Input (via stdin): JSON with session_id, transcript_path, cwd
# Output: Event updates for Claude to see (if any new events)
#
# Uses --resume for incremental polling: only shows events since last prompt.
# The server tracks cursor position per session, so each prompt only sees NEW events.
#
# Shares its denylist + fetch path with drain-directed-events.sh via the
# eventbus-collect.sh lib so the two hooks cannot diverge. See hooks/README.md
# "Event-drain architecture".

set -euo pipefail

# Source shared collection library (handles ~/.extra, URL args, denylist, fetch).
# shellcheck source=lib/eventbus-collect.sh
source "$(dirname "$0")/lib/eventbus-collect.sh"

# Read session info (always consume stdin to avoid broken pipe)
INPUT=$(cat)

# Graceful degradation: need cli + jq.
eb_have_deps || exit 0

# Parse session-id - required for cursor tracking
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

# Without session_id, we can't do incremental polling
if [[ -z "$SESSION_ID" ]]; then
    exit 0
fi

# Fetch only NEW events since last prompt (consuming read, ascending, text).
# --order asc: chronological order (oldest first, new events at end)
EVENTS=$(eb_fetch_events "$SESSION_ID" consume text asc)

# Output events in XML tags (interpretation guidance is in CLAUDE.md)
if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
    echo "<recent-events>"
    echo "$EVENTS"
    echo "</recent-events>"
fi
