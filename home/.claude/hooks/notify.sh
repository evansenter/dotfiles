#!/bin/bash
# Notification hook: Display system notification for Claude Code events
#
# Cross-platform: uses osascript on macOS, notify-send on Linux
#
# Usage:
#   1. CLI args:  ~/.claude/hooks/notify.sh "Title" "Message"  (preferred for background tasks)
#   2. Pipe JSON: echo '{"title":"X","message":"Y"}' | ~/.claude/hooks/notify.sh
#   3. Default:   ~/.claude/hooks/notify.sh (uses default title/message)

# Handle command-line arguments (preferred for background tasks - avoids pipe issues)
if [[ $# -ge 2 ]]; then
    TITLE="${1:-Claude Code}"
    MESSAGE="${2:-Task completed}"
elif [[ $# -eq 1 ]]; then
    TITLE="Claude Code"
    MESSAGE="${1:-Task completed}"
else
    # Read from stdin (backward compatible with pipe usage)
    INPUT=$(cat)
    TITLE=$(echo "$INPUT" | jq -r '.title // "Claude Code"' 2>/dev/null || echo "Claude Code")
    MESSAGE=$(echo "$INPUT" | jq -r '.message // "Task completed"' 2>/dev/null || echo "Task completed")
fi

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
