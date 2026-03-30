# Agent Teams & Subagent Features Setup

Enable multi-agent coordination, persistent agent memory, and worktree isolation in Claude Code. These features are configured globally via dotfiles and apply to all projects.

## Prerequisites

- Claude Code v2.1.32+ (Agent Teams requirement)
- `agent-event-bus-cli` installed (for hook event publishing)
- Dotfiles repo bootstrapped (`./bootstrap.sh -f`)

## What's Included

| Feature | What it does |
|---------|-------------|
| Agent Teams | Multiple Claude instances coordinate on shared tasks |
| Agent Teams hooks | Publish task/teammate events to event bus for visibility |
| Audit agent memory | Persistent cross-session learnings for audit agents |
| Audit agent isolation | Clean repo snapshots via git worktrees |
| `.worktreeinclude` | Copy gitignored files (`.env`) into new worktrees |

## Global Setup (via dotfiles)

These are already configured if you've bootstrapped the dotfiles repo. The following files are symlinked to `~/.claude/`:

### 1. Agent Teams Flag

In `settings.json`, the env section enables the experimental feature:

```json
"env": {
  "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
}
```

### 2. Hook Scripts

Three hooks publish events to the event bus when Agent Teams events occur:

| Hook Event | Script | Event Published | Exit Code Behavior |
|------------|--------|-----------------|-------------------|
| `TeammateIdle` | `teammate-idle.sh` | `teammate_idle` | Exit 2 = keep working |
| `TaskCreated` | `task-created.sh` | `task_created` | Exit 2 = block creation |
| `TaskCompleted` | `task-completed.sh` | `task_completed` | Exit 2 = block completion |

All hooks are notification-only (always exit 0). They degrade gracefully when `jq` or `agent-event-bus-cli` is missing.

### 3. Audit Agent Frontmatter

Audit agents (`audit-codebase`, `audit-docs`, `audit-issues`, `audit-tests`, `audit-workflows`) have:

```yaml
memory: user       # Persists learnings in ~/.claude/agent-memory/<name>/
isolation: worktree # Runs in a temporary git worktree for clean snapshots
```

## Per-Repo Setup

### `.worktreeinclude`

Create this file at your repo root to copy gitignored files into worktrees:

```
.env
.env.*
```

Uses `.gitignore` syntax. Only files that match a pattern AND are gitignored get copied. Add patterns for any config files your project needs (e.g., `config/secrets.json`, `.env.local`).

This applies to worktrees created by `--worktree`, `isolation: worktree` subagents, and desktop app parallel sessions.

## Gotchas

### WorktreeCreate/WorktreeRemove hooks replace default behavior

Do **not** add `WorktreeCreate` or `WorktreeRemove` hooks for notification purposes. These hooks **replace** Claude Code's default git worktree creation/removal entirely. Your hook must:
1. Create/remove the worktree itself
2. Handle `.worktreeinclude` file copying
3. Print the worktree path to stdout (WorktreeCreate)

If you just want to observe worktree lifecycle events, use `SubagentStart`/`SubagentStop` hooks with matchers instead.

### `mcpServers` frontmatter is additive

The `mcpServers` field in agent frontmatter **adds** MCP servers — it doesn't restrict them. Subagents inherit all MCP tools from the parent by default. To restrict MCP access, use `disallowedTools` with exact tool names (wildcard support unconfirmed).

### Hook exit codes are semantic

| Exit Code | Effect |
|-----------|--------|
| 0 | Allow the action to proceed |
| 2 | Block the action, feed stderr back as feedback |
| Other | Non-blocking error. stderr shown in verbose mode only. Action proceeds |

For notification-only hooks (like ours), always exit 0. A stray `exit 2` in a `TaskCreated` hook would silently prevent all task creation.

### Agent Teams limitations

- **No session resumption with in-process teammates**: `/resume` and `/rewind` don't restore in-process teammates. The lead may try to message teammates that no longer exist — tell it to spawn new ones
- **Experimental**: Monitor for stability issues; disable with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0`
- **Sweet spot**: 3-5 teammates with 5-6 tasks each

## Testing

```bash
make test-hooks  # Includes tests for all Agent Teams hooks
```

Tests verify syntax, graceful degradation (no jq, no CLI), and happy-path integration with mock event bus.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Hooks not firing | Check `settings.json` has the hook events. Run `/hooks` in Claude Code to verify |
| Events not appearing | Verify `agent-event-bus-cli` is installed and `AGENT_EVENT_BUS_URL` is set in `~/.extra` |
| Agent memory not persisting | Check `~/.claude/agent-memory/<agent-name>/` directory exists after first run |
| Worktree isolation failing | Ensure repo has committed changes (worktrees need a clean base) |
| `.worktreeinclude` not working | Verify the file is at repo root and patterns match gitignored files |
