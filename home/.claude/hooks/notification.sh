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
# strictly more urgent. A mid-turn notification stays visible until the
# turn ends (Stop clears the slot; UserPromptSubmit rewrites it).

set -euo pipefail

# Read input (must consume stdin before any exit)
INPUT=$(cat)

# Skip if not in zellij
[[ -z "${ZELLIJ:-}" ]] && exit 0

# Graceful degradation if jq is missing
command -v jq &>/dev/null || exit 0

# Truncate inside jq: bash ${MESSAGE:0:57} slices bytes under a C locale
# (GUI-launched sessions), splitting multibyte chars; jq slices codepoints.
# The `|| exit 0` guards keep the always-exit-0 contract on malformed stdin.
MESSAGE=$(echo "$INPUT" | jq -r '.message // "" | if length > 60 then .[0:57] + "..." else . end' 2>/dev/null) || exit 0
NTYPE=$(echo "$INPUT" | jq -r '.notification_type // ""' 2>/dev/null) || exit 0

# Nothing to show
[[ -z "$MESSAGE" ]] && exit 0

# Permission prompts arrive untyped (notification_type is set only for
# background-agent events), so also key the padlock off the message text —
# matched against the raw input, not $MESSAGE, which is already truncated.
if [[ "$NTYPE" == "agent_completed" ]]; then
    ICON="✅"
elif [[ "$NTYPE" == permission* || "$INPUT" == *[Pp]ermission* ]]; then
    ICON="🔐"
else
    # Includes agent_needs_input and other untyped notifications
    ICON="🔔"
fi

zellij pipe "zjstatus::notify::${ICON} ${MESSAGE}" 2>/dev/null || true
