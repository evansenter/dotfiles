#!/bin/bash
# Notification hook: Display system notification for Claude Code events
#
# Cross-platform: uses osascript on macOS, notify-send on Linux
# Expects JSON input with 'title' and 'message' fields from Claude Code

# Read input (Claude Code passes notification data)
INPUT=$(cat)

# Extract title and message (default values if not provided)
TITLE=$(echo "$INPUT" | jq -r '.title // "Claude Code"' 2>/dev/null || echo "Claude Code")
MESSAGE=$(echo "$INPUT" | jq -r '.message // "Task completed"' 2>/dev/null || echo "Task completed")

# Send notification based on platform
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
elif command -v notify-send >/dev/null 2>&1; then
    # Linux with notify-send
    notify-send "$TITLE" "$MESSAGE"
fi

# Return success
echo '{"ok": true}'
