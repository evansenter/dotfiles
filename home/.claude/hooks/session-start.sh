#!/bin/bash
# Session start hook: Registers with the event bus and fetches recent events
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, source
# Output: Text context that Claude reads on session start

set -euo pipefail

# Source user's environment for AGENT_EVENT_BUS_URL
[[ -f ~/.extra ]] && source ~/.extra

# Read and parse session info
INPUT=$(cat)

# Configure tmux window if in tmux (prevent Claude from overwriting window name)
if [[ -n "${TMUX:-}" ]] && [[ -n "${TMUX_PANE:-}" ]]; then
    WINDOW_ID=$(tmux display-message -t "$TMUX_PANE" -p '#{window_id}' 2>/dev/null) || true
    if [[ -n "$WINDOW_ID" ]]; then
        tmux set-window-option -t "$WINDOW_ID" allow-rename off 2>/dev/null || true
        tmux set-window-option -t "$WINDOW_ID" automatic-rename off 2>/dev/null || true

        # Set window name to directory (Claude already set it to "2.0.76" before hook ran)
        PANE_PATH=$(tmux display-message -t "$TMUX_PANE" -p '#{pane_current_path}' 2>/dev/null) || PANE_PATH="$PWD"
        DIR_NAME="${PANE_PATH##*/}"
        if [[ "$PANE_PATH" == */.worktrees/* ]]; then
            worktree_parent="${PANE_PATH%/.worktrees/*}"
            repo_name="${worktree_parent##*/}"
            worktree_branch="${PANE_PATH##*/}"
            DIR_NAME="${repo_name} (${worktree_branch})"
        fi
        tmux rename-window -t "$WINDOW_ID" "$DIR_NAME" 2>/dev/null || true
    fi
fi

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    # Graceful degradation: can't parse input without jq
    echo "Event bus registration skipped (jq not installed)"
    exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[[ -z "$CWD" ]] && CWD="$PWD"
CLIENT_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
SOURCE=$(echo "$INPUT" | jq -r '.source // "startup"')

# Derive session name (graceful fallback if git unavailable)
if command -v git &>/dev/null && git -C "$CWD" rev-parse --git-dir &>/dev/null; then
    # Use git-common-dir to get actual repo name (works in worktrees)
    GIT_COMMON=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null || echo "")
    if [[ -n "$GIT_COMMON" ]]; then
        REPO_NAME=$(basename "$(dirname "$GIT_COMMON")")
    else
        REPO_NAME=$(basename "$CWD")
    fi
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "")
    [[ -n "$BRANCH" ]] && SESSION_NAME="${REPO_NAME}/${BRANCH}" || SESSION_NAME="$REPO_NAME"
else
    REPO_NAME=$(basename "$CWD")
    SESSION_NAME="$REPO_NAME"
fi

# Check for agent-event-bus-cli
if ! command -v agent-event-bus-cli &>/dev/null; then
    echo "Event bus registration skipped (agent-event-bus-cli not installed)"
    exit 0
fi

# Register with event bus using CLI
REGISTER_ARGS=(--name "$SESSION_NAME")
[[ -n "$CLIENT_ID" ]] && REGISTER_ARGS+=(--client-id "$CLIENT_ID")

OUTPUT=$(agent-event-bus-cli register "${REGISTER_ARGS[@]}" 2>/dev/null) || true
SESSION_ID=$(echo "$OUTPUT" | jq -r '.session_id // ""')

if [[ -n "$SESSION_ID" ]]; then
    # Pre-populate statusline cache so it doesn't need to query the event bus
    DISPLAY_ID=$(echo "$OUTPUT" | jq -r '.display_id // ""')
    if [[ -n "$DISPLAY_ID" && -n "$CLIENT_ID" ]]; then
        CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline"
        mkdir -p "$CACHE_DIR" && chmod 700 "$CACHE_DIR" 2>/dev/null
        echo "$DISPLAY_ID" > "$CACHE_DIR/$CLIENT_ID" 2>/dev/null
    fi
    echo "Registered on event bus as: $SESSION_ID ($SESSION_NAME)"
else
    echo "Event bus registration failed"
    exit 0
fi

# Fetch recent events (newest-first for natural reading order - most relevant at top)
# Session is auto-subscribed to 4 channels:
# - "all" - broadcasts to everyone
# - "repo:<name>" - repo-specific coordination
# - "machine:<hostname>" - local machine coordination
# - "session:<id>" - direct messages (if resumed with same session_id)
EVENTS=$(agent-event-bus-cli events \
    --session-id "$SESSION_ID" \
    --order desc \
    --exclude session_registered,session_unregistered \
    --timeout 200 \
    --limit 20 \
    2>/dev/null) || true

# Output events in XML tags (interpretation guidance is in CLAUDE.md)
if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
    echo "<recent-events>"
    echo "$EVENTS"
    echo "</recent-events>"
fi

# Launch background event bus watcher
# Keeps an inbox file fresh between prompts so events are pre-staged
WATCHER_SCRIPT="$(dirname "$0")/event-bus-watcher.sh"
INBOX_DIR="${TMPDIR:-/tmp}/claude-event-inbox"
INBOX_PATH="$INBOX_DIR/$SESSION_ID.inbox"
mkdir -p "$INBOX_DIR" && chmod 700 "$INBOX_DIR" 2>/dev/null

# Kill any existing watcher for this session
WATCHER_PID_FILE="${INBOX_PATH}.pid"
if [[ -f "$WATCHER_PID_FILE" ]]; then
    OLD_PID=$(cat "$WATCHER_PID_FILE" 2>/dev/null)
    if [[ -n "$OLD_PID" ]] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null || true
    fi
fi

# Clear stale inbox and start fresh watcher
rm -f "$INBOX_PATH"
if [[ -x "$WATCHER_SCRIPT" ]]; then
    nohup "$WATCHER_SCRIPT" "$SESSION_ID" "$INBOX_PATH" 5 >/dev/null 2>&1 &
    disown
fi

# If resuming after compaction, fetch and display WIP checkpoint
if [[ "$SOURCE" == "compact" ]]; then
    # Fetch the most recent wip_checkpoint event for this session
    # Note: CLI has --include/--exclude but for specific types, use grep post-fetch
    WIP_EVENT=$(agent-event-bus-cli events \
        --session-id "$SESSION_ID" \
        --channel "session:${SESSION_ID}" \
        --limit 1 \
        --order desc \
        2>/dev/null | grep -E "wip_checkpoint" | head -1) || true

    if [[ -n "$WIP_EVENT" ]]; then
        echo ""
        echo "<wip-checkpoint-restored>"
        echo "Session resumed after compaction. Previous WIP state:"
        echo "$WIP_EVENT"
        echo "</wip-checkpoint-restored>"
    fi
fi
