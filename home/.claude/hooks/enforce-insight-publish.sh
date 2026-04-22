#!/bin/bash
# Stop hook: Enforces the "★ Insight → publish_event" rule from CLAUDE.md.
#
# Input (via stdin): JSON with transcript_path, stop_hook_active, session_id, cwd
# Output: JSON {"decision":"block","reason":"..."} when violated; silent otherwise.
#
# Scans the current assistant turn (events after the last real user message)
# for "★ Insight ─" markers in text blocks and mcp__agent-event-bus__publish_event
# calls in tool_use blocks. If insights > 0 and publishes == 0, blocks the turn
# and prompts Claude to publish before ending.
#
# Lenient counting: one publish_event covers all insights in the turn. Strict
# counting could be added later if Claude games the lenient form.

set -euo pipefail

INPUT=$(cat)

# Graceful degradation: no jq, nothing we can do.
command -v jq >/dev/null 2>&1 || exit 0

TRANSCRIPT_PATH=$(jq -r '.transcript_path // ""' <<<"$INPUT")
STOP_HOOK_ACTIVE=$(jq -r '.stop_hook_active // false' <<<"$INPUT")

# Prevent infinite loop: once we've blocked and Claude still didn't publish,
# let the turn end to avoid trapping the session.
[[ "$STOP_HOOK_ACTIVE" == "true" ]] && exit 0

# No transcript to inspect → nothing to enforce.
[[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]] && exit 0

# Wait for the transcript to stabilize. Stop hooks race Claude Code's
# transcript writer — at hook-start time, the current turn's final `text`
# block is often not yet flushed (only the preceding `thinking` block is
# visible). If we read too early we miss the insight and fail to block.
#
# Poll line count until it's unchanged across two 100ms samples. Typical
# latency is 100-200ms; hard cap is 1s. The alternative (fixed sleep) is
# simpler but pays the worst case every turn. See PR discussion for empirical
# data: 3 of 4 test firings lost this race before this wait was introduced.
prev_lines=-1
for _ in 1 2 3 4 5 6 7 8 9 10; do
    cur_lines=$(wc -l < "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)
    [[ "$cur_lines" -eq "$prev_lines" ]] && break
    prev_lines=$cur_lines
    sleep 0.1
done

# Parse the transcript: find the last "real" user event (string content or
# array without tool_result blocks), then count insight markers in text blocks
# and publish_event calls in tool_use blocks that come after it.
# Malformed transcript lines cause `jq -s` to fail hard; the `|| exit 0` below
# is deliberate — we never want a broken transcript to trap the session by
# repeatedly blocking Stop. Missing enforcement is preferable to missing exit.
#
# Marker regex: matches "★ Insight" followed by whitespace and 3+ divider
# characters (U+2500 light, U+2501 heavy, U+2550 double) anchored at line
# start, with an optional leading backtick. The backtick is there because
# the explanatory-output-style plugin wraps the decorator line in backticks:
#   `★ Insight ─────────`
# This excludes casual inline references like `the ★ Insight ─ marker` (only
# one divider char). Code-fenced examples at column 0 will still match —
# accepted trade-off.
ANALYSIS=$(jq -s '
  def is_real_user:
    .type == "user" and
    ((.message.content | type) == "string"
     or ((.message.content | type) == "array"
         and all(.message.content[]; .type != "tool_result")));

  . as $events
  | [range(0; length) | select($events[.] | is_real_user)] as $user_idxs
  | (if ($user_idxs | length) == 0 then 0 else ($user_idxs | last) + 1 end) as $start
  | $events[$start:]
  | {
      insights: (
        [ .[]
          | select(.type == "assistant")
          | .message.content[]?
          | select(.type == "text")
          | .text
          | match("(?:^|\\n)`?★ Insight[ \\t]+[─━═]{3,}"; "g")
        ] | length
      ),
      publishes: (
        [ .[]
          | select(.type == "assistant")
          | .message.content[]?
          | select(.type == "tool_use" and .name == "mcp__agent-event-bus__publish_event")
        ] | length
      )
    }
' "$TRANSCRIPT_PATH" 2>/dev/null) || exit 0

INSIGHTS=$(jq -r '.insights // 0' <<<"$ANALYSIS")
PUBLISHES=$(jq -r '.publishes // 0' <<<"$ANALYSIS")

if [[ "$INSIGHTS" -gt 0 && "$PUBLISHES" -eq 0 ]]; then
    MESSAGE="You emitted ${INSIGHTS} ★ Insight block(s) but made no publish_event calls this turn. Per global CLAUDE.md, publish insights to the event bus via mcp__agent-event-bus__publish_event before ending the turn. One publish_event can cover multiple related insights (lenient mode). If the insight is purely line-specific with no cross-session value, remove the ★ Insight block instead."
    jq -n --arg msg "$MESSAGE" '{decision: "block", reason: $msg}'
fi

exit 0
