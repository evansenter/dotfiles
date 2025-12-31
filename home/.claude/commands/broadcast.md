---
argument-hint: <message> [--to session-name]
description: Send message to other Claude Code sessions via event bus
---

# Broadcast

Send a message to other Claude Code sessions via the event bus.

## Usage

```
/broadcast <message>                    # Broadcast to all sessions in same repo
/broadcast <message> --to <session>     # Direct message to specific session
/broadcast <message> --all              # Broadcast to all sessions everywhere
```

## Instructions

### 1. Parse Arguments

From `$ARGUMENTS`, extract:
- **Message**: The text to send (everything except flags)
- **Target**: `--to <session-name>` for direct message, `--all` for global broadcast, or neither for repo-scoped

If no message provided, ask the user what to send.

### 2. Determine Channel

- **Default (no flags)**: `repo:<current-repo-name>` — broadcasts to all sessions in same repo
- **--to <session>**: `session:<session-id>` — direct message to specific session
- **--all**: `all` — broadcasts to every session everywhere

To get repo name:
```bash
gh repo view --json name -q .name 2>/dev/null || basename "$(git rev-parse --show-toplevel)"
```

If `--to` is specified, look up the session ID with `mcp__event-bus__list_sessions()` and find a matching session name (partial match OK).

### 3. Send Message

```
mcp__event-bus__publish_event(
  event_type: "message",
  payload: "<MESSAGE>",
  channel: "<determined-channel>"
)
```

### 4. Confirm

Output confirmation:

```markdown
## Message Sent

**To:** [channel description - "all sessions in dotfiles" / "session dotfiles/issue-48" / "all sessions"]
**Message:** [message content]

Recipients will see this in their event stream. They can check with `/session-status`.
```

### 5. Common Use Cases

- **Announce completion:** `/broadcast "Auth feature done and merged, you can integrate now"`
- **Request help:** `/broadcast "Need review on auth.ts approach" --to dotfiles/main`
- **Coordinate:** `/broadcast "Starting DB migration, wait before testing"`
- **Status update:** `/broadcast "PR #42 approved, merging soon"`
