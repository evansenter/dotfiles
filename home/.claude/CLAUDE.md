# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) for all sessions.

## Decision-Making

- Proactively suggest improvements when you notice opportunities.
- Feel free to use git and gh directly. Ask before pushing or closing PRs.

### Autonomous Decisions (no need to ask)

- Reading, creating, editing, or deleting files in the project (don't ask, just do it)
- Running tests, linters, formatters
- Creating branches, checking out, stashing
- Staging and committing changes
- Fetching PR/issue information
- Creating, merging, and editing PRs
- Creating, closing, and editing issues
- Re-running flaky CI (once per failure)
- Web searches for documentation/research

### Requires Discussion

- Pushing to remote
- Closing PRs
- Design trade-offs with multiple valid approaches
- Disagreements with reviewer feedback on Critical/Important items

## Allowed Permissions

Configured in `~/.claude/settings.json` for autonomous operation:

**Core:** Edit, Write, Read, WebSearch, EnterPlanMode

**Git CLI:**
- `git status`, `git diff`, `git log`, `git add`, `git commit`
- `git fetch`, `git branch`, `git remote`, `git mv`, `git checkout`, `git stash`

**GitHub CLI:**
- PRs: `gh pr view/list/checks/merge/create/edit/review`
- Issues: `gh issue list/view/close/create/edit`

**GitHub MCP Server:**
- PRs: `get_pull_request`, `list_pull_requests`, `get_pull_request_status`, `get_pull_request_files`, `get_pull_request_comments`, `get_pull_request_reviews`, `create_pull_request`, `merge_pull_request`, `update_pull_request_branch`, `create_pull_request_review`
- Issues: `get_issue`, `list_issues`, `create_issue`, `update_issue`, `add_issue_comment`, `search_issues`
- Other: `list_commits`, `create_branch`, `get_file_contents`, `search_code`

## Quality Gates

- Always run linter, formatter, and all tests before pushing.

## PR Workflow

- Before creating a PR with significant changes, check that CLAUDE.md and README.md are updated to reflect the changes.
- Before creating a PR, run `/pr-review-toolkit:review-pr` to locally check the quality of your changes.
- After pushing a PR, watch CI with `gh pr checks <PR#> --watch --interval 5`, then fetch comments with `gh pr view <PR#> --comments`.

### Handling PR Feedback

After CI completes and there's reviewer feedback, automatically run `/pr-feedback` to process it:

1. **Run analysis** - by default, runs both local (`/pr-review-toolkit:review-pr`) and remote review in parallel
   - Use `--local` for only local analysis, `--remote` for only external reviewer comments
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

- If integration tests fail with LLM-related flakiness (status mismatch, unexpected response format), auto-rerun failed jobs once with `gh run rerun <run-id> --failed`
- If tests fail twice, investigate the root cause

## Hooks

Configured hooks (in `~/.claude/hooks/`):

- **stop-hook.sh** - Gathers git/PR context when Claude stops. A prompt hook evaluates whether to continue working based on:
  - CI pending/running → continue and monitor
  - Unprocessed PR feedback → continue and address
  - Recent push needing CI → continue and watch
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
