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
│      ├── Stop hooks (run in order): │
│      │   1. zj-status.sh waiting    │
│      │   2. enforce-insight-publish │
│      │      (blocks if ★ Insight    │
│      │       without publish_event) │
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
**Trigger:** `TaskCreated` (Agent Teams)

**Purpose:** Broadcast task creation for cross-agent visibility.

**Actions:**
1. Parse task subject and teammate from stdin JSON
2. Publish `task_created` event to event bus on `repo:<name>` channel

**Input JSON fields:** `session_id`, `transcript_path`, `cwd`, `permission_mode`, `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`

**Output:** None (side-effect only)

**Exit code:** Must be 0. Exit code 2 would prevent the task from being created.

---

### task-completed.sh
**Trigger:** `TaskCompleted` (Agent Teams)

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
3. Parse the JSONL transcript to find the last "real" user message (string content, or array without `tool_result` blocks)
4. Count `★ Insight ─` markers in assistant text blocks after that point
5. Count `mcp__agent-event-bus__publish_event` tool_use blocks after that point
6. If insights > 0 and publishes == 0, emit `{"decision": "block", "reason": "..."}` to force Claude to publish before the turn ends
7. Otherwise exit silently

Counting is lenient: one `publish_event` covers all insights in the turn (matches how insights are often batched into a single cross-session event).

**Input JSON fields:** `session_id`, `transcript_path`, `stop_hook_active`, `cwd`

**Output:** `{"decision": "block", "reason": "..."}` when the rule is violated. Silent otherwise.

**Exit code:** Always 0. Blocking is signaled via the JSON `decision` field, not the exit code.

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
PATH="$no_jq_dir" bash "$HOOKS_DIR/your-hook.sh"
```

Use `type -P`, not `command -v` — it bypasses shell aliases (your outer zsh may have `alias cat=bat` etc. that would break the symlink).

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
      { "type": "command", "command": "~/.claude/hooks/enforce-insight-publish.sh" }
    ] }],
    "PreCompact": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/pre-compact.sh" }] }],
    "TeammateIdle": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/teammate-idle.sh" }] }],
    "TaskCreated": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/task-created.sh" }] }],
    "TaskCompleted": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/task-completed.sh" }] }],
    "PostToolUseFailure": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/post-tool-failure.sh" }] }]
  }
}
```
