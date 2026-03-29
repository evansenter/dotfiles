# Agent Teams, Worktree Hooks, and Subagent Features

**Issue:** #295
**Date:** 2026-03-30
**Status:** Approved (revised after doc verification)

## Problem

Claude Code has shipped Agent Teams (experimental), worktree lifecycle hooks, and subagent configuration improvements (memory, isolation, MCP scoping). The dotfiles repo needs to integrate these to enable multi-agent coordination and persistent agent memory.

## Design Decisions

1. **MCP scoping:** `mcpServers` frontmatter is **additive** (adds servers), not restrictive. To deny MCP access, use `disallowedTools`. Only `summarize-work` needs restriction (it has no MCP usage).
2. **Isolation:** Only audit agents get `isolation: worktree` (they scan the full repo and benefit from clean snapshots). Other agents don't touch files.
3. **No worktree hooks:** `WorktreeCreate`/`WorktreeRemove` hooks **replace** default git behavior entirely — the hook must create/remove the worktree itself, handle `.worktreeinclude` copying, and return the path. The risk of breaking all worktree creation outweighs the benefit of event bus notifications. Dropped from scope.
4. **Hook implementation:** Follow existing standalone-script pattern. Each hook is self-contained with its own boilerplate.
5. **Scope:** All hooks, agents, and settings are global (symlinked from `home/.claude/` to `~/.claude/`). `.worktreeinclude` is per-repo by design.

## Verified Against Official Docs

- [Hooks reference](https://code.claude.com/docs/en/hooks) — confirmed all hook events exist, confirmed WorktreeCreate/WorktreeRemove replace default behavior
- [Subagents docs](https://code.claude.com/docs/en/sub-agents) — confirmed `memory`, `isolation`, `mcpServers` fields; confirmed mcpServers is additive
- [Common workflows](https://code.claude.com/docs/en/common-workflows) — confirmed `.worktreeinclude` format and behavior

### Key Gotchas Discovered

1. **WorktreeCreate/WorktreeRemove hooks replace default git behavior.** Your hook is responsible for the entire operation. When configured, `.worktreeinclude` is not processed — you must copy files in your hook.
2. **`mcpServers` is additive.** It gives a subagent access to servers NOT in the main conversation. It does not restrict inherited servers. Use `disallowedTools` to restrict.
3. **TaskCreated exit code 2 prevents task creation.** This is a gating hook, not just a notification hook. Our hook must exit 0 to avoid blocking task creation.
4. **TeammateIdle exit code 2 keeps teammate working.** Same pattern — exit 0 for notification-only.
5. **TaskCompleted exit code 2 prevents task completion.** Same pattern — exit 0 for notification-only.

## Changes

### 1. `.worktreeinclude` (repo root)

```
.env
.env.*
```

Copies matching gitignored files into new worktrees created by `isolation: worktree`.

### 2. Agent Frontmatter

| Agent | `memory` | `isolation` | `disallowedTools` |
|-------|----------|-------------|--------------------|
| audit-codebase | `user` | `worktree` | -- |
| audit-docs | `user` | `worktree` | -- |
| audit-issues | `user` | `worktree` | -- |
| audit-tests | `user` | `worktree` | -- |
| audit-workflows | `user` | `worktree` | -- |
| summarize-work | -- | -- | all `mcp__*` tools |

Other agents (`improve-workflow`, `rfc-create`, `rfc-respond`, `status-report`) keep defaults — they actively use MCP tools and don't need isolation or memory.

### 3. `settings.json`

**env addition:**
```json
"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
```

**New hook events (3, not 5 — worktree hooks dropped):**
```json
"TeammateIdle": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/teammate-idle.sh" }] }],
"TaskCreated": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/task-created.sh" }] }],
"TaskCompleted": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/task-completed.sh" }] }]
```

### 4. Hook Scripts

All hooks follow the existing boilerplate pattern. **Critical:** all must exit 0 — exit code 2 blocks the action (prevents task creation/completion, keeps teammate working).

```bash
#!/bin/bash
set -euo pipefail
[[ -f ~/.extra ]] && source ~/.extra
INPUT=$(cat)
# graceful degradation checks for jq, agent-event-bus-cli
# URL_ARGS pattern
# hook-specific logic
# publish event (|| true to ensure exit 0)
```

#### teammate-idle.sh
- **Event type:** `teammate_idle`
- **Channel:** `repo:<name>`
- **Input fields:** `session_id`, `teammate_name`, `team_name`
- **Payload:** Teammate name and team context
- **Purpose:** Signal that a teammate agent has no tasks, enabling coordination visibility

#### task-created.sh
- **Event type:** `task_created`
- **Channel:** `repo:<name>`
- **Input fields:** `session_id`, `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`
- **Payload:** Task subject and description
- **Purpose:** Broadcast task creation for cross-agent visibility

#### task-completed.sh
- **Event type:** `task_completed`
- **Channel:** `repo:<name>`
- **Input fields:** `session_id`, `task_id`, `task_subject`, `task_description`, `teammate_name`, `team_name`
- **Payload:** Task subject
- **Purpose:** Broadcast task completion for coordination

### 5. Tests

Add to `tests/test-hooks.sh`:
- Syntax check for each new hook (3 tests)
- Graceful degradation (no jq, no CLI) for each (6 tests)
- Happy path integration tests using existing mock infrastructure (3 tests)
- **Verify exit code is always 0** — critical to avoid blocking task operations
- The mock `publish` case already handles arbitrary event types

### 6. hooks/README.md

Update lifecycle diagram to include:
- Agent Teams hooks (TeammateIdle, TaskCreated, TaskCompleted) in the prompt/processing loop

Add individual hook detail sections for all 3 new hooks following existing format.

### 7. Porting Guide (`docs/agent-teams-setup.md`)

A standalone guide for adopting Agent Teams and subagent features in other repos. Follows the pattern of `docs/work-review-cycle.md`. Covers:

- Enabling the Agent Teams experimental flag
- Adding hook scripts (what to copy from dotfiles)
- Agent frontmatter configuration (`memory`, `isolation`, `disallowedTools`)
- Creating per-repo `.worktreeinclude`
- Gotchas: WorktreeCreate replaces default behavior, mcpServers is additive, exit codes matter
- Troubleshooting (common issues, graceful degradation)

## Implementation Order

1. `.worktreeinclude` -- no dependencies
2. `memory: user` + `isolation: worktree` + `disallowedTools` on agents -- frontmatter only
3. Settings.json -- env flag + hook wiring
4. Agent Teams hooks (3 scripts) -- notification-only, must exit 0
5. Tests -- after all hooks exist
6. hooks/README.md update -- after all hooks documented
7. Porting guide (`docs/agent-teams-setup.md`) -- after everything is implemented and tested

## Out of Scope

- **WorktreeCreate/WorktreeRemove hooks** — replace default behavior, too risky for notification-only use case
- Shared hook library extraction (separate refactoring concern)
- Per-repo `.worktreeinclude` for other repos (add as needed)
- Agent Teams orchestration strategies (iterate after flag is enabled)
- Broad MCP scoping (only summarize-work needs restriction)
