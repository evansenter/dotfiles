# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Minimal dotfiles for zsh, git, vim, and tmux. Primarily macOS with Linux graceful degradation. Dotfiles in `home/` are symlinked to `~` on install. External themes are git submodules in `vendor/`.

## Commands

```bash
./bootstrap.sh           # Install/sync dotfiles (prompts for confirmation)
./bootstrap.sh -f        # Force install (skip confirmation)
./bootstrap.sh --pull    # Pull latest then install
./uninstall.sh           # Remove symlinks
git submodule update --init --remote  # Update theme submodules
```

## Quality Gates

```bash
make check       # Run all quality gates (lint, test, hooks)
make lint        # Run shellcheck on all .sh files
make test        # Syntax check bash/zsh scripts
make test-hooks  # Test hook graceful degradation
```

CI runs these on PRs: Lint, Test, Hooks, Bootstrap, claude-review.

## Testing Changes

To validate changes beyond CI:

1. **Shell configs** - Open a new terminal tab or `source ~/.zshrc`
2. **Tmux** - Run `tmux source ~/.tmux.conf` or restart tmux
3. **Git** - Test alias with `git <alias>`, e.g., `git st`
4. **Bootstrap** - Run `./bootstrap.sh -f` to verify idempotent symlink creation

## Architecture

### Zsh Loading Order

`.zshrc` sources files in this order:
1. `.exports` - Environment variables, PATH
2. `.zsh_prompt` - Prompt with command timer (uses `preexec`/`precmd` hooks)
3. `.aliases` - Command aliases
4. `~/.extra` - Personal customizations (not tracked)

### Bootstrap Process

The `sync_dotfiles` function in `bootstrap.sh`:
1. Symlinks all files in `home/` to `~` (idempotent - skips existing correct symlinks)
2. Symlinks `.claude/hooks/`, `.claude/commands/`, `.claude/contrib/`, and `.claude/agents/` directories
3. Installs Claude Code MCP servers (GitHub)
4. Installs tmux plugin manager (TPM) - requires manual `prefix + I` to install plugins
5. Symlinks btop themes from `vendor/btop-catppuccin/`
6. Installs LaunchAgents (macOS only)

### Key Components

**Prompt System** - `home/.zsh_prompt`
- `preexec` captures start time, `precmd` calculates elapsed time
- Timer only displayed if command takes >0 seconds

**Dark Mode Theme Switching** - `home/.bin/toggle-btop-theme`
- Switches btop theme based on macOS appearance (mocha/latte)
- Requires `dark-notify` (`brew install cormacrelf/tap/dark-notify`)
- LaunchAgent runs daemon, sends SIGUSR2 to btop instances

**Claude Code Configuration** - `home/.claude/`
- `CLAUDE.md` - Global workflow preferences (symlinked to `~/.claude/CLAUDE.md`)
- `agents/` - User-defined agents for autonomous task execution
- `commands/` - Custom slash commands (`/status-report`, `/pr-create`, `/pr-review`, `/work`, etc.)
- `contrib/` - Helper scripts and MCP server data directories
- `hooks/` - Session lifecycle hooks (event bus registration, event polling)
- `settings.json` - Allowed permissions, enabled plugins

### Command File Format

New commands in `home/.claude/commands/` should follow this structure:

```markdown
---
argument-hint: [arg1] [optional-arg]
description: Brief description for autocomplete hints
---

# Command Name

One-line description of what the command does.

## Usage

\`\`\`
/command-name <required-arg> [optional-arg]
\`\`\`

- Explain each argument
- Note defaults for optional args

## Instructions

### 1. First Step

\`\`\`bash
# Commands to run
\`\`\`

### 2. Next Step

Detailed instructions...

### N. Output

Describe expected output format.
```

**Guidelines:**
- Use `$1`, `$2` for positional args parsed in instructions
- Use `$ARGUMENTS` only for freeform context (not when parsing positional args)
- Include bash snippets for commands Claude should run
- End with output format specification

### Agent File Format

User-defined agents in `home/.claude/agents/` provide autonomous task execution with custom system prompts.

```markdown
---
name: agent-name
description: When/how to use this agent (used for automatic delegation)
tools: Read, Glob, Grep, Bash, WebFetch, WebSearch
model: sonnet
---

Your agent's system prompt goes here. Define the agent's role,
capabilities, approach, and output format.
```

**Required fields:**
- `name` - Unique identifier (lowercase, hyphens)
- `description` - Natural language for automatic delegation

**Optional fields:**
- `tools` - Comma-separated list (inherits all if omitted)
- `model` - `sonnet`, `opus`, `haiku`, or `inherit`

**Invocation (NOT via Task tool):**
User-defined agents work differently from the Task tool's built-in `subagent_type` values (`general-purpose`, `Explore`, `Plan`, etc.):

| Method | Example |
|--------|---------|
| Natural language | "Use the audit-codebase agent to review this" |
| Automatic delegation | CC delegates based on `description` field |
| `/agents` command | Interactive agent management |

**Note:** Session restart required after creating new agent files.

**iTerm2 Configuration** - `preferences/`, `vendor/iterm-catppuccin/`
- Manual import required: Preferences → Profiles → Colors → Color Presets → Import
- Enable "Use different colors for light mode and dark mode"
- Profile backup: `preferences/iTerm Profile.json`

## After Merging Changes

Run `./bootstrap.sh -f` to apply changes to the local system.

## Event Bus Integration

The event bus enables cross-session coordination via the `mcp__event-bus__*` tools.

### Channels

Sessions auto-subscribe to 4 channels based on their attributes:

| Channel | Receives | Use Case |
|---------|----------|----------|
| `all` | Everyone everywhere | Rare - major announcements only |
| `repo:<name>` | Same repository | **Most common** - coordinate parallel work on same codebase |
| `machine:<host>` | Same machine | Cross-repo local coordination (e.g., "running heavy build") |
| `session:<id>` | One session | Direct messages, help requests |

### Event Type Conventions

| Event Type | Description | Example Payload |
|------------|-------------|-----------------|
| `task_started` | Work begun on task | `"Started work on #42 - Add auth"` |
| `task_completed` | Task finished (includes PR merge) | `"Merged PR #42 - Add auth"` |
| `rfc_created` | New RFC issue created | `"RFC created: #48 - Event bus integration"` |
| `rfc_responded` | Response posted to RFC | `"RFC response posted: #48"` |
| `parallel_work_started` | New worktree/session started | `"Started parallel work: issue-48"` |
| `ci_completed` | CI finished (pass or fail) | `"CI passed on PR #42"` |
| `feedback_addressed` | PR feedback processed | `"Addressed feedback on PR #42: 3 implemented, 1 deferred"` |
| `issue_created` | Issue created (often cross-repo) | `"Created issue #15 in claude-event-bus"` |
| `message` | Generic message/announcement | `"Auth feature done, you can integrate now"` |
| `help_needed` | Request for assistance | `"Need review on auth.ts approach"` |
| `gotcha_discovered` | Non-obvious issue found | `"SQLite needs datetime adapters in Python 3.12+"` |
| `pattern_found` | Useful pattern discovered | `"Use (machine, client_id) as dedup key"` |
| `test_flaky` | Flaky test identified | `"test_concurrent_writes sometimes fails"` |
| `error_broadcast` | Rate limits or service outages | `"API rate limited - wait 10min"` |
| `blocker_found` | Blocking issue discovered | `"Main branch CI broken"` |

### Proactive Publishing

Publish discoveries that would save other sessions time:
- **gotcha_discovered** - Non-obvious issues
- **pattern_found** - Useful patterns
- **test_flaky** - Flaky tests (safe to retry)
- **error_broadcast** - Rate limits, service outages
- **blocker_found** - Main branch broken, blocking issues

### Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| MCP tools unavailable | Server not running | `launchctl list | grep event-bus` |
| Events not received | Wrong channel | Check `list_sessions()` |
| Stale sessions | Didn't unregister | Local: cleaned on heartbeat timeout; Remote: 7 day expiry |

**Additional documentation:** Read `event-bus://guide` MCP resource.

## Session Analytics

The session-analytics MCP server provides workflow insights from Claude Code session logs.

### Key Tools

| Tool | Purpose |
|------|---------|
| `get_insights` | Comprehensive analysis (tool frequency, sequences, permission gaps, trends) |
| `get_tool_frequency` | Detailed tool usage with breakdowns by command/skill/agent |
| `get_permission_gaps` | Commands that may need adding to settings.json |
| `get_handoff_context` | Recent activity summary for session continuity |
| `analyze_failures` | Error patterns and rework detection |

### Usage

Primarily used by `/improve-workflow` and `/status-report`. Direct usage:

```
mcp__session-analytics__get_insights(days=7, refresh=false)
mcp__session-analytics__get_permission_gaps(days=7, min_count=5)
```

**Data source:** Session logs in `~/.claude/projects/**/*.jsonl`.

**Additional documentation:** Read `session-analytics://guide` MCP resource.

## Contrib Utilities

Scripts in `home/.claude/contrib/` for workflow analysis:

### repo-stats.sh

Shows project stats, codebase size, and recent activity across repositories.

```bash
~/.claude/contrib/repo-stats.sh [OPTIONS] [repo1 repo2 ...]

OPTIONS:
  --days N        Look back N days (default: 14)
  --owner NAME    GitHub owner (default: evansenter)
  --local-dir DIR Local repos directory (default: ~/Documents/projects)
```

**Output:**
- Project stats (test counts, dependency counts, open issues/PRs)
- Codebase size per repo (code, comments, blanks, total lines)
- Recent activity (commits, additions, deletions, net)

**Test detection:** Rust (`#[test]`), Python (`def test_`/`class Test`), JS/TS (test/it/describe), Shell (tests/).

**Requirements:** `gh` CLI, `jq`, `scc` (optional)
