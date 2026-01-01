#!/bin/bash
# Session start hook: Prompts Claude to register with the event bus
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, source
# Output: Text context that Claude reads on session start

set -euo pipefail

# Check for required dependencies
if ! command -v jq &>/dev/null; then
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
</event-bus-registration>
EOF
