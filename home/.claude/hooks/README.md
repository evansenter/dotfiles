# Claude Code Hooks

Shell scripts that run at specific points in the Claude Code lifecycle. Configured in `settings.json` under the `hooks` key.

## Hook Lifecycle

```
Session Start
    │
    ├── SessionStart hook (session-start.sh)
    │   - Registers with event bus
    │   - Renames zellij tab to directory name
    │   - Fetches recent events
    │
    ▼
┌─────────────────────────────────────┐
│  User sends prompt                  │
│      │                              │
│      ├── UserPromptSubmit hooks     │
│      │   - prompt-events.sh         │
│      │   - zj-status.sh working     │
│      │                              │
│      ▼                              │
│  Claude processes...                │
│      │                              │
│      ├── TaskCreated hook           │
│      │   - task-created.sh          │
│      │   (publishes to event bus)   │
│      │                              │
│      ├── TaskCompleted hook         │
│      │   - task-completed.sh        │
│      │   (publishes to event bus)   │
│      │                              │
│      ├── PostToolUseFailure hook    │
│      │   - post-tool-failure.sh     │
│      │   (detects recurring errors) │
│      │                              │
│      ├── Notification hook          │
│      │   - notification.sh          │
│      │   (surfaces in zjstatus bar) │
│      │                              │
│      ├── Stop hooks (run in order): │
│      │   1. zj-status.sh waiting    │
│      │   2. enforce-insight-publish │
│      │      (blocks if ★ Insight    │
│      │       without publish_event) │
│      │   3. drain-directed-events   │
│      │      (blocks to surface DMs/  │
│      │       help_needed at idle)   │
│      │                              │
│      ▼                              │
│  (repeat)                           │
└─────────────────────────────────────┘
    │
    ├── PreCompact hook (pre-compact.sh)
    │   - Runs before context summarization
    │   - Checkpoints WIP state to event bus
    │
    ▼
Session End / Agent Teams
    │
    ├── TeammateIdle hook (teammate-idle.sh)
    │   - Publishes teammate_idle to event bus
    │   - Fires when a teammate has no work
    │
    └── SessionEnd hook (session-end.sh)
        - Unregisters from event bus
```

## Hook Details

### session-start.sh
**Trigger:** `SessionStart`

**Purpose:** Initialize session context and cross-session coordination.

**Actions:**
1. Rename zellij tab to directory name (with worktree format: `repo (branch)`)
2. Register with event bus using `agent-event-bus-cli`
3. Fetch recent events (last 20, newest first)
4. If resuming after compaction, restore WIP checkpoint

**Input JSON fields:** `session_id`, `transcript_path`, `cwd`, `permission_mode`, `source`

**Output:** Registration confirmation and recent events in `<recent-events>` tags

---

### session-end.sh
**Trigger:** `SessionEnd`

**Purpose:** Clean up session resources.

**Actions:**
1. Unregister from event bus

**Input JSON fields:** `session_id`, `transcript_path`, `cwd`, `permission_mode`, `reason`

**Output:** Unregistration confirmation

---

### prompt-events.sh
**Trigger:** `UserPromptSubmit`

**Purpose:** Show new events since last prompt (incremental polling).

**Actions:**
1. Fetch new events using `--resume` flag (server tracks cursor per session)
2. Output events if any new ones exist

**Input JSON fields:** `session_id`, `transcript_path`, `cwd`

**Output:** New events in `<recent-events>` tags (only if new events exist)

**Shared lib:** Uses `lib/eventbus-collect.sh` for `~/.extra`/`AGENT_EVENT_BUS_URL` handling, the canonical `EB_EXCLUDE` denylist, and the `eb_fetch_events` wrapper — the same code path as `drain-directed-events.sh`, so the two hooks cannot diverge. See [Event-drain architecture](#event-drain-architecture).

---

### zj-status.sh
**Trigger:** `UserPromptSubmit` (with arg `working`), `Stop` (with arg `waiting`)

**Purpose:** Visual indicator of Claude's state via zjstatus notification pipe.

**Actions:**
- `working`: Send `⏳ working...` notification to zjstatus
- `waiting`: Clear zjstatus notification

**Input:** Consumes stdin (required) but doesn't use it. State passed as argument.

**Output:** None (zellij pipe commands only)

---

### pre-compact.sh
**Trigger:** `PreCompact`

**Purpose:** Preserve work-in-progress state before context summarization.

**Actions:**
1. Gather current state (branch, PR number, modified files)
2. Build work ID from branch name (e.g., `issue-123` → `work: issue-123`)
3. Publish `wip_checkpoint` event to event bus
4. Event is sent to `session:<id>` channel for later retrieval

**Input JSON fields:** `session_id`, `transcript_path`, `cwd`, `trigger`

**Output:** Confirmation message

---

### teammate-idle.sh
**Trigger:** `TeammateIdle` (Agent Teams)

**Purpose:** Broadcast when a teammate agent has no work, enabling coordination visibility.

**Actions:**
1. Parse teammate name and team from stdin JSON
2. Publish `teammate_idle` event to event bus on `repo:<name>` channel

**Input JSON fields:** `session_id`, `transcript_path`, `cwd`, `permission_mode`, `teammate_name`, `team_name`

**Output:** None (side-effect only)

**Exit code:** Must be 0. Exit code 2 would keep the teammate working instead of going idle.

---

### task-created.sh
**Trigger:** `TaskCreated` — fires whenever a task is created via the `TaskCreate` tool (solo sessions and Agent Teams alike; `teammate_name`/`team_name` are empty outside teams)

**Purpose:** Broadcast task creation for cross-agent visibility.

**Actions:**
1. Parse task subject and teammate from stdin JSON
2. Publish `task_created` event to event bus on `repo:<name>` channel

**Input JSON fields:** `session_id`, `transcript_path`, `cwd`, `permission_mode`, `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`

**Output:** None (side-effect only)

**Exit code:** Must be 0. Exit code 2 would prevent the task from being created.

---

### task-completed.sh
**Trigger:** `TaskCompleted` — fires whenever a task is marked complete (solo sessions and Agent Teams alike; `teammate_name`/`team_name` are empty outside teams)

**Purpose:** Broadcast task completion for coordination.

**Actions:**
1. Parse task subject and teammate from stdin JSON
2. Publish `task_completed` event to event bus on `repo:<name>` channel

**Input JSON fields:** `session_id`, `transcript_path`, `cwd`, `permission_mode`, `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`

**Output:** None (side-effect only)

**Exit code:** Must be 0. Exit code 2 would prevent the task from being marked complete.

---

### enforce-insight-publish.sh
**Trigger:** `Stop`

**Purpose:** Enforce the "★ Insight → publish_event" rule from global CLAUDE.md. Blocks turn end if the assistant emitted one or more `★ Insight` blocks but made no `mcp__agent-event-bus__publish_event` tool calls in the same turn.

**Actions:**
1. Exit 0 if `stop_hook_active` is true (prevents infinite loop after a prior block)
2. Exit 0 if `transcript_path` is missing or the file doesn't exist
3. **Wait for transcript to stabilize** — poll line count every 100ms until unchanged across two samples (hard cap: 1s). This handles a race with Claude Code's transcript writer: the current turn's `text` block can be flushed after the Stop hook starts, so reading too early sees only the preceding `thinking` event.
4. Parse the JSONL transcript to find the last "real" user message (string content, or array without `tool_result` blocks)
5. Count `★ Insight ─` markers in assistant text blocks after that point
6. Count `mcp__agent-event-bus__publish_event` tool_use blocks after that point
7. If insights > 0 and publishes == 0, emit `{"decision": "block", "reason": "..."}` to force Claude to publish before the turn ends
8. Otherwise exit silently

Counting is lenient: one `publish_event` covers all insights in the turn (matches how insights are often batched into a single cross-session event).

**Input JSON fields:** `session_id`, `transcript_path`, `stop_hook_active`, `cwd`

**Output:** `{"decision": "block", "reason": "..."}` when the rule is violated. Silent otherwise.

**Exit code:** Always 0. Blocking is signaled via the JSON `decision` field, not the exit code.

---

### notification.sh
**Trigger:** `Notification`

**Purpose:** Surface Claude Code notifications in the zjstatus bar — permission requests, idle "waiting for input" prompts, and background agent events (`agent_needs_input` / `agent_completed`, fired by background agents since CC v2.1.198).

**Actions:**
1. Exit silently if not inside zellij, jq is missing, or stdin isn't valid JSON
2. Parse `message` and optional `notification_type` from stdin JSON, truncating the message to 60 chars inside jq (codepoint-safe — bash slicing counts bytes under a C locale and can split multibyte chars)
3. Map to icon: `agent_completed` → ✅, permission prompts (`permission*` type, or "permission" in the message text since permission notifications arrive untyped) → 🔐, everything else (incl. `agent_needs_input`) → 🔔
4. Send `zjstatus::notify::<icon> <message>` via zellij pipe

The notify slot is shared with `zj-status.sh` (working/waiting); notifications intentionally overwrite the working indicator. A mid-turn notification stays visible until the turn ends (`Stop` clears the slot; the next `UserPromptSubmit` rewrites it).

**Input JSON fields:** `session_id`, `cwd`, `message`, `notification_type` (background agent events only)

**Output:** None (zellij pipe side effect only)

**Exit code:** Always 0 (graceful degradation without zellij/jq, and on malformed input).

---

### drain-directed-events.sh
**Trigger:** `Stop`

**Purpose:** Surface **directed** event-bus events (DMs to `session:<id>`, or `help_needed` on the session's `repo:<name>` channel) that arrived while the session was working, so the agent acts on them at end-of-turn instead of waiting until the next human prompt. `prompt-events.sh` (UserPromptSubmit) only fires when the human types; a directed event sent to an idle/just-finished session would otherwise sit unseen.

**Actions:**
1. Exit 0 if `stop_hook_active` is true (loop guard, mirrors `enforce-insight-publish.sh`).
2. Exit 0 (silent) if jq, `agent-event-bus-cli`, or `session_id` is missing — never block on degradation.
3. Derive `repo` from `cwd` (git common-dir / toplevel, falling back to `cwd` basename) for `repo:<name>` classification.
4. **Peek** new events (non-consuming, JSON) and classify DIRECTED = `channel == session:<id>` OR (`event_type == help_needed` AND `channel == repo:<name>`).
5. If no directed events: exit 0 without consuming — leave everything for the next `prompt-events.sh` pull.
6. If ≥1 directed: re-peek as text, emit `{"decision": "block", "reason": "...<recent-events>..."}` surfacing **all** peeked events, then do a consuming read to advance the cursor.

**Input JSON fields:** `session_id`, `transcript_path`, `stop_hook_active`, `cwd`

**Output:** `{"decision": "block", "reason": "..."}` (with surfaced events in `<recent-events>` tags) when directed events wait. Silent otherwise.

**Exit code:** Always 0. Blocking is signaled via the JSON `decision` field.

See [Event-drain architecture](#event-drain-architecture) for the shared-lib design, cursor/peek semantics, and the multi-Stop-hook ordering caveat.

---

### post-tool-failure.sh
**Trigger:** `PostToolUseFailure`

**Purpose:** Detect recurring tool error patterns via event bus and inject context back to Claude.

**Actions:**
1. Skip benign errors (interrupts, expected exploration failures)
2. Build pattern signature from tool name + error prefix (80 chars)
3. Publish `error_pattern` event to event bus on `repo:<name>` channel
4. Query event bus for matching recent events
5. If ≥3 matches: output JSON with `additionalContext` for Claude

**Input JSON fields:** `session_id`, `cwd`, `tool_name`, `tool_input`, `error`, `is_interrupt`

**Output:** JSON with `hookSpecificOutput.additionalContext` when recurring pattern detected. Silent otherwise.

**Exit code:** Always 0. Uses `additionalContext` for feedback, not exit codes.

## Event-drain architecture

Two hooks read the agent-event-bus and surface events to the agent:

- **`prompt-events.sh`** (`UserPromptSubmit`) — fires when the human types. Consumes new events and injects them as `<recent-events>`.
- **`drain-directed-events.sh`** (`Stop`) — fires at end-of-turn. Peeks for *directed* events and blocks once to surface them if any are waiting, closing the gap where a session goes idle without seeing a DM / help request.

### Shared library (`lib/eventbus-collect.sh`)

Both hooks `source "$(dirname "$0")/lib/eventbus-collect.sh"` so they **cannot diverge**. It is the single source of truth for:

- `~/.extra` sourcing + `AGENT_EVENT_BUS_URL` → `EB_URL_ARGS` (one fetch path).
- `EB_EXCLUDE` — one canonical denylist of noisy event types.
- `eb_have_deps` — graceful-degradation guard (`agent-event-bus-cli` AND `jq`).
- `eb_fetch_events SESSION_ID PEEK FORMAT ORDER` — thin wrapper over `agent-event-bus-cli events`, always `--resume`. `peek`→`--peek` (non-consuming); `json`→`--json`.

Bootstrap symlinks the whole `hooks/` dir, so `lib/` rides along automatically.

### Event-bus JSON schema (verified live)

`events --json` returns a **top-level object**: `{"events":[{event_id, event_type, payload, channel}, …], "next_cursor": …}`. The human-readable field is `payload` (not `message`); classification keys on `channel`.

### Peek / cursor semantics

The bus keeps **one high-water cursor per `session_id`**, shared by both hooks.

- **Peek** is non-consuming: it looks without advancing the cursor.
- The drain only **consumes** (advances the cursor) when it actually surfaces events — i.e. only when it blocks.
- When it blocks, it surfaces **all** peeked events (directed *and* ambient), because the single shared cursor can't selectively skip the ambient ones. Surfacing ambient alongside directed is lossless and correct.
- When there are **no directed** events, it neither surfaces nor consumes — everything is left in place for the next `prompt-events.sh` pull on `UserPromptSubmit`. (No directed → no consume → ambient flows normally.)

### Multi-Stop-hook ordering caveat

`drain-directed-events.sh` is registered in `settings.json` **after** `enforce-insight-publish.sh`. Both can emit `{"decision":"block"}`, and Claude Code honors **one** block decision per Stop. This is safe by design: the drain *peeks* and only *consumes when it wins*. If `enforce-insight-publish.sh` wins a given Stop, the directed events are left intact (unconsumed) and drain on the next Stop. No directed event is lost to the race.

## Writing Hooks

### Requirements
- Must be executable (`chmod +x`)
- Must consume stdin (even if not used) to avoid broken pipe errors
- Should use `set -euo pipefail` for safety
- Should gracefully degrade if dependencies missing (jq, agent-event-bus-cli, zellij)
- Source `~/.extra` if the hook needs user environment variables (e.g., `AGENT_EVENT_BUS_URL`)

### Input Format
All hooks receive JSON on stdin with at least:
```json
{
  "session_id": "uuid",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory"
}
```

Additional fields vary by hook type.

### Output
- Text output is shown to Claude as context
- Use XML tags for structured data (e.g., `<recent-events>`)
- Exit 0 for success (non-zero doesn't block Claude, but may show error)

### Testing
Run `make test-hooks` to test all hooks. Add tests for new hooks in `tests/test-hooks.sh`.

### Gotchas

**jq multiline regex: prefer explicit alternation over `^`+`m` flag.** In jq 1.8.1, `scan("^pattern"; "m")` can silently fail to match at line starts, especially when `^` is near a character class. Use `match("(?:^|\\n)pattern"; "g")` instead — explicit newline alternation behaves reliably. See `enforce-insight-publish.sh` for a working example.

**"No-jq" tests: symlink `cat` + `bash` into a fake PATH, not an empty dir.** Every hook reads stdin via `cat`, which needs PATH to resolve before the `command -v jq` check runs. A truly empty PATH fails with `cat: command not found` (exit 127) before the graceful-degradation branch is reached. Fix:

```bash
local no_jq_dir="$TEST_TMP/no-jq"
mkdir -p "$no_jq_dir"
ln -sf "$(type -P cat)"  "$no_jq_dir/cat"
ln -sf "$(type -P bash)" "$no_jq_dir/bash"
env -i PATH="$no_jq_dir" HOME="$HOME" bash "$HOOKS_DIR/your-hook.sh"
```

`env -i` is load-bearing: without it, PATH inherits from the test shell, and on Debian/Ubuntu CI runners `/usr/bin/jq` would be found — the test then passes via an unrelated code path and masks regressions. Use `type -P`, not `command -v` — it bypasses shell aliases (your outer zsh may have `alias cat=bat` etc. that would break the symlink).

**Stop hooks race Claude Code's transcript writer.** If your Stop hook reads `transcript_path` and inspects the current turn's assistant output, the last `text` block may not be flushed yet when the hook runs. Empirically: 3 of 4 firings lose the race on a fast machine, with the hook seeing only the preceding `thinking` event. Any content-inspecting Stop hook needs quiescence detection before reading. The pattern used in `enforce-insight-publish.sh`: poll `wc -l` every 100ms and, once the line count is stable for two samples, **gate on a content check** — keep waiting until the current turn actually contains an assistant `text` block. A line-count-only check is insufficient: a writer that hasn't started flushing the final block yet reads as "stable & empty" and the hook misses the insight. Hard-cap ~2s, but a turn that's been quiescent for ~500ms (5 stable samples) proceeds even without a text block, so pure `tool_use` turns aren't penalized. The content check is only run while the file looks settled (stable samples 2–4), bounding the per-poll `jq` cost.

## Configuration

In `settings.json`:
```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/session-start.sh" }] }],
    "SessionEnd": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/session-end.sh" }] }],
    "UserPromptSubmit": [{ "hooks": [
      { "type": "command", "command": "~/.claude/hooks/prompt-events.sh" },
      { "type": "command", "command": "~/.claude/hooks/zj-status.sh working" }
    ] }],
    "Stop": [{ "hooks": [
      { "type": "command", "command": "~/.claude/hooks/zj-status.sh waiting" },
      { "type": "command", "command": "~/.claude/hooks/enforce-insight-publish.sh" },
      { "type": "command", "command": "~/.claude/hooks/drain-directed-events.sh" }
    ] }],
    "PreCompact": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/pre-compact.sh" }] }],
    "TeammateIdle": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/teammate-idle.sh" }] }],
    "TaskCreated": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/task-created.sh" }] }],
    "TaskCompleted": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/task-completed.sh" }] }],
    "PostToolUseFailure": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/post-tool-failure.sh" }] }],
    "Notification": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/notification.sh" }] }]
  }
}
```
