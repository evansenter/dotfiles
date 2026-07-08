#!/bin/bash
# Surface Claude Code notifications in the zjstatus bar
#
# Trigger: Notification. Fires when Claude Code sends a notification —
# permission requests, idle "waiting for input" prompts, and background
# agent events (notification_type: agent_needs_input / agent_completed,
# added in CC v2.1.198).
#
# Input (via stdin): JSON with session_id, cwd, message, and (for
# background agent events) notification_type.
# Output: None (zellij pipe side effect only)
#
# The zjstatus notify slot is shared with zj-status.sh (working/waiting).
# Overwriting the working indicator is intentional: a notification is
# strictly more urgent, and the next UserPromptSubmit/Stop restores state.

set -euo pipefail

# Read input (must consume stdin before any exit)
INPUT=$(cat)

# Skip if not in zellij
[[ -z "${ZELLIJ:-}" ]] && exit 0

# Graceful degradation if jq is missing
command -v jq &>/dev/null || exit 0

MESSAGE=$(echo "$INPUT" | jq -r '.message // ""')
NTYPE=$(echo "$INPUT" | jq -r '.notification_type // ""')

# Nothing to show
[[ -z "$MESSAGE" ]] && exit 0

case "$NTYPE" in
    agent_completed)
        ICON="✅"
        ;;
    agent_needs_input)
        ICON="🔔"
        ;;
    permission_request | permission*)
        ICON="🔐"
        ;;
    *)
        ICON="🔔"
        ;;
esac

# Truncate so the status bar stays readable
if ((${#MESSAGE} > 60)); then
    MESSAGE="${MESSAGE:0:57}..."
fi

zellij pipe "zjstatus::notify::${ICON} ${MESSAGE}" 2>/dev/null || true
