---
name: hook-authoring
description: |
  Writing and modifying Claude Code hooks. Auto-applies when editing files in
  hooks/, creating new hooks, debugging hook behavior, or discussing hook
  lifecycle events (PreToolUse, PostToolUse, Stop, etc.). Also use when
  modifying settings.json hook configuration or troubleshooting hooks that
  aren't firing or are producing errors.
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
---

# Hook Authoring Patterns

This skill auto-applies when you're working with Claude Code hooks. Follow these patterns for consistent, reliable hooks.

## Hook Lifecycle

```
Session Start
    │
    ├── SessionStart hook
    │
    ▼
┌─────────────────────────────────────┐
│  User sends prompt                  │
│      │                              │
│      ├── UserPromptSubmit hooks     │
│      ▼                              │
│  Claude processes...                │
│      │                              │
│      ├── TaskCreated / TaskCompleted│
│      ├── PostToolUseFailure         │
│      ├── Notification               │
│      │                              │
│      ├── Stop hooks (in order)      │
│      ▼                              │
│  (repeat)                           │
└─────────────────────────────────────┘
    │
    ├── PreCompact hook
    │
    ▼
Session End / Agent Teams
    │
    ├── TeammateIdle hook
    └── SessionEnd hook
```

The authoritative per-hook lifecycle for THIS repo (which script runs on which trigger, in what order) is `home/.claude/hooks/README.md` — keep that as the source of truth and update it when adding hooks.

## Required Patterns

### 1. Script Header

Always start with:

```bash
#!/bin/bash
set -euo pipefail
```

### 2. Consume stdin

**Critical:** All hooks MUST consume stdin to avoid broken pipe errors:

```bash
# Read stdin (required even if not used)
input=$(cat)

# Or if you need the JSON:
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')
```

### 3. Graceful Degradation

Hooks should work even when dependencies are missing:

```bash
# Check for jq
if ! command -v jq &>/dev/null; then
    exit 0  # Silent exit, don't break Claude
fi

# Check for agent-event-bus-cli
if ! command -v agent-event-bus-cli &>/dev/null; then
    cli_path="$HOME/.local/bin/agent-event-bus-cli"
    [[ -x "$cli_path" ]] || exit 0
fi

# Check for zellij
if [[ -z "${ZELLIJ:-}" ]]; then
    exit 0  # Not in zellij, skip zellij operations
fi
```

### 4. Exit Codes

- `exit 0` - Success (normal completion)
- Non-zero exits don't block Claude but may show error messages
- Prefer silent `exit 0` for graceful degradation

## Input JSON Format

All hooks receive JSON on stdin:

```json
{
  "session_id": "uuid",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory"
}
```

Additional fields by trigger:
- **SessionStart:** `permission_mode`, `source` ("startup", "resume", "clear", or "compact")
- **SessionEnd:** `permission_mode`, `reason`
- **PreCompact:** `trigger`
- **Stop:** `stop_hook_active` (true when re-entered after a prior block — exit early to avoid loops)
- **TeammateIdle:** `permission_mode`, `teammate_name`, `team_name`
- **TaskCreated / TaskCompleted:** `permission_mode`, `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name` (teammate fields empty outside Agent Teams)
- **PostToolUseFailure:** `tool_name`, `tool_input`, `error`, `is_interrupt`
- **Notification:** `message`, `notification_type` (type set for background-agent events only)

## Output Patterns

### Structured Data

Use XML tags for data Claude should parse:

```bash
echo "<recent-events>"
echo "$events"
echo "</recent-events>"
```

### Status Messages

Simple text output works:

```bash
echo "Hook completed successfully"
```

### Silent Hooks

For hooks that only have side effects (like zjstatus notifications):

```bash
# No output needed - zellij pipe is the action
zellij pipe "zjstatus::notify::message" 2>/dev/null || true
```

## Zellij Integration

When interacting with zellij:

```bash
# Check if in zellij first
[[ -z "${ZELLIJ:-}" ]] && exit 0

# Rename tab
zellij action rename-tab "$tab_name" 2>/dev/null || true

# Send zjstatus notification (appears in statusbar)
zellij pipe "zjstatus::notify::message" 2>/dev/null || true

# Clear zjstatus notification
zellij pipe "zjstatus::notify::" 2>/dev/null || true
```

For worktree paths, show `repo (branch)` format:

```bash
if [[ "$cwd" == */.worktrees/* ]]; then
    repo=$(basename "$(dirname "$(dirname "$cwd")")")
    branch=$(basename "$cwd")
    tab_name="$repo ($branch)"
fi
```

## Event Bus Integration

For hooks that interact with the event bus:

```bash
# Find CLI
if command -v agent-event-bus-cli &>/dev/null; then
    cli="agent-event-bus-cli"
elif [[ -x "$HOME/.local/bin/agent-event-bus-cli" ]]; then
    cli="$HOME/.local/bin/agent-event-bus-cli"
else
    exit 0
fi

# Register session
"$cli" register --name "$session_name" --client-id "$session_id"

# Publish events
"$cli" publish --type "event_type" --payload "message" --session-id "$session_id"

# Get events with resume (incremental)
"$cli" events --resume --session-id "$session_id"
```

## Testing

Run `make test-hooks` to test all hooks. Tests verify:
- Script syntax is valid
- Scripts are executable
- Graceful degradation works (missing deps don't crash)

Add new test cases in `tests/test-hooks.sh`.

**Fixture realism.** When writing a regex or string match against transcript content, sample one real `~/.claude/projects/*/<id>.jsonl` message and paste the literal bytes (or `jq -r` output) into the fixture. Don't hand-write the expected format from a mental model — Claude's output styles include details like backtick-wrapped decorators that are easy to miss until production. See `home/.claude/hooks/enforce-insight-publish.sh` and its inline regex comment for the empirical case study: the matcher shipped without backtick support, hook never fired in production until rediscovered via deliberate-violation test.

## Configuration

Register hooks in `settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/your-hook.sh" }] }]
  }
}
```

Triggers used in this repo:
- `SessionStart` - Session begins
- `SessionEnd` - Session ends
- `UserPromptSubmit` - User sends message
- `Stop` - Claude finishes response (can block via `{"decision": "block"}`)
- `PreCompact` - Before context summarization
- `PostToolUseFailure` - A tool call failed
- `TaskCreated` / `TaskCompleted` - Task lifecycle (TaskCreate tool; also Agent Teams)
- `TeammateIdle` - Teammate agent has no work (Agent Teams)
- `Notification` - Claude Code sends a notification (permission prompts, idle waits, background-agent events)

Claude Code has more (PreToolUse, PostToolUse, PostCompact, StopFailure, MessageDisplay, CwdChanged, FileChanged, PermissionRequest/PermissionDenied, Elicitation…) — check current docs before assuming a trigger doesn't exist.

## Reference

See existing hooks in `home/.claude/hooks/` for examples:
- `session-start.sh` - Event bus registration, zellij tab rename
- `session-end.sh` - Cleanup
- `prompt-events.sh` - Incremental event polling
- `zj-status.sh` - Visual state indicator (zjstatus notification)
- `pre-compact.sh` - WIP checkpointing
- `notification.sh` - Notification → zjstatus bridge with icon mapping
- `post-tool-failure.sh` - Recurring-error detection, feedback via `hookSpecificOutput.additionalContext`
- `task-created.sh` / `task-completed.sh` - Task event broadcasting to event bus
- `teammate-idle.sh` - Agent Teams idle broadcasting
- `enforce-insight-publish.sh` - Stop-hook transcript inspection with quiescence detection; blocks via JSON `decision` field
