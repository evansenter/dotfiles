# Claude Code Hooks

Shell scripts that run at specific points in the Claude Code lifecycle. Configured in `settings.json` under the `hooks` key.

## Hook Lifecycle

```
Session Start
    │
    ├── SessionStart hook (session-start.sh)
    │   - Registers with event bus
    │   - Configures tmux window (disables allow-rename, sets window name)
    │   - Fetches recent events
    │
    ▼
┌─────────────────────────────────────┐
│  User sends prompt                  │
│      │                              │
│      ├── UserPromptSubmit hooks     │
│      │   - prompt-events.sh         │
│      │   - tmux-status.sh working   │
│      │                              │
│      ▼                              │
│  Claude processes...                │
│      │                              │
│      ├── Stop hook                  │
│      │   - tmux-status.sh waiting   │
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
        - Restores tmux automatic-rename
```

## Hook Details

### session-start.sh
**Trigger:** `SessionStart`

**Purpose:** Initialize session context and cross-session coordination.

**Actions:**
1. Configure tmux window (if in tmux):
   - Disable `allow-rename` to prevent Claude from overwriting window name
   - Disable `automatic-rename` to keep our custom name
   - Set window name to directory (with worktree format: `repo (branch)`)
2. Register with event bus using `event-bus-cli`
3. Fetch recent events (last 20, newest first)
4. If resuming after compaction, restore WIP checkpoint

**Input JSON fields:** `session_id`, `transcript_path`, `cwd`, `permission_mode`, `source`

**Output:** Registration confirmation and recent events in `<recent-events>` tags

---

### session-end.sh
**Trigger:** `SessionEnd`

**Purpose:** Clean up session resources.

**Actions:**
1. Restore tmux `automatic-rename` and `allow-rename` settings
2. Unregister from event bus

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

### tmux-status.sh
**Trigger:** `UserPromptSubmit` (with arg `working`), `Stop` (with arg `waiting`)

**Purpose:** Visual indicator of Claude's state in tmux window name.

**Actions:**
- `working`: Rename window to `⏳ <dir>` (hourglass indicates processing)
- `waiting`: Rename window to `<dir>` (no hourglass)

**Worktree support:** Shows `repo (branch)` format for `.worktrees/` paths.

**Input:** Consumes stdin (required) but doesn't use it. State passed as argument.

**Output:** None (tmux commands only)

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
- Should gracefully degrade if dependencies missing (jq, event-bus-cli, tmux)

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
      { "type": "command", "command": "~/.claude/hooks/tmux-status.sh working" }
    ] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/tmux-status.sh waiting" }] }],
    "PreCompact": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/pre-compact.sh" }] }]
  }
}
```
