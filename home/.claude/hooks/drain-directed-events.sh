#!/bin/bash
# Stop hook: drain DIRECTED agent-event-bus events that arrived while the
# session was working, so the agent sees DMs / help requests at end-of-turn
# instead of only on the next human prompt.
#
# Input (via stdin): JSON with session_id, stop_hook_active, cwd, transcript_path
# Output: JSON {"decision":"block","reason":"..."} when directed events wait;
#         silent (exit 0) otherwise.
#
# Why this exists:
#   prompt-events.sh (UserPromptSubmit) only fires when the human types. A
#   directed event sent to an idle/just-finished session would otherwise sit
#   unseen until the next prompt. This hook closes that gap by PEEKing the bus
#   at Stop and, if anything directed is waiting, blocking once to surface it.
#
# Cursor semantics (important):
#   The bus keeps ONE high-water cursor per session_id, shared by BOTH hooks.
#   - PEEK (non-consuming) lets us look without moving the cursor.
#   - We only CONSUME (advance the cursor) when we actually surface events.
#   - When we surface, we surface ALL peeked events (directed + ambient), then
#     consume, because the single cursor can't selectively skip ambient ones.
#     Surfacing ambient alongside directed is lossless and correct.
#   - When there are NO directed events we neither surface nor consume, leaving
#     everything for prompt-events.sh to pull on the next UserPromptSubmit.
#
# Stop-hook ordering / multi-block interaction (ORDERING IS LOAD-BEARING):
#   Claude Code honors ONE block decision per Stop; a hook cannot observe
#   whether its own block "won". Because this hook CONSUMES (advances the
#   shared cursor) when it blocks, it MUST be registered BEFORE any other
#   blocking Stop hook (enforce-insight-publish.sh) so its block is the one
#   honored — otherwise the events would be consumed but the surfacing reason
#   dropped, silently losing the DM/help_needed. Cost of this ordering: on a
#   turn where both would block, insight enforcement is skipped once (both
#   hooks exit early on stop_hook_active at the continuation Stop). That is
#   the accepted trade — a missed best-effort policy nudge beats losing a
#   directed event. See hooks/README.md "Event-drain architecture".
#
# NEVER block the session on error: every failure path exits 0.

set -euo pipefail

# Read stdin (always consume to avoid broken pipe).
INPUT=$(cat)

# Loop guard: do not re-fire on our own block (mirrors enforce-insight-publish.sh).
# Done before sourcing the lib / requiring the cli so the guard is robust.
if command -v jq >/dev/null 2>&1; then
    STOP_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
    [[ "$STOP_ACTIVE" == "true" ]] && exit 0
fi

# Source shared collection library (denylist + fetch path shared w/ prompt-events.sh).
# shellcheck source=lib/eventbus-collect.sh
source "$(dirname "$0")/lib/eventbus-collect.sh"

# Graceful degradation: need cli + jq.
eb_have_deps || exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
[[ -z "$SESSION_ID" ]] && exit 0

# Determine this session's repo (for repo:<name> help_needed classification),
# from cwd/git like session-start.sh does. Best-effort; empty REPO is fine.
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[[ -z "$CWD" ]] && CWD="$PWD"
REPO=""
if command -v git >/dev/null 2>&1 && git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1; then
    COMMON_DIR=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null)
    if [[ "$COMMON_DIR" == /* ]]; then
        REPO=$(basename "$(dirname "$COMMON_DIR")")
    else
        REPO=$(basename "$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$CWD")
    fi
else
    REPO=$(basename "$CWD" 2>/dev/null || echo "")
fi

# PEEK new events (non-consuming), JSON for classification, ascending order.
# JSON shape (verified live): {"events":[{event_id,event_type,payload,channel},...]}.
PEEKED=$(eb_fetch_events "$SESSION_ID" peek json asc)
[[ -z "$PEEKED" ]] && exit 0

# Count DIRECTED events:
#   DIRECTED = channel == "session:<this session_id>"
#           OR (event_type == "help_needed" AND channel == "repo:<this repo>")
SESSION_CHANNEL="session:$SESSION_ID"
REPO_CHANNEL=""
[[ -n "$REPO" ]] && REPO_CHANNEL="repo:$REPO"

DIRECTED=$(echo "$PEEKED" | jq -r \
    --arg sc "$SESSION_CHANNEL" --arg rc "$REPO_CHANNEL" '
      (.events // [])
      | [ .[] | select(
            (.channel == $sc)
            or (.event_type == "help_needed" and $rc != "" and .channel == $rc)
          )
        ] | length' 2>/dev/null || echo 0)

# No directed events (or parse failure): leave everything for prompt-events.sh.
# Do NOT consume.
if [[ -z "$DIRECTED" ]] || ! [[ "$DIRECTED" =~ ^[0-9]+$ ]] || [[ "$DIRECTED" -eq 0 ]]; then
    exit 0
fi

# Render ALL peeked events from the JSON we already hold — no second peek
# (avoids doubled bus traffic and a divergent event set). Format mirrors
# the CLI's text mode: "[id] type (channel)" + indented payload.
SUMMARY=$(echo "$PEEKED" | jq -r '
    (.events // [])[] | "[\(.event_id)] \(.event_type) (\(.channel))\n    \(.payload)"' 2>/dev/null)
[[ -z "$SUMMARY" ]] && exit 0

PEEKED_COUNT=$(echo "$PEEKED" | jq -r '(.events // []) | length' 2>/dev/null) || exit 0
[[ "$PEEKED_COUNT" =~ ^[0-9]+$ ]] || exit 0
[[ "$PEEKED_COUNT" -eq 0 ]] && exit 0

REASON=$(printf 'Directed event(s) arrived while you were working. Address them before going idle.\n\n<recent-events>\n%s\n</recent-events>' "$SUMMARY")

# Consume to advance the shared cursor past what we just surfaced, BOUNDED to
# exactly the peeked count (asc order → the same events). An unbounded consume
# would also swallow any event that arrived between the peek above and now,
# consuming it without ever surfacing it. Bounding closes that window: late
# arrivals stay behind the cursor for the next Stop / prompt-events.sh pull.
#
# ASSUMES the CLI applies --limit AFTER --exclude (PEEKED_COUNT is a
# post-exclusion count), consistently between peek and consume. If a CLI
# change ever counted --limit pre-exclusion, this consume could over-advance
# and silently drop events — revisit this bound if that flag semantic changes.
eb_fetch_events "$SESSION_ID" consume text asc "$PEEKED_COUNT" >/dev/null 2>&1 || true

# Block once, surfacing all peeked events so the agent can act.
jq -n --arg reason "$REASON" '{decision: "block", reason: $reason}'
exit 0
