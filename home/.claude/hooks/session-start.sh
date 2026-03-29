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

# Rename zellij tab to directory name (if in zellij)
if [[ -n "${ZELLIJ:-}" ]]; then
    DIR_NAME="${PWD##*/}"
    if [[ "$PWD" == */.worktrees/* ]]; then
        worktree_parent="${PWD%/.worktrees/*}"
        repo_name="${worktree_parent##*/}"
        worktree_branch="${PWD##*/}"
        DIR_NAME="${repo_name} (${worktree_branch})"
    fi
    zellij action rename-tab "$DIR_NAME" 2>/dev/null || true
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

# Build URL args if AGENT_EVENT_BUS_URL is set (e.g., remote Tailscale endpoint)
URL_ARGS=()
[[ -n "${AGENT_EVENT_BUS_URL:-}" ]] && URL_ARGS=(--url "$AGENT_EVENT_BUS_URL")

# Register with event bus using CLI
REGISTER_ARGS=(--name "$SESSION_NAME")
[[ -n "$CLIENT_ID" ]] && REGISTER_ARGS+=(--client-id "$CLIENT_ID")

OUTPUT=$(agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} register "${REGISTER_ARGS[@]}" 2>/dev/null) || true
SESSION_ID=$(echo "$OUTPUT" | jq -r '.session_id // ""' 2>/dev/null)

if [[ -n "$SESSION_ID" ]]; then
    # Pre-populate statusline cache so it doesn't need to query the event bus
    DISPLAY_ID=$(echo "$OUTPUT" | jq -r '.display_id // ""')
    if [[ -n "$DISPLAY_ID" && -n "$CLIENT_ID" ]]; then
        CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline"
        mkdir -p "$CACHE_DIR" && chmod 700 "$CACHE_DIR" 2>/dev/null
        echo "$DISPLAY_ID" > "$CACHE_DIR/$CLIENT_ID" 2>/dev/null || true
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
EVENTS=$(agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} events \
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

# If resuming after compaction, fetch and display WIP checkpoint
if [[ "$SOURCE" == "compact" ]]; then
    # Fetch the most recent wip_checkpoint event for this session
    # Note: CLI has --include/--exclude but for specific types, use grep post-fetch
    WIP_EVENT=$(agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} events \
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
