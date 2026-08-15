#!/bin/bash
# Tell the event-bus bridge whether this session is mid-turn.
#
# Usage in settings.json hooks:
#   UserPromptSubmit: wake-state.sh busy
#   Stop:             wake-state.sh idle
#
# The bridge (agent-event-bus RFC #122) wakes an idle session by typing a
# fixed prompt into its terminal pane. It injects ONLY between turns, keyed
# on the marker this script maintains. Gating costs no coverage — mid-turn,
# drain-directed-events.sh already surfaces directed events at end-of-turn —
# and it keeps injected keystrokes out of the one window where a permission
# dialog can be on screen to consume them.
#
# Ordering note: registered LAST in both slots. In Stop that keeps it clear of
# the load-bearing block ordering between drain-directed-events.sh and
# enforce-insight-publish.sh (see README "Multi-Stop-hook ordering caveat") —
# this hook never blocks, so its position cannot affect which block wins.
#
# NEVER block the session on error: every failure path exits 0.

set -euo pipefail

# Consume stdin (required for hooks — must be before any exit)
INPUT=$(cat)

# No default. zj-status.sh and tmux-status.sh use `${1:-waiting}`, and that is
# fine for a status bar — but this argument decides whether a wake may be
# injected, and defaulting a MISSING one to `idle` fails OPEN: a miswiring
# would silently disable the gate and let a wake land mid-turn, which is the
# thing the gate exists to prevent. A missing argument is not evidence of
# either state, so it is treated exactly like an unknown one: write nothing
# and leave whatever the last known state was.
STATE="${1:-}"
case "$STATE" in
    busy | idle) ;;
    *)
        echo "wake-state.sh: expected 'busy' or 'idle', got '${STATE:-(none)}'" >&2
        exit 0
        ;;
esac

# Graceful degradation: the bridge is optional and experimental, so a box
# without the CLI (or without jq) simply has no idle gate.
command -v agent-event-bus-cli &>/dev/null || exit 0
command -v jq &>/dev/null || exit 0

# Claude Code's session_id IS the bus session_id: session-start.sh registers
# with --client-id set to it, and the bus adopts a client_id as its session_id
# verbatim. So the marker can be keyed from stdin without asking the bus —
# which matters because this runs on every turn boundary and must not depend
# on the bus being up.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null) || exit 0
[[ -z "$SESSION_ID" ]] && exit 0

agent-event-bus-cli wake-state "$STATE" --session-id "$SESSION_ID" >/dev/null 2>&1 || true
