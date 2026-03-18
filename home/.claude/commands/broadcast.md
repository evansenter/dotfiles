---
argument-hint: [--to repo|session] <message>
description: Send message to other Claude Code sessions via event bus
---

# Broadcast

Send a message to other Claude Code sessions via the event bus.

## Usage

```
/broadcast <message>                  # Broadcast to all sessions (default)
/broadcast --to gemicro <message>     # Broadcast to repo:gemicro
/broadcast --to tender-bear <message> # Direct message to specific session
```

## Instructions

### 1. Parse Arguments

From `$ARGUMENTS`, extract:
- **--to <target>**: Optional repo name or session name
- **Message**: Everything after the target (or all args if no --to)

If no message provided, ask the user what to send.

### 2. Determine Channel

- **Default (no --to)**: `all` — broadcasts to every session
- **--to <name>**: Get active sessions via `mcp__agent-event-bus__list_sessions()`, then:
  1. Match `display_id` (e.g., "kind-ibis") → `session:<session-id>`
  2. Match `name` (e.g., "dotfiles/main") → `session:<session-id>`
  3. Match `repo` field (e.g., "gemicro") → `repo:<name>`
  4. No match → assume repo → `repo:<name>`

### 3. Send Message

Include your session_id (from startup: "Registered on event bus as: <session_id>") for attribution:

```
mcp__agent-event-bus__publish_event(
  event_type: "message",
  payload: "<MESSAGE>",
  session_id: "<your-session-id>",
  channel: "<determined-channel>"
)
```

### 4. Confirm

```markdown
**Sent to:** [all / repo:gemicro / session:tender-bear]
**Message:** [content]
```
