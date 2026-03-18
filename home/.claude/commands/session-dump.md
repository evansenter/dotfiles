---
description: Dump recent conversation to file (avoids context pollution after compaction)
---

# Session Dump

Export recent conversation to a temporary file for reference without bloating context.

## Arguments

- `$ARGUMENTS` - Optional: number of messages (default: 50), "all" for full session, or "cross" for cross-session view

## Instructions

### 1. Parse Arguments

```
limit = parse $ARGUMENTS:
  - empty or not provided → 50
  - "all" → 500
  - "cross" → 50 (but skip session filtering)
  - number → that number

cross_session = ($ARGUMENTS == "cross")
```

### 2. Get Current Session ID

Skip this step if `cross_session` is true.

```
sessions = mcp__agent-event-bus__list_sessions()
current_session = find session where cwd matches current working directory
session_id = current_session.session_id
```

### 3. Get Messages

```
mcp__agent-session-analytics__get_session_messages(
  days=1,
  limit=<parsed limit>,
  session_id=<session_id or null if cross_session>
)
```

If no messages found, try `ingest_logs(days=1, force=true)` first, then retry.

### 4. Format Output

The API returns messages with `type` field ("user" or "assistant") and `message` content.

Write to `/tmp/session-dump-{timestamp}.md`:

```markdown
# Session Dump

**Generated:** {timestamp}
**Messages:** {count} ({user_count} user, {assistant_count} assistant)
**Session:** {session_id or "cross-session"}

---

## Conversation

### User (HH:MM)
{message content}

### Assistant (HH:MM)
{message content}

...
```

Format each message based on its `type` field. Capitalize the type for headers.

### 5. Open File

```bash
${EDITOR:-less} /tmp/session-dump-{timestamp}.md
```

### 6. Minimal Response

Return ONLY:

```
Wrote {N} messages to /tmp/session-dump-{timestamp}.md (opened in {editor})
```

Do NOT echo any message content to the conversation. The entire point is to avoid context pollution.
