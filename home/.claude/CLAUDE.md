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
- After completing implementation work: summarize changes and run `/pr-feedback --local` before pushing
- **After creating or pushing to a PR: immediately run `/watch-ci <PR#>`** - CI is now running, monitor it

### Requires Discussion

- Merging PRs (GitHub PR merges via `gh pr merge`, not local `git merge`)
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
- Issues: `gh issue list/view/close/create/edit`
- CI: `gh run view/list/rerun/watch`

**Build Tools:**
- `make`, `cargo check/build/test/clippy/fmt/run/doc`

**GitHub MCP Server:**
- PRs: `get_pull_request`, `list_pull_requests`, `get_pull_request_status`, `get_pull_request_files`, `get_pull_request_comments`, `get_pull_request_reviews`, `create_pull_request`, `merge_pull_request`, `update_pull_request_branch`, `create_pull_request_review`
- Issues: `get_issue`, `list_issues`, `create_issue`, `update_issue`, `add_issue_comment`, `search_issues`
- Other: `list_commits`, `create_branch`, `get_file_contents`, `search_code`

**When to use MCP vs gh CLI:**
- **Prefer MCP** for standard operations (faster, structured data): fetching PR/issue details, creating issues, listing items
- **Use gh CLI** when MCP doesn't support it: `gh pr checks --watch`, `gh run` commands, `gh api` for arbitrary endpoints

## Quality Gates

- Run quality gates appropriate to the project (linter, formatter, tests) before pushing.
- Significant user-facing features should include examples demonstrating usage - this ensures the codepath doesn't go stale.

## PR Workflow

### Development Flow

1. **Orient**: Run `/status-report` to see recent work, open issues, and recommendations
2. **Pick work**: Choose an issue or task to work on
3. **Develop**: Make changes, run tests/linters as needed
4. **Self-review**: After completing work, summarize what was done and run `/pr-feedback --local` before pushing
5. **Iterate**: Address feedback, repeat step 4 until clean
6. **Create PR**: Use `/commit-commands:commit-push-pr` (preferred) for streamlined commit-push-PR flow
7. **Monitor CI**: Run `/watch-ci <PR#>` after PR creation or any push - track in background with notification
8. **Process feedback**: When CI passes, run `/pr-feedback --remote` to handle reviewer comments
9. **Merge & cleanup**: After approval, merge PR and run `/commit-commands:clean_gone` to clean stale branches

### Pre-PR Checklist

- Check that CLAUDE.md and README.md are updated for significant changes
- Run `/pr-feedback --local` to catch issues before pushing

### Handling PR Feedback

After CI passes, run `/pr-feedback --remote` to fetch and process reviewer comments. Use `--local` for self-checks after implementing fixes (reviewers haven't seen your changes yet).

1. **Fetch comments** from the PR
2. **Categorize** feedback as Critical, Important, or Suggestion
3. **Form opinions** - assess whether each item is valid given your context on the work
4. **Present ALL items** via AskUserQuestion with your opinion included
5. **Act on user's choices**:
   - **Implement**: Fix it immediately
   - **Skip**: Note it was skipped, move on
   - **Defer**: Create a GitHub issue for later
6. **Push and re-check** - run `/pr-feedback --local` to verify changes are clean

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

## Custom Commands

Available slash commands (in `~/.claude/commands/`):

- `/im-lost` - Show current workflow position and context when you've lost track
- `/status-report` - Generate repo status summary with recently completed work, open PRs/issues, and recommendations
- `/pr-feedback` - Process PR review feedback with categorization and opinion-forming
- `/pr-followups` - Find unaddressed or deferred comments from merged PRs
- `/audit-codebase` - Check for AI-generated anti-patterns and Evergreen violations
- `/audit-tests` - Find redundant or stale tests
- `/audit-issues` - Categorize open issues as current or needing updates
- `/cross-repo` - Gather context from a related repository (CLAUDE.md, PRs, issues)
- `/improve-workflow` - Suggest workflow improvements, categorized as local (this repo) or global (dotfiles)
- `/rfc-response` - Generate structured response to RFC-style issues with assumptions, questions, and requirements
- `/watch-ci` - Monitor CI in background with notification when complete
- `/parallel-work` - Manage git worktrees for parallel PR development (start, list, cleanup)
- `/commit-commands:commit-push-pr` - Commit, push, and create PR in one step (preferred for new PRs)
- `/commit-commands:clean_gone` - Delete local branches whose remote tracking branch is gone
