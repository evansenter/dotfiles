# Agent Teams, Worktree Hooks, and Subagent Features

**Issue:** #295
**Date:** 2026-03-30
**Status:** Approved

## Problem

Claude Code has shipped Agent Teams (experimental), worktree lifecycle hooks, and subagent configuration improvements (memory, isolation, MCP scoping). The dotfiles repo needs to integrate all three to enable multi-agent coordination, automatic worktree event bus registration, and persistent agent memory.

## Design Decisions

1. **MCP scoping:** Allowlist per agent based on actual tool usage. Agents without `mcpServers` frontmatter inherit all servers; agents with `mcpServers: []` get none.
2. **Isolation:** Only audit agents get `isolation: worktree` (they scan the full repo and benefit from clean snapshots). Other agents don't touch files.
3. **Hook implementation:** Follow existing standalone-script pattern (no shared library extraction). Each hook is self-contained with its own boilerplate.
4. **Scope:** All hooks, agents, and settings are global (symlinked from `home/.claude/` to `~/.claude/`). `.worktreeinclude` is per-repo by design.

## Changes

### 1. `.worktreeinclude` (repo root)

```
.env
.env.*
```

Copies matching gitignored files into new worktrees created by `isolation: worktree`.

### 2. Agent Frontmatter

| Agent | `memory` | `isolation` | `mcpServers` |
|-------|----------|-------------|--------------|
| audit-codebase | `user` | `worktree` | `[agent-event-bus]` |
| audit-docs | `user` | `worktree` | `[agent-event-bus]` |
| audit-issues | `user` | `worktree` | `[agent-event-bus]` |
| audit-tests | `user` | `worktree` | `[agent-event-bus]` |
| audit-workflows | `user` | `worktree` | `[agent-event-bus]` |
| improve-workflow | -- | -- | `[agent-event-bus, agent-session-analytics]` |
| rfc-create | -- | -- | `[agent-event-bus]` |
| rfc-respond | -- | -- | `[agent-event-bus]` |
| status-report | -- | -- | `[agent-event-bus, agent-session-analytics]` |
| summarize-work | -- | -- | `[]` |

### 3. `settings.json`

**env addition:**
```json
"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
```

**New hook events:**
```json
"TeammateIdle": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/teammate-idle.sh" }] }],
"TaskCreated": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/task-created.sh" }] }],
"TaskCompleted": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/task-completed.sh" }] }],
"WorktreeCreate": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/worktree-create.sh" }] }],
"WorktreeRemove": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/worktree-remove.sh" }] }]
```

### 4. Hook Scripts

All hooks follow the existing boilerplate pattern:
```bash
#!/bin/bash
set -euo pipefail
[[ -f ~/.extra ]] && source ~/.extra
INPUT=$(cat)
# graceful degradation checks for jq, agent-event-bus-cli
# URL_ARGS pattern
# hook-specific logic
# publish event
```

#### teammate-idle.sh
- **Event type:** `teammate_idle`
- **Channel:** `repo:<name>`
- **Payload:** Session ID and idle status
- **Purpose:** Signal that a teammate agent has no tasks, enabling work redistribution

#### task-created.sh
- **Event type:** `task_created`
- **Channel:** `repo:<name>`
- **Payload:** Task subject/description from stdin JSON
- **Purpose:** Broadcast task creation for cross-agent visibility

#### task-completed.sh
- **Event type:** `task_completed`
- **Channel:** `repo:<name>`
- **Payload:** Task subject/description from stdin JSON
- **Purpose:** Broadcast task completion for coordination

#### worktree-create.sh
- **Event type:** `parallel_work_started`
- **Channel:** `repo:<name>`
- **Actions:**
  1. Register worktree session with event bus (follows session-start.sh pattern)
  2. Publish `parallel_work_started` event
- **Purpose:** Auto-register any worktree with event bus for coordination

#### worktree-remove.sh
- **Event type:** `parallel_work_completed`
- **Channel:** `repo:<name>`
- **Actions:**
  1. Publish `parallel_work_completed` event
  2. Unregister worktree session from event bus (follows session-end.sh pattern)
- **Purpose:** Clean up worktree session registration

### 5. Tests

Add to `tests/test-hooks.sh`:
- Syntax check for each new hook (5 tests)
- Graceful degradation (no jq, no CLI) for each (10 tests)
- Happy path integration tests using existing mock infrastructure (5 tests)
- The mock `publish` case already handles arbitrary event types

### 6. hooks/README.md

Update lifecycle diagram to include:
- Agent Teams hooks (TeammateIdle, TaskCreated, TaskCompleted) in the prompt/processing loop
- Worktree hooks (WorktreeCreate, WorktreeRemove) as separate lifecycle events

Add individual hook detail sections for all 5 new hooks following existing format.

### 7. Porting Guide (`docs/agent-teams-setup.md`)

A standalone guide for adopting Agent Teams, worktree hooks, and subagent features in other repos. Follows the pattern of `docs/work-review-cycle.md`. Covers:

- Enabling the Agent Teams experimental flag
- Adding hook scripts (what to copy from dotfiles)
- Agent frontmatter configuration (`memory`, `isolation`, `mcpServers`)
- Creating per-repo `.worktreeinclude`
- Event bus integration for worktree coordination
- Troubleshooting (common issues, graceful degradation)

## Implementation Order

1. `.worktreeinclude` -- no dependencies
2. `memory: user` + `isolation: worktree` + `mcpServers` on agents -- frontmatter only
3. Settings.json -- env flag + hook wiring
4. Worktree hooks -- well-understood pattern from session-start/end
5. Agent Teams hooks -- experimental, same pattern
6. Tests -- after all hooks exist
7. hooks/README.md update -- after all hooks documented
8. Porting guide (`docs/agent-teams-setup.md`) -- after everything is implemented and tested

## Out of Scope

- Shared hook library extraction (separate refactoring concern)
- Per-repo `.worktreeinclude` for other repos (add as needed)
- Agent Teams orchestration strategies (iterate after flag is enabled)
