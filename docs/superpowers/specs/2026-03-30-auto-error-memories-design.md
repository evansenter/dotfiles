# Auto-Create Memory Entries from Recurring Errors

**Issue:** #273
**Date:** 2026-03-30
**Status:** Approved

## Problem

Session analytics shows recurring errors across sessions (permission issues, path problems, hook failures) that currently require manual memory creation to learn from. This feature closes the learning loop automatically.

## Design Decisions

1. **Two-component pipeline:** A `PostToolUseFailure` hook for real-time in-session awareness, plus an `improve-workflow` agent enhancement for cross-session memory creation.
2. **Event bus as error tally:** No local temp files. The hook publishes `error_pattern` events to the event bus, then queries for matching recent events. Cross-session aggregation comes for free.
3. **Simple pattern matching:** `tool_name` + first 80 chars of error message. No normalization — YAGNI. The agent phase uses the model for semantic clustering if needed.
4. **Threshold: 3 occurrences** in 24h before triggering `additionalContext` injection.
5. **Agent Teams decomposition:** Three independent workstreams — hook, agent enhancement, docs/tests — suitable for parallel teammates.

## Component 1: PostToolUseFailure Hook

### File: `home/.claude/hooks/post-tool-failure.sh`

**Trigger:** `PostToolUseFailure` — fires after any tool call exits with a non-zero status or errors.

**Input JSON fields:** `session_id`, `cwd`, `tool_name`, `tool_input`, `error`, `is_interrupt`

**Flow:**
```
Tool fails → PostToolUseFailure fires
  → Skip if error is in benign denylist (see below)
  → Build pattern signature: "{tool_name}:{first_80_chars_of_error}"
  → Publish error_pattern event to event bus
      payload: pattern signature
      channel: repo:<name>
  → Query event bus for recent error_pattern events (last 24h)
  → Grep results for matching signature
  → If ≥3 matches: output JSON with additionalContext
      "⚠️ Recurring error (Nth occurrence in 24h): {tool_name} — {error_prefix}.
       This pattern has been seen across sessions. Consider investigating
       the root cause or creating a memory entry to prevent it."
  → If <3 matches: exit 0 silently
```

**Benign error denylist** (skip without publishing):
- `is_interrupt: true` — user cancelled, not an error
- Grep/Glob with "No files found" or "No matches" — normal exploration
- Read on nonexistent file during search — expected during codebase exploration

**Output format** (when threshold met):
```json
{
  "hookSpecificOutput": {
    "additionalContext": "⚠️ Recurring error (4th occurrence in 24h): Bash — Command exited with non-zero status code 1. This pattern has been seen across sessions. Consider investigating the root cause or creating a memory entry to prevent it."
  }
}
```

**Exit code:** Always 0. This hook has decision control (`additionalContext`), not gating control.

### Settings.json

```json
"PostToolUseFailure": [
  {
    "hooks": [
      { "type": "command", "command": "~/.claude/hooks/post-tool-failure.sh" }
    ]
  }
]
```

## Component 2: improve-workflow Agent Enhancement

### File: `home/.claude/agents/improve-workflow.md`

Add **Phase 2b** after existing Phase 2 (error analysis):

**Phase 2b: Auto-create error memories**

Triggered when: Phase 2 found error patterns (error rate > 5%).

Steps:
1. Call `get_error_details(days=7, limit=20)` to get recurring error patterns with counts
2. Filter to errors with 3+ occurrences across sessions
3. Read `MEMORY.md` index to check for existing memories on the same topic
4. For each new pattern not already covered:
   a. Create a `feedback` memory file:
      ```markdown
      ---
      name: <descriptive-slug>
      description: <one-line description of the error pattern>
      type: feedback
      ---

      <Error description and what triggers it>

      **Why:** Occurred N times across M sessions in the last 7 days.
      Tool: <tool_name>, typical error: <error_message>
      **How to apply:** <Suggested fix or avoidance strategy>
      ```
   b. Add entry to MEMORY.md index
5. Publish `gotcha_discovered` to event bus for each new memory created

**Deduplication:** Match existing memories by checking if MEMORY.md entries contain the tool name + error substring. If a memory already covers this pattern, skip it.

**Cap:** Create at most 3 memories per invocation to avoid noise.

## Component 3: Documentation & Tests

### Hook tests (in `tests/test-hooks.sh`)
- Syntax check
- Graceful degradation (no jq, no CLI)
- Benign error filtering (verify skipped errors don't publish)
- Happy path: below threshold (silent exit)
- Happy path: at threshold (additionalContext JSON output)
- Verify JSON output format matches `hookSpecificOutput` schema

### hooks/README.md
- Add `PostToolUseFailure` to lifecycle diagram (in the processing loop, after tool calls)
- Add hook detail section following existing format
- Document exit code and `additionalContext` output

### docs/agent-teams-setup.md
- Add `PostToolUseFailure` to the hooks table

## Agent Teams Execution Plan

| Teammate | Files | Dependencies |
|----------|-------|-------------|
| Hook builder | `post-tool-failure.sh`, `settings.json` | None — independent |
| Agent enhancer | `improve-workflow.md` | None — different file |
| Test/doc integrator | `test-hooks.sh`, `README.md`, `agent-teams-setup.md` | Blocked on hook builder (needs hook to test) |

Teammates 1 and 2 work in parallel. Teammate 3 starts on README/docs immediately, then picks up tests once the hook exists.

## Event Bus Events

| Event Type | Published By | Payload | Channel |
|------------|-------------|---------|---------|
| `error_pattern` | post-tool-failure.sh | `{tool_name}:{error_prefix_80}` | `repo:<name>` |
| `gotcha_discovered` | improve-workflow agent | Memory creation details | `repo:<name>` |

## Out of Scope

- Error normalization (stripping paths, UUIDs) — YAGNI, add if simple matching proves insufficient
- Configurable threshold — hardcoded at 3 for now
- Auto-deletion of stale error memories — manual cleanup
- StopFailure hook (API-level errors) — output is ignored by Claude Code, logging-only
