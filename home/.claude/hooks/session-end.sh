#!/bin/bash
# Session end hook: Unregisters from the event bus
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, reason
# Output: Text context that Claude reads before session ends

set -euo pipefail

# Read and parse session info
INPUT=$(cat)

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    echo "Event bus unregistration skipped (jq not installed)"
    exit 0
fi

if ! command -v event-bus-cli &>/dev/null; then
    echo "Event bus unregistration skipped (event-bus-cli not installed)"
    exit 0
fi

# Get client_id from the session info (same as what was passed to register)
CLIENT_ID=$(echo "$INPUT" | jq -r '.session_id // ""')

if [[ -z "$CLIENT_ID" ]]; then
    echo "Event bus unregistration skipped (no session_id in input)"
    exit 0
fi

# Unregister by client_id - server looks up session by (machine, client_id)
OUTPUT=$(event-bus-cli unregister --client-id "$CLIENT_ID" 2>/dev/null) || true

if echo "$OUTPUT" | grep -q '"success": true'; then
    SESSION_ID=$(echo "$OUTPUT" | jq -r '.session_id // "unknown"')
    echo "Unregistered from event bus: $SESSION_ID"
else
    echo "Event bus unregistration failed or session not found"
fi
