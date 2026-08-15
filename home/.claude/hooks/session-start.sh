#!/bin/bash
# Session start hook: Registers with the event bus and fetches recent events
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, permission_mode, source
# Output: Text context that Claude reads on session start

set -euo pipefail

# Source user's environment for AGENT_EVENT_BUS_URL
if [[ -f ~/.extra ]]; then
    # ~/.extra is user-edited and untracked; a stray unset var or non-zero
    # line must not abort the hook under set -euo pipefail.
    set +eu
    # shellcheck source=/dev/null
    source ~/.extra
    set -eu
fi

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
    # git-common-dir returns absolute path in worktrees, relative in regular repos
    COMMON_DIR=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null)
    if [[ "$COMMON_DIR" == /* ]]; then
        REPO_NAME=$(basename "$(dirname "$COMMON_DIR")")
    else
        REPO_NAME=$(basename "$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$CWD")
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

# Map this session to its terminal pane so the RFC #122 bridge can wake it
# when it goes idle. Without this the bridge resolves every DM to
# "spool-unmapped" — which is also the normal outcome for a session on
# another machine, so a missing mapping never surfaces as an error, only as
# wakes that quietly never happen.
#
# `panes set` writes nothing at all when this session is not inside a
# multiplexer, which is the correct behaviour rather than a failure: the
# contract says OMIT the entry, because a null or empty one reads as a
# misconfiguration the bridge warns about and asks an operator to repair.
# It also evicts any stale entry on this same pane — a previous session
# killed without its SessionEnd hook would otherwise leave a mapping that has
# the bridge type into whatever now owns the pane.
#
# Also clear any turn-state marker left behind: reaching SessionStart means
# no turn is in flight, and a marker orphaned by a hard kill would otherwise
# keep this session's id gated as busy.
#
# `panes set` clears it too, so this is redundant against a current CLI. It
# stays because these two repos version independently: a machine that pulls
# dotfiles before agent-event-bus has a `panes set` that does NOT clear, and
# the failure it would leave — a resumed session gated busy while idle — is
# invisible from both sides.
agent-event-bus-cli panes set --session-id "$SESSION_ID" >/dev/null 2>&1 || true
agent-event-bus-cli wake-state idle --session-id "$SESSION_ID" >/dev/null 2>&1 || true

# Fetch recent events (newest-first for natural reading order - most relevant at top)
# Session is auto-subscribed to 4 channels:
# - "all" - broadcasts to everyone
# - "repo:<name>" - repo-specific coordination
# - "machine:<hostname>" - local machine coordination
# - "session:<id>" - direct messages (if resumed with same session_id)
# --min-level info drops lifecycle churn (session_registered, ci_watching,
# task_started, ...) server-side - one canonical noise policy on the bus
# (agent-event-bus#129) instead of a local denylist.
#
# The primary fetch and the version-skew fallback below differ only in
# their filter flag - one shared invocation keeps --timeout/--limit (and
# the stderr suppression) from drifting between the two call sites.
fetch_events() {
    agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} events \
        --session-id "$SESSION_ID" \
        --order desc \
        "$@" \
        --timeout 200 \
        --limit 20 \
        2>/dev/null
}

FETCH_RC=0
EVENTS=$(fetch_events --min-level info) || FETCH_RC=$?

# Version-skew fallback: a CLI predating --min-level (agent-event-bus#129)
# rejects the flag with an argparse usage error - exit 2, stderr suppressed,
# EVENTS empty - so retry once with the legacy client-side denylist. Exit 2
# discriminates that from a bus that is down or timed out (exit 1), where a
# retry can't help and would make every offline session start pay a second
# ~200ms timeout. A flag-aware CLI prints "No events" when there are
# genuinely none, so empty-with-success never fires the fallback either.
if [[ -z "$EVENTS" && $FETCH_RC -eq 2 ]]; then
    EVENTS=$(fetch_events --exclude session_registered,session_unregistered) || true
fi

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
