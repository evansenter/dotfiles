---
description: Show event bus overview with active sessions, recent activity, and coordination insights
---

# Event Bus Status

Comprehensive overseer view of cross-session coordination via the event bus.

## Usage

```
/event-bus-status
```

No arguments required. Shows current session state and recent activity.

## Instructions

### 1. Get Current Session Info

Note your own session ID from the initial registration or check with:
```
mcp__event-bus__list_sessions()
```

### 2. List Active Sessions and Channels

```
mcp__event-bus__list_sessions()
mcp__event-bus__list_channels()
```

`list_sessions()` returns all active sessions with:
- `session_id`: Unique identifier (e.g., "tender-bear")
- `name`: Session name (usually repo/branch, e.g., "dotfiles/issue-48")
- `cwd`: Working directory
- `machine`: Machine identifier
- `repo`: Repository name
- `last_heartbeat`: Last activity timestamp

`list_channels()` returns active channels with:
- `channel`: Channel name (e.g., "all", "repo:dotfiles", "machine:laptop")
- `subscribers`: Number of sessions subscribed

### 3. Fetch Recent Events

```
mcp__event-bus__get_events(limit=50)
```

Events are returned newest-first by default, which is ideal for showing recent activity.

This returns recent events with:
- `event_type`: Type of event (e.g., `rfc_created`, `ci_completed`)
- `payload`: Event message
- `channel`: Target channel
- `created_at`: Timestamp
- `session_id`: Originating session

### 4. Build the Output

#### Group Sessions by Repo

Parse the session list and group by the `repo` field. For each repo, show:
- Total session count
- Table of sessions with: session_id, branch (from name), activity status

#### Detect Stale Sessions

Calculate time since `last_heartbeat`:
- **Active**: < 30 minutes
- **Idle**: 30 min - 2 hours
- **Stale**: > 2 hours (flag with warning)

#### Summarize Recent Activity

Group events by type and count:
- PRs merged (`pr_merged`)
- CI results (`ci_completed` - separate pass/fail)
- RFCs created (`rfc_created`)
- Work started (`parallel_work_started`)
- Messages (`message`)
- Help requests (`help_needed`)

#### Generate Coordination Insights

Check for:
- **Stale sessions**: Any session inactive > 2 hours
- **Related work**: Multiple sessions in same repo
- **Pending help**: Any `help_needed` events without response
- **Unread DMs**: Direct messages to sessions (check `session:*` channels)

### 5. Output Format

```markdown
## Event Bus Overview

### Active Sessions (N total, M repos)

**<repo-name>** (X sessions)
| Session | Branch | Activity |
|---------|--------|----------|
| tender-bear (you) | main | just now |
| crisp-falcon | issue-29 | 2h ago (stale?) |

**<another-repo>** (Y sessions)
| Session | Branch | Activity |
|---------|--------|----------|
| polite-heron | issue-93 | 15 min ago |

### Active Channels

| Channel | Subscribers |
|---------|-------------|
| all | 3 |
| repo:dotfiles | 2 |
| repo:gemicro | 1 |
| machine:laptop | 2 |

### Recent Activity (last hour)

| Time | Event | Details |
|------|-------|---------|
| 5 min ago | PR merged | #32 in claude-event-bus |
| 10 min ago | CI passed | PR #172 in gemicro |
| 15 min ago | RFC created | #33 - New event types |

**Summary:** N PRs merged, M CI runs (P passed, F failed), K RFCs created

### Coordination Insights

- ⚠️ **Stale session detected:** crisp-falcon hasn't had activity in 2h (orphaned worktree?)
- 🔗 **Related work:** 3 sessions active in gemicro - may benefit from coordination
- 📬 **Unread DMs:** 1 message waiting for polite-moose
- 🆘 **Help requested:** session-x asked for help N min ago

### Quick Actions

- `/broadcast "message"` - Send to all sessions
- `/broadcast --to session-name "message"` - Direct message
- `/learnings` - View discovered gotchas and patterns
```

If no sessions are registered:

```markdown
## Event Bus Overview

No active sessions found.

The event bus may not be running, or no sessions have registered yet.

### Troubleshooting

1. Check if the event-bus MCP server is configured in settings
2. New sessions should auto-register via the SessionStart hook
3. Manually register with: `mcp__event-bus__register_session(name="...", cwd="...")`
```

### 6. Time Formatting

Use human-readable relative times:
- `just now` - < 1 minute
- `N min ago` - 1-59 minutes
- `Nh ago` - 1-23 hours
- `Nd ago` - 1+ days

For the "last hour" event filter, check `created_at` timestamps.
