---
description: Show event bus overview with action items, cleanup needs, and active work
---

# Event Bus Status

Action-oriented overview of cross-session coordination.

## Instructions

### 1. Gather Data

```
mcp__agent-event-bus__list_sessions()
mcp__agent-event-bus__get_events(limit=50)
```

### 2. Identify Action Items

From events, find:
- **Help requests** (`help_needed`) not yet addressed
- **Unread DMs** (`message` events to `session:<your-id>`)
- **Improvement suggestions** (`improvement_suggested`) worth considering

### 3. Identify Cleanup Needed

From sessions, find stale ones (> 2 hours since last heartbeat):
- Extract likely worktree path from `cwd`
- Suggest cleanup command: `git -C <repo-path> worktree prune`

### 4. Summarize Active Work

Group non-stale sessions by repo. Show who's working on what.

### 5. Output Format

```markdown
## Event Bus Status

### Your Session
<display_id> (<name>) - active <time>

### Action Items
- 🆘 <session> asked for help <time> ago: "<payload>"
- 📬 <N> unread DM(s) from <session>
- 💡 Improvement suggested: "<payload>"

*Or: "No action items"*

### Cleanup Needed
| Session | Repo | Stale Since | Worktree |
|---------|------|-------------|----------|
| <display_id> | <repo> | <time> | <path> |

**To clean:** `git -C <repo-path> worktree prune`

*Or: "No stale sessions"*

### Active Work
| Repo | Sessions | Working On |
|------|----------|------------|
| gemicro | kind-ibis | docs/llm-first-design |
| dotfiles | epic-ibis (you) | main |
```

If no sessions registered, explain event bus may not be running.
