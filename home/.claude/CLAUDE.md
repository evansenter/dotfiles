# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) for all sessions.

## Decision-Making

- Proactively suggest improvements when you notice opportunities.
- Feel free to use git and gh directly. Ask before merging or closing PRs.

### Autonomous Decisions (no need to ask)

- Reading, creating, editing, or deleting files in the project (don't ask, just do it)
- Running tests, linters, formatters
- Creating branches, checking out, stashing
- Staging and committing changes
- Pushing to remote (as part of PR workflow)
- Fetching PR/issue information
- Creating and editing PRs
- Creating, closing, and editing issues
- Re-running flaky CI (once per failure)
- Web searches for documentation/research
- After completing implementation work: summarize changes and run `/pr local` before pushing
- **After creating or pushing to a PR: immediately run `/watch-ci <PR#>`** - CI is now running, monitor it

### Requires Discussion

- Merging PRs - unless user explicitly approves (e.g., "merge when CI passes")
- Closing PRs
- Design trade-offs with multiple valid approaches
- Disagreements with reviewer feedback on Critical/Important items

## Allowed Permissions

Configured in `~/.claude/settings.json` for autonomous operation:

**Core:** Edit, Write, Read, WebSearch, EnterPlanMode

**Git CLI:**
- `git status`, `git diff`, `git log`, `git add`, `git commit`
- `git fetch`, `git branch`, `git remote`, `git mv`, `git checkout`, `git stash`, `git worktree`
- `git push`, `git rebase`, `git pull`, `git merge`

**GitHub CLI:**
- PRs: `gh pr view/list/checks/merge/create/edit/review`
- Issues: `gh issue list/view/close/create/edit/comment`
- CI: `gh run view/list/rerun/watch`
- Other: `gh api`, `gh repo view`

**Build Tools:**
- `make`, `cargo check/build/test/clippy/fmt/run/doc/add`

**Utilities:**
- `rm`, `tmux`, `date`, `source`, `sed`

**GitHub MCP Server:**
- PRs: `get_pull_request`, `list_pull_requests`, `get_pull_request_status`, `get_pull_request_files`, `get_pull_request_comments`, `get_pull_request_reviews`, `create_pull_request`, `merge_pull_request`, `update_pull_request_branch`, `create_pull_request_review`
- Issues: `get_issue`, `list_issues`, `create_issue`, `update_issue`, `add_issue_comment`, `search_issues`
- Other: `list_commits`, `create_branch`, `get_file_contents`, `search_code`

**Event Bus MCP Server:**
- `register_session`, `unregister_session`, `list_sessions`
- `publish_event`, `get_events`
- `notify`

**When to use MCP vs gh CLI:**
- **Prefer MCP** for standard operations (faster, structured data): fetching PR/issue details, creating issues, listing items
- **Use gh CLI** when MCP doesn't support it: `gh pr checks --watch`, `gh run` commands, `gh api` for arbitrary endpoints

## Quality Gates

- Run quality gates appropriate to the project (linter, formatter, tests) before pushing.
- Significant user-facing features should include examples demonstrating usage - this ensures the codepath doesn't go stale.

## PR Workflow

### Development Flow

Use `/work <issue-number>` to start workflow-aware task execution with explicit checkpoints. This wraps the full development flow:

1. **Orient**: Run `/status-report` to see recent work, open issues, and recommendations
2. **Start work**: Run `/work <issue-number>` to create a tracked work plan with checkpoints
3. **Develop**: Make changes, run tests/linters as needed
4. **Self-review**: After completing work, summarize what was done and run `/pr local` before pushing
5. **Iterate**: Address feedback, repeat step 4 until clean
6. **Create PR**: Use `/pr create` for streamlined commit-push-PR flow
7. **Monitor CI**: Run `/watch-ci <PR#>` after PR creation or any push - track in background with notification
8. **Process feedback**: When CI passes, run `/pr remote` to handle reviewer comments
9. **Merge & cleanup**: After approval, merge PR and run `/commit-commands:clean_gone` to clean stale branches

**Tip**: Use `/work resume` to continue after context loss - picks up from current todo state.

### Pre-PR Checklist

- Check that CLAUDE.md and README.md are updated for significant changes
- Run `/pr local` to catch issues before pushing

### Handling PR Feedback

After CI passes, run `/pr remote` to fetch and process reviewer comments. Use `/pr local` for self-checks after implementing fixes (reviewers haven't seen your changes yet).

1. **Fetch comments** from the PR
2. **Categorize** feedback as Critical, Important, or Suggestion
3. **Form opinions** - assess whether each item is valid given your context on the work
4. **Present ALL items** via AskUserQuestion with your opinion included
5. **Act on user's choices**:
   - **Implement**: Fix it immediately
   - **Skip**: Note it was skipped, move on
   - **Defer**: Create a GitHub issue for later
6. **Push and re-check** - run `/pr local` to verify changes are clean

**Key principle**: You have context on the work's purpose that automated reviewers lack. Include your opinion in each question to help inform the user's decision.

## Issue Workflow

- When making an issue, check if there are relevant labels to put on the issue. Suggest new labels as needed.

## CI Handling

- **Always run `/watch-ci <PR#>` after creating or pushing to a PR** - don't wait for user to ask; CI is running, monitor it
- If CI fails due to flakiness, auto-rerun failed jobs once with `gh run rerun <run-id> --failed`
- If CI fails twice, investigate the root cause
- **CRITICAL: After CI passes, run `/pr remote` before declaring ready to merge** - automated reviewers post new comments on each CI run

## Hooks

Configured hooks (in `~/.claude/hooks/`):

- **session-start.sh** - Auto-registers session with the event bus and fetches recent events
- **session-end.sh** - Unregisters session from the event bus on exit
- **prompt-events.sh** - Fetches new event bus events on every prompt (UserPromptSubmit hook)

## Event Bus

The event bus enables cross-session coordination via the `mcp__event-bus__*` tools.

### Session Lifecycle

Sessions are auto-registered on startup via the SessionStart hook. The hook outputs instructions to register with:
- `name`: Derived from repo/branch (e.g., `dotfiles/issue-48`)
- `cwd`: Current working directory

On session end, unregister to clean up.

### Channels

Sessions auto-subscribe to 4 channels based on their attributes:

| Channel | Receives | Use Case |
|---------|----------|----------|
| `all` | Everyone everywhere | Rare - major announcements only |
| `repo:<name>` | Same repository | **Most common** - coordinate parallel work on same codebase |
| `machine:<host>` | Same machine | Cross-repo local coordination (e.g., "running heavy build") |
| `session:<id>` | One session | Direct messages, help requests |

**Channel reach:**
- `repo:` crosses machines but not repos
- `machine:` crosses repos but not machines
- `session:` and `all` cross both

**Default is `all`** when publishing - use it freely. We'll tune down noise as needed.

### Discovery

Use these tools to see who's working and find sessions to coordinate with:

```
list_sessions()  → See all active sessions with their subscribed channels
list_channels()  → See active channels and subscriber counts
```

Example: Find a session working on auth to ask a question:
```
sessions = list_sessions()
auth_session = [s for s in sessions if "auth" in s["name"]][0]
publish_event("help_needed", "How do I call the new auth endpoint?",
              channel=f"session:{auth_session['session_id']}")
```

### Automatic Event Synchronization

Events are automatically fetched at two lifecycle points:
- **Session start**: Catches up on events that occurred since last session
- **Every prompt**: Checks for new events before processing user input

This enables maximum synchronization between parallel sessions. Events are filtered to exclude `session_registered`/`session_unregistered` noise and use incremental polling via `~/.local/state/claude/last_event_id` state file.

**Performance note**: Event fetching adds ~250-300ms latency (Python CLI startup + HTTP). If this is noticeable, the hooks can be disabled in settings.json.

### Broadcasting Events

Commands broadcast events to coordinate with parallel sessions. **Broadcasts are best-effort** - if the event bus is unavailable, commands should still complete successfully; the broadcast simply won't happen.

| Command | Event Type | Channel | When |
|---------|------------|---------|------|
| `/rfc --create` | `rfc_created` | `repo:<name>` | After creating RFC |
| `/rfc` | `rfc_responded` | `repo:<name>` | After posting response |
| `/parallel-work start` | `parallel_work_started` | `repo:<name>` | After creating worktree |
| `/watch-ci` | `ci_completed` | `repo:<name>` | When CI finishes |
| `/broadcast` | `message` | varies | Manual messaging |

**Deriving repo name for channels:** Use `gh repo view --json name -q .name` or `basename $(git rev-parse --show-toplevel)`.

### Checking Events

- `/event-bus-status` - Show event bus overview with active sessions and coordination insights
- `/status-report` - Includes event bus activity in report
- `/learnings` - Query historical discoveries (gotchas, patterns, flaky tests)

### Direct Messaging

To message a specific session:
```
mcp__event-bus__publish_event(
  event_type: "message",
  payload: "Your message here",
  channel: "session:<session-id>"
)
```

Use `/broadcast --to <session-name>` for convenience.

### Event Type Conventions

Standard event types for consistency across commands:

| Event Type | Description | Example Payload |
|------------|-------------|-----------------|
| `rfc_created` | New RFC issue created | `"RFC created: #48 - Event bus integration"` |
| `rfc_responded` | Response posted to RFC | `"RFC response posted: #48"` |
| `parallel_work_started` | New worktree/session started | `"Started parallel work: issue-48 - Implement event bus"` |
| `ci_completed` | CI finished (pass or fail) | `"CI passed on PR #42"` or `"CI failed on PR #42"` |
| `message` | Generic message/announcement | `"Auth feature done, you can integrate now"` |
| `help_needed` | Request for assistance | `"Need review on auth.ts approach"` |
| `task_completed` | Significant task finished | `"Feature X is done and merged"` |
| `gotcha_discovered` | Non-obvious issue found | `"SQLite needs datetime adapters in Python 3.12+"` |
| `pattern_found` | Useful pattern discovered | `"Use (machine, client_id) as dedup key"` |
| `test_flaky` | Flaky test identified | `"test_concurrent_writes sometimes fails, safe to retry"` |
| `workaround_needed` | Temporary fix for known issue | `"Rate limit workaround: batch requests"` |
| `task_started` | Work begun on issue/task | `"Started work on #42 - Add dark mode"` |
| `feedback_addressed` | PR feedback processed | `"Addressed feedback on PR #108: 2 implemented, 1 skipped"` |
| `error_broadcast` | Repeated failures or rate limits | `"API rate limited - wait 10min"` |
| `blocker_found` | Blocking issue discovered | `"Main branch CI broken"` |

**Naming conventions:**
- Use `snake_case` for event types
- Be specific: `rfc_created` not just `created`
- Include context in payload: what happened and any relevant identifiers (PR#, issue#)
- Payloads are automatically JSON-escaped by the MCP layer - special characters are safe

### Proactive Publishing

Beyond command-triggered events, proactively publish when you discover something useful for other sessions:

| When | Event Type | Example |
|------|------------|---------|
| Find non-obvious issue | `gotcha_discovered` | `"SQLite needs datetime adapters in Python 3.12+"` |
| Discover useful pattern | `pattern_found` | `"Use (machine, client_id) as dedup key"` |
| Identify flaky test | `test_flaky` | `"test_concurrent_writes sometimes fails, safe to retry"` |
| Use temporary workaround | `workaround_needed` | `"Rate limit workaround: batch requests"` |
| Complete significant task | `task_completed` | `"Auth refactor done, safe to integrate"` |
| Hit repeated failures | `error_broadcast` | `"API rate limited - wait 10min before retrying"` |
| Discover blocking issue | `blocker_found` | `"Main branch broken - CI failing on unrelated commit"` |

**Channel choice for learnings:** Use `repo:<name>` for repo-specific discoveries, `machine:<host>` for environment issues.

**When to broadcast errors:**
- **Rate limits**: Warn others before they hit the same limit
- **Service outages**: CI, GitHub API, external services down
- **Main branch broken**: Tests failing on main, blocking all PRs
- **Repeated flaky failures**: Same test failing across sessions

**When NOT to publish:** Don't emit events for routine work or one-off errors. Reserve for discoveries that would save another session time or prevent them from hitting the same issue.

### Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| MCP tools unavailable | Event bus server not running | Check LaunchAgent: `launchctl list | grep event-bus` |
| Registration fails | Server not configured | Verify MCP config in Claude Code settings |
| Events not received | Wrong channel or not subscribed | Check session is registered; use `list_sessions` |
| Stale/zombie sessions | Previous session didn't unregister | Local sessions cleaned on PID death; remote after 7 days |

**Session cleanup:** Local sessions with dead PIDs are cleaned immediately via liveness checks. Remote sessions expire after 7 days of inactivity. The `get_events` and `publish_event` calls auto-refresh the heartbeat.

**Availability detection:** Use `list_sessions()` as a lightweight health check before relying on event bus features. If it fails, gracefully skip event-bus-dependent functionality.

**Additional documentation:** Read the MCP resource `event-bus://guide` for more patterns and best practices.

## Custom Commands

Available slash commands (in `~/.claude/commands/`):

- `/work` - Workflow-aware task execution with checkpoints (`<issue-number>`, `resume`)
- `/im-lost` - Show current workflow position and context when you've lost track
- `/status-report` - Generate repo status summary with recently completed work, open PRs/issues, and recommendations
- `/pr` - Create PRs or review feedback (`create`, `local`, `remote`)
- `/pr-followups` - Find unaddressed or deferred comments from merged PRs
- `/audit-codebase` - Check for AI-generated anti-patterns and Evergreen violations
- `/audit-tests` - Find redundant or stale tests
- `/audit-issues` - Categorize open issues as current or needing updates
- `/cross-repo` - Gather context from a related repository (CLAUDE.md, PRs, issues)
- `/improve-workflow` - Suggest workflow improvements, categorized as local (this repo) or global (dotfiles)
- `/rfc` - Create or respond to RFC-style issues (`--create` for new, issue number for response)
- `/watch-ci` - Monitor CI in background with notification when complete
- `/parallel-work` - Manage git worktrees for parallel PR development (start with tmux auto-launch, list, cleanup)
- `/event-bus-status` - Show event bus overview with active sessions and coordination insights
- `/broadcast` - Send message to other Claude Code sessions via event bus
- `/learnings` - Query historical discoveries (gotchas, patterns, flaky tests) from event bus
- `/commit-commands:commit-push-pr` - Commit, push, and create PR in one step (or use `/pr create`)
- `/commit-commands:clean_gone` - Delete local branches whose remote tracking branch is gone

## Contrib Utilities

Scripts in `~/.claude/contrib/` for workflow analysis and automation:

### parse-session-logs.sh

Analyzes Claude Code session metrics from `~/.claude/projects/**/*.jsonl` for evidence-based workflow improvements.

**Note:** Session logs are stored as `.jsonl` files in `~/.claude/projects/`. Availability may depend on Claude Code's retention policies.

**Usage:**
```bash
~/.claude/contrib/parse-session-logs.sh [OPTIONS]

OPTIONS:
  --project       Analyze current project only (default)
  --global        Analyze all projects
  --days N        Look back N days (default: 7)
  --verbose, -v   Show detailed output
```

**Output:**
- Date range and total tool calls analyzed
- Project breakdown (global scope) - shows which repos contributed
- Tool frequency (Bash, Read, Edit, MCP tools, Skills)
- Top commands (git, gh, cargo, etc.)
- Common tool sequences (workflow patterns)
- Commands needing permission (compares usage against settings.json)
- Data-driven improvement suggestions

**Example:**
```bash
# Analyze dotfiles project from last 7 days
cd ~/Documents/projects/dotfiles
~/.claude/contrib/parse-session-logs.sh --project

# Global analysis across all projects, last 30 days
~/.claude/contrib/parse-session-logs.sh --global --days 30
```

### repo-stats.sh

Shows codebase size (LoC) and recent activity across repositories using GitHub API and `scc`.

**Usage:**
```bash
~/.claude/contrib/repo-stats.sh [OPTIONS] [repo1 repo2 ...]

OPTIONS:
  --days N        Look back N days (default: 14)
  --owner NAME    GitHub owner (default: evansenter)
  --local-dir DIR Local repos directory (default: ~/Documents/projects)
```

**Output:**
- Codebase size per repo (code, comments, blanks, total lines)
- Recent activity (commits, additions, deletions, net)
- Combined language breakdown via `scc`

**Requirements:** `gh` CLI, `jq`, `scc` (optional, for accurate LoC)

**Example:**
```bash
# Default repos, last 14 days
~/.claude/contrib/repo-stats.sh

# Custom repos, last 7 days
~/.claude/contrib/repo-stats.sh --days 7 myrepo otherrepo
```
