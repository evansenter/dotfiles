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

Extract the message and optional target:

```bash
MESSAGE="$ARGUMENTS"
TARGET=""

# Check for --to flag
if [[ "$ARGUMENTS" =~ --to[[:space:]]+([^[:space:]]+) ]]; then
  TARGET="${BASH_REMATCH[1]}"
  MESSAGE="${ARGUMENTS%%--to*}"
fi

# Check for --all flag
if [[ "$ARGUMENTS" =~ --all ]]; then
  TARGET="all"
  MESSAGE="${ARGUMENTS%%--all*}"
fi

# Trim whitespace from message
MESSAGE=$(echo "$MESSAGE" | xargs)
```

If `MESSAGE` is empty, prompt for it:

```json
{
  "questions": [
    {
      "question": "What message do you want to send?",
      "header": "Message",
      "options": [
        {"label": "Type message", "description": "I'll enter the message"}
      ],
      "multiSelect": false
    }
  ]
}
```

### 2. Determine Channel

- **Default (no flags):** `repo:<current-repo-name>` - broadcasts to all sessions in the same repo
- **--to <session>:** `session:<session-id>` - direct message to specific session
- **--all:** `all` - broadcasts to every session everywhere

If `--to` is specified, look up the session ID:

```
mcp__event-bus__list_sessions()
```

Find the session matching the provided name (partial match is OK).

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
