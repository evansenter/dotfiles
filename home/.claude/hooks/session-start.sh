#!/bin/bash
# Session start hook: Prompts Claude to register with the event bus
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, source
# Output: Text context that Claude reads on session start

set -euo pipefail

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    # Consume stdin to avoid broken pipe
    cat >/dev/null
    # Graceful degradation: output minimal instruction without parsed fields
    cat <<EOF
<event-bus-registration>
Register with event bus: mcp__event-bus__register_session(name: "<repo>/<branch>", cwd: "$PWD")
</event-bus-registration>
EOF
    exit 0
fi

# Read and parse session info
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[[ -z "$CWD" ]] && CWD="$PWD"
CLIENT_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

# Compute session-specific key from transcript_path for multi-session support
# Use simple hash that works on both macOS (md5) and Linux (md5sum)
if [[ -n "$TRANSCRIPT_PATH" ]]; then
    if command -v md5 &>/dev/null; then
        SESSION_KEY=$(echo -n "$TRANSCRIPT_PATH" | md5 | cut -c1-12)
    elif command -v md5sum &>/dev/null; then
        SESSION_KEY=$(echo -n "$TRANSCRIPT_PATH" | md5sum | cut -c1-12)
    else
        # Fallback: use basename of transcript file
        SESSION_KEY=$(basename "$TRANSCRIPT_PATH" .jsonl)
    fi
else
    SESSION_KEY="default"
fi

# Derive session name (graceful fallback if git unavailable)
REPO_NAME=$(basename "$CWD")
if command -v git &>/dev/null && git -C "$CWD" rev-parse --git-dir &>/dev/null; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "")
    [[ -n "$BRANCH" ]] && SESSION_NAME="${REPO_NAME}/${BRANCH}" || SESSION_NAME="$REPO_NAME"
else
    SESSION_NAME="$REPO_NAME"
fi

# Concise output for Claude
# Include client_id if available (enables session resumption across context reloads)
if [[ -n "$CLIENT_ID" ]]; then
    CLIENT_ID_ARG=", client_id: \"$CLIENT_ID\""
else
    CLIENT_ID_ARG=""
fi

cat <<EOF
<event-bus-registration>
Register with event bus: mcp__event-bus__register_session(name: "$SESSION_NAME", cwd: "$CWD"$CLIENT_ID_ARG)
After registration, persist the session_id for statusline display:
  mkdir -p ~/.claude/.event-bus-sessions && echo "SESSION_ID_HERE" > ~/.claude/.event-bus-sessions/$SESSION_KEY
</event-bus-registration>
EOF

# Fetch recent events to catch up on what happened since last session
# Uses event-bus-cli if available, shows up to 10 non-registration events
if command -v event-bus-cli &>/dev/null; then
    STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude"
    STATE_FILE="$STATE_DIR/last_event_id"
    mkdir -p "$STATE_DIR"

    # Get recent events (initializes state file if needed)
    EVENTS=$(event-bus-cli events \
        --track-state "$STATE_FILE" \
        --exclude-types session_registered,session_unregistered \
        --timeout 200 \
        --limit 10 \
        2>/dev/null) || true

    if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
        cat <<EVENTS_EOF
<recent-events>
$EVENTS
</recent-events>
EVENTS_EOF
    fi
fi
