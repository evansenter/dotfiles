#!/bin/bash
# Session start hook: Registers with the event bus and fetches recent events
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, source
# Output: Text context that Claude reads on session start

set -euo pipefail

# Read and parse session info
INPUT=$(cat)

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    # Graceful degradation: can't parse input without jq
    echo "Event bus registration skipped (jq not installed)"
    exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[[ -z "$CWD" ]] && CWD="$PWD"
CLIENT_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"')

# Derive session name (graceful fallback if git unavailable)
REPO_NAME=$(basename "$CWD")
if command -v git &>/dev/null && git -C "$CWD" rev-parse --git-dir &>/dev/null; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "")
    [[ -n "$BRANCH" ]] && SESSION_NAME="${REPO_NAME}/${BRANCH}" || SESSION_NAME="$REPO_NAME"
else
    SESSION_NAME="$REPO_NAME"
fi

# Check for event-bus-cli
if ! command -v event-bus-cli &>/dev/null; then
    echo "Event bus registration skipped (event-bus-cli not installed)"
    exit 0
fi

# Register with event bus using CLI
REGISTER_ARGS=(--name "$SESSION_NAME")
[[ -n "$CLIENT_ID" ]] && REGISTER_ARGS+=(--client-id "$CLIENT_ID")

OUTPUT=$(event-bus-cli register "${REGISTER_ARGS[@]}" 2>/dev/null) || true
SESSION_ID=$(echo "$OUTPUT" | jq -r '.session_id // ""')

if [[ -n "$SESSION_ID" ]]; then
    echo "Registered on event bus as: $SESSION_ID ($SESSION_NAME)"
else
    echo "Event bus registration failed"
    exit 0
fi

# Fetch recent events (newest-first for natural reading order - most relevant at top)
# Session is auto-subscribed to 4 channels:
# - "all" - broadcasts to everyone
# - "repo:<name>" - repo-specific coordination
# - "machine:<hostname>" - local machine coordination
# - "session:<id>" - direct messages (if resumed with same session_id)
EVENTS=$(event-bus-cli events \
    --session-id "$SESSION_ID" \
    --order desc \
    --exclude-types session_registered,session_unregistered \
    --timeout 200 \
    --limit 20 \
    2>/dev/null) || true

# Output events in XML tags (interpretation guidance is in CLAUDE.md)
if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
    echo "<recent-events>"
    echo "$EVENTS"
    echo "</recent-events>"
fi

# If resuming after compaction, fetch and display WIP checkpoint
if [[ "$SOURCE" == "compact" ]]; then
    # Fetch the most recent wip_checkpoint event for this session
    # Note: CLI only has --exclude-types, so we filter with grep post-fetch
    WIP_EVENT=$(event-bus-cli events \
        --session-id "$SESSION_ID" \
        --channel "session:${SESSION_ID}" \
        --limit 1 \
        --order desc \
        2>/dev/null | grep -E "wip_checkpoint" | head -1) || true

    if [[ -n "$WIP_EVENT" ]]; then
        echo ""
        echo "<wip-checkpoint-restored>"
        echo "Session resumed after compaction. Previous WIP state:"
        echo "$WIP_EVENT"
        echo "</wip-checkpoint-restored>"
    fi
fi
