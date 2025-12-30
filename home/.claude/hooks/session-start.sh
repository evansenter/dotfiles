#!/bin/bash
# Session start hook: Prompts Claude to register with the event bus
#
# When a Claude Code session starts, this outputs instructions that Claude
# will read and act upon - registering the session with the event bus MCP server.
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, source
# Output: Text context that Claude reads on session start

set -euo pipefail

# Read session info from stdin
INPUT=$(cat)

# Extract fields we need for registration context
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"')

# Derive session name from directory
if [[ -n "$CWD" ]]; then
    REPO_NAME=$(basename "$CWD")
    # Check if in a git repo with a branch
    if [[ -d "$CWD/.git" ]] || git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
        BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "")
        if [[ -n "$BRANCH" ]]; then
            SESSION_NAME="${REPO_NAME}/${BRANCH}"
        else
            SESSION_NAME="$REPO_NAME"
        fi
    else
        SESSION_NAME="$REPO_NAME"
    fi
else
    SESSION_NAME="claude-session"
fi

# Output instructions for Claude to act on
# This becomes part of the session context
cat <<EOF
<event-bus-registration>
Register this session with the event bus for cross-session coordination.

Call: mcp__event-bus__register_session
  name: "$SESSION_NAME"
  cwd: "$CWD"

After registering, store the session_id for later use with publish_event and get_events.
</event-bus-registration>
EOF
