#!/bin/bash
# Session end hook: Prompts Claude to unregister from the event bus
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, reason
# Output: Text context that Claude reads before session ends

set -euo pipefail

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    # Graceful degradation: output minimal instruction
    cat <<EOF
<event-bus-cleanup>
Unregister from event bus: mcp__event-bus__unregister_session(session_id: "<your-session-id>")
</event-bus-cleanup>
EOF
    exit 0
fi

# Read and parse session info
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Concise output for Claude
cat <<EOF
<event-bus-cleanup>
Unregister from event bus: mcp__event-bus__unregister_session(session_id: "$SESSION_ID")
</event-bus-cleanup>
EOF
