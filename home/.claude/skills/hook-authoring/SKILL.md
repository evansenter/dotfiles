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
┌─────────────────────────────────┐
│  User sends prompt              │
│      │                          │
│      ├── UserPromptSubmit hooks │
│      ▼                          │
│  Claude processes...            │
│      │                          │
│      ├── Stop hook              │
│      ▼                          │
│  (repeat)                       │
└─────────────────────────────────┘
    │
    ├── PreCompact hook
    │
    ▼
Session End
    │
    └── SessionEnd hook
```

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
- **SessionStart:** `permission_mode`, `source` ("user" or "resume")
- **SessionEnd:** `permission_mode`, `reason`
- **PreCompact:** `trigger`

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

## Configuration

Register hooks in `settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/your-hook.sh" }] }]
  }
}
```

Available triggers:
- `SessionStart` - Session begins
- `SessionEnd` - Session ends
- `UserPromptSubmit` - User sends message
- `Stop` - Claude finishes response
- `PreCompact` - Before context summarization

## Reference

See existing hooks in `home/.claude/hooks/` for examples:
- `session-start.sh` - Event bus registration, zellij tab rename
- `session-end.sh` - Cleanup
- `prompt-events.sh` - Incremental event polling
- `zj-status.sh` - Visual state indicator (zjstatus notification)
- `pre-compact.sh` - WIP checkpointing
