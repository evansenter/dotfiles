#!/bin/bash
# Update tmux window title based on Claude state
#
# Usage in settings.json hooks:
#   UserPromptSubmit: tmux-status.sh working
#   Stop: tmux-status.sh waiting
#
# Only runs if inside tmux

set -euo pipefail

# Skip if not in tmux
[[ -z "${TMUX:-}" ]] && exit 0

# Consume stdin (required for hooks)
cat > /dev/null

STATE="${1:-waiting}"

# Get the pane ID where this hook is running (not necessarily the focused pane)
PANE_ID="${TMUX_PANE:-}"
if [[ -z "$PANE_ID" ]]; then
    exit 0
fi

# Get window ID and dirname for this specific pane
WINDOW_ID=$(tmux display-message -t "$PANE_ID" -p '#{window_id}' 2>/dev/null) || exit 0
DIR_NAME=$(tmux display-message -t "$PANE_ID" -p '#{b:pane_current_path}' 2>/dev/null) || DIR_NAME=$(basename "$PWD")

case "$STATE" in
    working)
        # Disable automatic-rename and allow-rename so our title sticks
        tmux set-window-option -t "$WINDOW_ID" automatic-rename off 2>/dev/null || true
        tmux set-window-option -t "$WINDOW_ID" allow-rename off 2>/dev/null || true
        tmux rename-window -t "$WINDOW_ID" "⏳ $DIR_NAME" 2>/dev/null || true
        ;;
    waiting)
        # Keep renames disabled while Claude is running
        tmux rename-window -t "$WINDOW_ID" "$DIR_NAME" 2>/dev/null || true
        ;;
esac
