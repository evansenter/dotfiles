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
│      ├── Stop hook                  │
│      │   - zj-status.sh waiting     │
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
Session End
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
    "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/zj-status.sh waiting" }] }],
    "PreCompact": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/pre-compact.sh" }] }]
  }
}
```
