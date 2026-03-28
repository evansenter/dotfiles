#!/bin/bash
# Session end hook: Unregisters from the event bus
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, reason
# Output: Text context that Claude reads before session ends

set -euo pipefail

# Source user's environment for AGENT_EVENT_BUS_URL
[[ -f ~/.extra ]] && source ~/.extra

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

# Unregister by client_id - server looks up session by (machine, client_id)
OUTPUT=$(agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} unregister --client-id "$CLIENT_ID" 2>/dev/null) || true

if echo "$OUTPUT" | jq -e '.success == true' >/dev/null 2>&1; then
    SESSION_ID=$(echo "$OUTPUT" | jq -r '.session_id // "unknown"')
    echo "Unregistered from event bus: $SESSION_ID"
else
    echo "Event bus unregistration failed or session not found"
fi
