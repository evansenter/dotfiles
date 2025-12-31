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

## Hooks

Configured hooks (in `~/.claude/hooks/`):

- **notify.sh** - Cross-platform notifications (macOS: osascript, Linux: notify-send)
- **session-start.sh** - Auto-registers session with the event bus on startup
- **session-end.sh** - Unregisters session from the event bus on exit

## Event Bus

The event bus enables cross-session coordination via the `mcp__event-bus__*` tools.

### Session Lifecycle

Sessions are auto-registered on startup via the SessionStart hook. The hook outputs instructions to register with:
- `name`: Derived from repo/branch (e.g., `dotfiles/issue-48`)
- `cwd`: Current working directory

On session end, unregister to clean up.

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

- `/session-status` - Show active sessions and recent events
- `/status-report` - Includes event bus activity in report

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

**Naming conventions:**
- Use `snake_case` for event types
- Be specific: `rfc_created` not just `created`
- Include context in payload: what happened and any relevant identifiers (PR#, issue#)
- Payloads are automatically JSON-escaped by the MCP layer - special characters are safe

### Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| MCP tools unavailable | Event bus server not running | Check LaunchAgent: `launchctl list | grep event-bus` |
| Registration fails | Server not configured | Verify MCP config in Claude Code settings |
| Events not received | Wrong channel or not subscribed | Check session is registered; use `list_sessions` |
| Stale/zombie sessions | Previous session didn't unregister | Auto-expire after 5 min; use `list_sessions` to check |

**Manual cleanup:** Sessions auto-expire 5 minutes after last heartbeat. The `get_events` call refreshes the heartbeat. To see stale sessions, run `list_sessions` - expired ones won't appear.

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
- `/rfc` - Create or respond to RFC-style issues (`--create "Title"` for new, issue number for response)
- `/watch-ci` - Monitor CI in background with notification when complete
- `/parallel-work` - Manage git worktrees for parallel PR development (start with tmux auto-launch, list, cleanup)
- `/session-status` - Show active sessions and recent events from the event bus
- `/broadcast` - Send message to other Claude Code sessions via event bus
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
