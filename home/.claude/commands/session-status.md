---
description: Show active sessions and recent events from the event bus
---

# Session Status

Show active Claude Code sessions and recent events for cross-session coordination.

## Instructions

### 1. List Active Sessions

```
mcp__event-bus__list_sessions()
```

This returns all active sessions with:
- `session_id`: Unique identifier
- `name`: Session name (usually repo/branch)
- `cwd`: Working directory
- `machine`: Machine identifier
- `repo`: Repository name
- `last_heartbeat`: Last activity timestamp

### 2. Fetch Recent Events

```
mcp__event-bus__get_events(since_id=0, limit=20)
```

This returns recent events with:
- `event_type`: Type of event (e.g., `rfc_created`, `ci_completed`)
- `payload`: Event message
- `channel`: Target channel
- `created_at`: Timestamp
- `session_id`: Originating session

### 3. Output Format

```markdown
## Event Bus Status

### Active Sessions (N total)

| Session | Branch | Machine | Last Activity |
|---------|--------|---------|---------------|
| dotfiles/issue-48 | issue-48 | macbook | 2 min ago |
| gemicro/main | main | macbook | 15 min ago |

**This session:** [session_id] (or "Not registered - run session-start hook")

### Recent Events

| Time | Type | Message | From |
|------|------|---------|------|
| 5 min ago | ci_completed | CI passed on PR #42 | dotfiles/main |
| 10 min ago | parallel_work_started | Started work on issue-48 | dotfiles/main |
| 30 min ago | rfc_created | RFC created: #48 - Event bus integration | dotfiles/main |

### Quick Actions

- **Send message:** Use `mcp__event-bus__publish_event` to broadcast
- **Direct message:** Use `channel: "session:<id>"` to message specific session
- **Repo broadcast:** Use `channel: "repo:<name>"` for repo-wide announcements
```

If no sessions are registered:

```markdown
## Event Bus Status

No active sessions found.

The event bus may not be running, or no sessions have registered yet.

### Troubleshooting

1. Check if the event-bus MCP server is configured in settings
2. New sessions should auto-register via the SessionStart hook
3. Manually register with: `mcp__event-bus__register_session(name="...", cwd="...")`
```

### 4. Suggestions

Based on the current state, suggest relevant actions:

- If working alone: "You're the only active session"
- If multiple sessions in same repo: "N sessions working on [repo] - consider coordinating"
- If recent `help_needed` events: "Session X requested help N minutes ago"
