#!/bin/bash
# Session end hook: Prompts Claude to unregister from the event bus
#
# When a Claude Code session ends, this outputs instructions that Claude
# will read and act upon - unregistering the session from the event bus.
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, reason
# Output: Text context that Claude reads before session ends

set -euo pipefail

# Read session info from stdin
INPUT=$(cat)

# Extract the session_id and reason from input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
REASON=$(echo "$INPUT" | jq -r '.reason // "other"')

# Output instructions for Claude to act on
cat <<EOF
<event-bus-cleanup>
Unregister this session from the event bus before exiting.

Call: mcp__event-bus__unregister_session
  session_id: "$SESSION_ID"

Reason for session end: $REASON
</event-bus-cleanup>
EOF
