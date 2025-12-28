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
- After completing implementation work: summarize changes and run `/pr-feedback --local`

### Requires Discussion

- Merging PRs
- Closing PRs
- Design trade-offs with multiple valid approaches
- Disagreements with reviewer feedback on Critical/Important items

## Allowed Permissions

Configured in `~/.claude/settings.json` for autonomous operation:

**Core:** Edit, Write, Read, WebSearch, EnterPlanMode

**Git CLI:**
- `git status`, `git diff`, `git log`, `git add`, `git commit`
- `git fetch`, `git branch`, `git remote`, `git mv`, `git checkout`, `git stash`
- `git push`, `git rebase`

**GitHub CLI:**
- PRs: `gh pr view/list/checks/merge/create/edit/review`
- Issues: `gh issue list/view/close/create/edit`

**GitHub MCP Server:**
- PRs: `get_pull_request`, `list_pull_requests`, `get_pull_request_status`, `get_pull_request_files`, `get_pull_request_comments`, `get_pull_request_reviews`, `create_pull_request`, `merge_pull_request`, `update_pull_request_branch`, `create_pull_request_review`
- Issues: `get_issue`, `list_issues`, `create_issue`, `update_issue`, `add_issue_comment`, `search_issues`
- Other: `list_commits`, `create_branch`, `get_file_contents`, `search_code`

## Quality Gates

- Run quality gates appropriate to the project (linter, formatter, tests) before pushing.

## PR Workflow

### Development Flow

1. **Orient**: Run `/status-report` to see recent work, open issues, and recommendations
2. **Pick work**: Choose an issue or task to work on
3. **Develop**: Make changes, run tests/linters as needed
4. **Self-review**: After completing work, summarize what was done and run `/pr-feedback --local`
5. **Iterate**: Address feedback, repeat step 4 until clean
6. **Create PR**: Use `/commit-commands:commit-push-pr` (preferred) for streamlined commit-push-PR flow
7. **Monitor CI**: Run `/watch-ci <PR#>` to track in background with notification
8. **Process feedback**: When CI passes, run `/pr-feedback --remote` to handle reviewer comments

### Pre-PR Checklist

- Check that CLAUDE.md and README.md are updated for significant changes
- Run `/pr-feedback --local` to catch issues before pushing

### Handling PR Feedback

After CI completes and there's reviewer feedback, run `/pr-feedback --remote` to process it:

1. **Fetch comments** from the PR
2. **Categorize** feedback as Critical, Important, or Suggestion
3. **Form opinions** - assess whether each item is valid given your context on the work
4. **Present grouped output** organized by action:
   - **Implement**: Items to fix immediately
   - **Discuss**: Items needing user input
   - **Skip**: Items to note but not implement
5. **Implement immediately**: Critical/Important items you agree with
6. **Stop and discuss**: Critical/Important items you disagree with or are uncertain about

**Key principle**: You have context on the work's purpose that automated reviewers lack. Honest disagreement is more valuable than blind compliance. If feedback misses the point or adds unnecessary complexity, flag it for discussion.

### After Feedback Discussion

- Implement items where agreement was reached
- Skip items agreed to skip
- Create GitHub issues for out-of-scope work

## Issue Workflow

- When making an issue, check if there are relevant labels to put on the issue. Suggest new labels as needed.

## CI Handling

- If CI fails due to flakiness, auto-rerun failed jobs once with `gh run rerun <run-id> --failed`
- If CI fails twice, investigate the root cause

## Hooks

Configured hooks (in `~/.claude/hooks/`):

- **notify.sh** - Cross-platform notifications (macOS: osascript, Linux: notify-send)

## Custom Commands

Available slash commands (in `~/.claude/commands/`):

- `/status-report` - Generate repo status summary with recently completed work, open PRs/issues, and recommendations
- `/pr-feedback` - Process PR review feedback with categorization and opinion-forming
- `/pr-followups` - Find unaddressed or deferred comments from merged PRs
- `/audit-codebase` - Check for AI-generated anti-patterns and Evergreen violations
- `/audit-tests` - Find redundant or stale tests
- `/audit-issues` - Categorize open issues as current or needing updates
- `/improve-workflow` - Suggest Claude Code features and config improvements
- `/watch-ci` - Monitor CI in background with notification when complete
- `/commit-commands:commit-push-pr` - Commit, push, and create PR in one step (preferred for new PRs)
