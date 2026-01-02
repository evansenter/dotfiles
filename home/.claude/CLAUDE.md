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
- After completing implementation work: summarize changes and run `/pr-review local` before pushing
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
- `rm`, `tmux`, `date`, `source`, `sed`, `mkdir`
- `ls`, `cat`, `head`, `tail`, `wc`, `chmod`
- `uv`, `sqlite3`, `launchctl`, `claude`

**Python:**
- `python3`, `pip`, `pip3`, `pytest`, `ruff`
- `.venv/bin/*` variants for virtual environments

**CLI Tools:**
- `event-bus-cli`, `session-analytics-cli` (and their venv/local paths)
- `~/.claude/contrib/*` - contrib utility scripts

**GitHub MCP Server:**
- PRs: `get_pull_request`, `list_pull_requests`, `get_pull_request_status`, `get_pull_request_files`, `get_pull_request_comments`, `get_pull_request_reviews`, `create_pull_request`, `merge_pull_request`, `update_pull_request_branch`, `create_pull_request_review`
- Issues: `get_issue`, `list_issues`, `create_issue`, `update_issue`, `add_issue_comment`, `search_issues`
- Other: `list_commits`, `create_branch`, `get_file_contents`, `search_code`

**Event Bus MCP Server:**
- `register_session`, `unregister_session`, `list_sessions`
- `publish_event`, `get_events`
- `notify`

**Session Analytics MCP Server:**
- `get_insights`, `get_tool_frequency`, `get_permission_gaps`
- `get_session_events`, `get_session_signals`, `get_handoff_context`
- `analyze_trends`, `analyze_failures`, `classify_sessions`

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
4. **Self-review**: After completing work, summarize what was done and run `/pr-review local` before pushing
5. **Iterate**: Address feedback, repeat step 4 until clean
6. **Create PR**: Use `/pr-create` for streamlined commit-push-PR flow
7. **Monitor CI**: Run `/watch-ci <PR#>` after PR creation or any push - track in background with notification
8. **Process feedback**: When CI passes, run `/pr-review remote` to handle reviewer comments
9. **Merge & cleanup**: After approval, merge PR and run `/commit-commands:clean_gone` to clean stale branches
10. **Reflect**: `/work` automatically runs `/improve-workflow` after merge to surface friction and infrastructure gaps

**Tip**: Use `/im-lost` to see your current workflow position if you lose context. Active `/work` sessions track progress via `[work:N]` todos. Use `/work --attach` to join an existing PR and pick up from the current checkpoint.

### Pre-PR Checklist

- Check that CLAUDE.md and README.md are updated for significant changes
- Run `/pr-review local` to catch issues before pushing

### Handling PR Feedback

After CI passes, run `/pr-review remote` to fetch and process reviewer comments. Use `/pr-review local` for self-checks after implementing fixes (reviewers haven't seen your changes yet).

1. **Fetch comments** from the PR
2. **Categorize** feedback as Critical, Important, or Suggestion
3. **Form opinions** - assess whether each item is valid given your context on the work
4. **Present ALL items** via AskUserQuestion with your opinion included
5. **Act on user's choices**:
   - **Implement**: Fix it immediately
   - **Skip**: Note it was skipped, move on
   - **Defer**: Create a GitHub issue for later
6. **Push and re-check** - run `/pr-review local` to verify changes are clean

**Key principle**: You have context on the work's purpose that automated reviewers lack. Include your opinion in each question to help inform the user's decision.

## Issue Workflow

- When making an issue, check if there are relevant labels to put on the issue. Suggest new labels as needed.

## CI Handling

- **Always run `/watch-ci <PR#>` after creating or pushing to a PR** - don't wait for user to ask; CI is running, monitor it
- If CI fails due to flakiness, auto-rerun failed jobs once with `gh run rerun <run-id> --failed`
- If CI fails twice, investigate the root cause
- **CRITICAL: After CI passes, run `/pr-review remote` before declaring ready to merge** - automated reviewers post new comments on each CI run

## Hooks

Configured hooks (in `~/.claude/hooks/`):

- **session-start.sh** - Auto-registers session with the event bus and fetches recent events
- **session-end.sh** - Unregisters session from the event bus on exit
- **prompt-events.sh** - Fetches new event bus events on every prompt (UserPromptSubmit hook)

## Event Bus

Cross-session coordination via `mcp__event-bus__*` tools. Sessions auto-register on startup via hooks.

**Channels:** `all` (broadcast), `repo:<name>` (most common), `machine:<host>`, `session:<id>` (DM)

**Key commands:**
- `/event-bus-status` - Overview of active sessions and recent activity
- `/broadcast` - Send messages to other sessions
- `/learnings` - Query historical discoveries (gotchas, patterns, flaky tests)

**Proactive publishing:** When you discover something useful (gotchas, patterns, flaky tests, blockers), publish it so other sessions benefit.

**Cross-repo coordination:** When creating issues in other repos (e.g., via `/improve-workflow`), broadcast to `repo:<target_repo>` so sessions there can pick up the work.

**Details:** See dotfiles `CLAUDE.md` or read the `event-bus://guide` MCP resource.

## Session Analytics

Workflow insights from Claude Code session logs via `mcp__session-analytics__*` tools.

**Key commands:**
- `/improve-workflow` - Data-driven workflow improvement suggestions
- `/status-report` - Includes session analytics in status summaries

**Key tools:** `get_insights`, `get_permission_gaps`, `get_handoff_context`, `analyze_failures`

**Details:** See dotfiles `CLAUDE.md` or read the `session-analytics://guide` MCP resource.

## Custom Commands

Available slash commands (in `~/.claude/commands/`):

- `/work` - Workflow-aware task execution with checkpoints (`<issue-number>`, `URL`, `"description"`, `--attach`)
- `/im-lost` - Show current workflow position and context when you've lost track
- `/status-report` - Generate repo status summary with recently completed work, open PRs/issues, and recommendations
- `/pr-create` - Commit changes and create/update a PR
- `/pr-review` - Review code via local analysis or remote reviewer comments (`local`, `remote`)
- `/audit-codebase` - Check for AI-generated anti-patterns and Evergreen violations
- `/audit-tests` - Find redundant or stale tests
- `/audit-issues` - Categorize open issues as current or needing updates
- `/improve-workflow` - Suggest workflow improvements, categorized as local (this repo) or global (dotfiles)
- `/rfc` - Create or respond to RFC-style issues (`--create` for new, issue number for response)
- `/watch-ci` - Monitor CI in background with notification when complete
- `/parallel-work` - Manage git worktrees for parallel PR development (start with tmux auto-launch, list, cleanup)
- `/event-bus-status` - Show event bus overview with active sessions and coordination insights
- `/broadcast` - Send message to other Claude Code sessions via event bus
- `/learnings` - Query historical discoveries (gotchas, patterns, flaky tests) from event bus
- `/commit-commands:commit-push-pr` - Commit, push, and create PR in one step (or use `/pr-create`)
- `/commit-commands:clean_gone` - Delete local branches whose remote tracking branch is gone
