#!/bin/bash
# Shared agent-event-bus collection library.
#
# Single source of truth for the two event-bus hooks so they CANNOT diverge:
#   - prompt-events.sh         (UserPromptSubmit): consumes events, injects <recent-events>
#   - drain-directed-events.sh (Stop):             peeks for directed events, surfaces+consumes
#
# This file is meant to be SOURCED, not executed. It provides:
#   EB_URL_ARGS        array of --url args (empty if AGENT_EVENT_BUS_URL unset)
#   EB_EXCLUDE         canonical denylist of noisy event types
#   eb_have_deps       func: returns 0 iff agent-event-bus-cli AND jq are present
#   eb_fetch_events    func: thin wrapper over `agent-event-bus-cli events`
#
# Symlink note: bootstrap symlinks the whole hooks/ dir, so lib/ rides along.
# Hooks source this via: "$(dirname "$0")/lib/eventbus-collect.sh".
#
# Callers run under `set -euo pipefail`; this lib must be safe under it.

# Source user's environment for AGENT_EVENT_BUS_URL, defensively (PR #314 pattern).
# ~/.extra is user-edited and untracked; a stray unset var or non-zero line must
# not abort the hook under set -euo pipefail.
if [[ -f ~/.extra ]]; then
    set +eu
    # shellcheck source=/dev/null
    source ~/.extra
    set -eu
fi

# Build --url args from AGENT_EVENT_BUS_URL if set (e.g. remote Tailscale endpoint).
EB_URL_ARGS=()
[[ -n "${AGENT_EVENT_BUS_URL:-}" ]] && EB_URL_ARGS=(--url "$AGENT_EVENT_BUS_URL")

# Canonical denylist of noisy event types. Both hooks MUST use this one list.
EB_EXCLUDE="session_registered,session_unregistered,ci_watching,task_started,ci_rerun,parallel_work_started"

# Graceful-degradation guard: caller should `eb_have_deps || exit 0`.
# Returns 0 iff both the CLI and jq are available.
eb_have_deps() {
    command -v agent-event-bus-cli >/dev/null 2>&1 && command -v jq >/dev/null 2>&1
}

# Fetch events for a session via the CLI.
#
# Usage: eb_fetch_events SESSION_ID PEEK FORMAT ORDER
#   SESSION_ID  required (used for cursor tracking; client-id == session-id)
#   PEEK        "peek" -> non-consuming (--peek); anything else -> consuming
#   FORMAT      "json" -> --json; anything else -> default text rendering
#   ORDER       "asc" | "desc" (default asc)
#
# Always uses --resume so the server tracks the per-session high-water cursor.
# JSON output is a top-level object: {"events":[{event_id,event_type,payload,
# channel}, ...], "next_cursor": ...}. Text output is the CLI's human format.
# Emits the CLI's stdout on success; empty string on any failure (never errors).
eb_fetch_events() {
    local session_id="$1" peek="${2:-consume}" format="${3:-text}" order="${4:-asc}"
    local flags=(--resume --session-id "$session_id" --order "$order" --exclude "$EB_EXCLUDE" --timeout 200 --limit 20)
    [[ "$peek" == "peek" ]] && flags+=(--peek)
    [[ "$format" == "json" ]] && flags+=(--json)
    agent-event-bus-cli ${EB_URL_ARGS[@]+"${EB_URL_ARGS[@]}"} events "${flags[@]}" 2>/dev/null || true
}
