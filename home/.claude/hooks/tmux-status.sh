#!/bin/bash
# Update tmux window title based on Claude state
#
# Usage in settings.json hooks:
#   UserPromptSubmit: tmux-status.sh working
#   Stop: tmux-status.sh waiting
#
# Only runs if inside tmux

set -euo pipefail

# Consume stdin (required for hooks — must be before any exit)
cat > /dev/null

# Skip if not in tmux
[[ -z "${TMUX:-}" ]] && exit 0

STATE="${1:-waiting}"

# Get the pane ID where this hook is running (not necessarily the focused pane)
PANE_ID="${TMUX_PANE:-}"
if [[ -z "$PANE_ID" ]]; then
    exit 0
fi

# Get window ID and path for this specific pane
WINDOW_ID=$(tmux display-message -t "$PANE_ID" -p '#{window_id}' 2>/dev/null) || exit 0
PANE_PATH=$(tmux display-message -t "$PANE_ID" -p '#{pane_current_path}' 2>/dev/null) || PANE_PATH="$PWD"

# Build display name - handle worktrees: show "branch (repo)" format
DIR_NAME="${PANE_PATH##*/}"
if [[ "$PANE_PATH" == */.worktrees/* ]]; then
    worktree_parent="${PANE_PATH%/.worktrees/*}"
    repo_name="${worktree_parent##*/}"
    worktree_branch="${PANE_PATH##*/}"
    DIR_NAME="${repo_name} (${worktree_branch})"
fi

case "$STATE" in
    working)
        # Disable automatic-rename and allow-rename so our title sticks
        tmux set-window-option -t "$WINDOW_ID" automatic-rename off 2>/dev/null || true
        tmux set-window-option -t "$WINDOW_ID" allow-rename off 2>/dev/null || true
        tmux rename-window -t "$WINDOW_ID" "⏳ $DIR_NAME" 2>/dev/null || true
        ;;
    waiting)
        # Remove hourglass indicator
        tmux rename-window -t "$WINDOW_ID" "$DIR_NAME" 2>/dev/null || true
        ;;
    *)
        echo "tmux-status.sh: unknown state '$STATE', expected 'working' or 'waiting'" >&2
        ;;
esac
