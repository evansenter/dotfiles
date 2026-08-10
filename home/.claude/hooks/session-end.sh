#!/bin/bash
# Session end hook: Unregisters from the event bus
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, reason
# Output: Text context that Claude reads before session ends

set -euo pipefail

# Source user's environment for AGENT_EVENT_BUS_URL
if [[ -f ~/.extra ]]; then
    # ~/.extra is user-edited and untracked; a stray unset var or non-zero
    # line must not abort the hook under set -euo pipefail.
    set +eu
    # shellcheck source=/dev/null
    source ~/.extra
    set -eu
fi

# Read and parse session info
INPUT=$(cat)

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    echo "Event bus unregistration skipped (jq not installed)"
    exit 0
fi

if ! command -v agent-event-bus-cli &>/dev/null; then
    echo "Event bus unregistration skipped (agent-event-bus-cli not installed)"
    exit 0
fi

# Build URL args if AGENT_EVENT_BUS_URL is set (e.g., remote Tailscale endpoint)
URL_ARGS=()
[[ -n "${AGENT_EVENT_BUS_URL:-}" ]] && URL_ARGS=(--url "$AGENT_EVENT_BUS_URL")

# Get client_id from the session info (same as what was passed to register)
CLIENT_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

if [[ -z "$CLIENT_ID" ]]; then
    echo "Event bus unregistration skipped (no session_id in input)"
    exit 0
fi

# Drop the bridge's pane mapping and any turn-state marker BEFORE unregistering.
#
# Before, because these are local filesystem operations that must happen even
# when the bus is unreachable — and a stale mapping is the one failure with a
# visible blast radius: the bridge would type its wake prompt into whatever
# now owns this pane, usually the shell left behind after the session exits.
#
# CLIENT_ID is the bus session_id (the bus adopts a client_id as its
# session_id verbatim), so no lookup is needed. `panes clear` also drops any
# other entry pointing at this pane, which cleans up after a previous session
# that died without reaching this hook.
agent-event-bus-cli panes clear --session-id "$CLIENT_ID" >/dev/null 2>&1 || true
agent-event-bus-cli wake-state idle --session-id "$CLIENT_ID" >/dev/null 2>&1 || true

# Unregister by client_id - server looks up session by (machine, client_id)
OUTPUT=$(agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} unregister --client-id "$CLIENT_ID" 2>/dev/null) || true

if echo "$OUTPUT" | jq -e '.success == true' >/dev/null 2>&1; then
    SESSION_ID=$(echo "$OUTPUT" | jq -r '.session_id // "unknown"')
    echo "Unregistered from event bus: $SESSION_ID"
else
    echo "Event bus unregistration failed or session not found"
fi
