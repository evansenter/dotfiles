# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) for all sessions.

## Decision-Making

- Proactively suggest improvements when you notice opportunities.
- Feel free to use git and gh directly. Ask before pushing, merging, or creating/closing PRs.

### Autonomous Decisions (no need to ask)

- Running tests, linters, formatters
- Creating branches
- Staging and committing changes
- Fetching PR/issue information
- Re-running flaky CI (once per failure)

### Requires Discussion

- Pushing to remote
- Creating/merging/closing PRs
- Design trade-offs with multiple valid approaches
- Disagreements with reviewer feedback on Critical/Important items

## Quality Gates

- Always run linter, formatter, and all tests before pushing.

## PR Workflow

- Before creating a PR with significant changes, check that CLAUDE.md and README.md are updated to reflect the changes.
- Before creating a PR, run `/pr-review-toolkit:review-pr` to locally check the quality of your changes.
- After pushing a PR, watch CI with `gh pr checks <PR#> --watch --interval 5`, then fetch comments with `gh pr view <PR#> --comments`.

### Handling PR Feedback

After CI completes and there's reviewer feedback, automatically run `/pr-feedback` to process it:

1. **Categorize** feedback as Critical, Important, or Suggestion
2. **Form opinions** - assess whether each item is valid given your context on the work
3. **Present table** with: #, Severity, Feedback, Opinion, Action (Implement/Discuss/Skip)
4. **Implement immediately**: Critical/Important items you agree with
5. **Stop and discuss**: Critical/Important items you disagree with or are uncertain about
6. **Skip**: Suggestions you disagree with (note in summary)

**Key principle**: You have context on the work's purpose that automated reviewers lack. Honest disagreement is more valuable than blind compliance. If feedback misses the point or adds unnecessary complexity, flag it for discussion.

### After Feedback Discussion

- Implement items where agreement was reached
- Skip items agreed to skip
- Create GitHub issues for out-of-scope work
- Never merge a PR without explicitly asking the user for permission first.

## Issue Workflow

- When making an issue, check if there are relevant labels to put on the issue. Suggest new labels as needed.

## CI Handling

- If integration tests fail with LLM-related flakiness (status mismatch, unexpected response format), auto-rerun failed jobs once with `gh run rerun <run-id> --failed`
- If tests fail twice, investigate the root cause

## Custom Commands

Available slash commands (in `~/.claude/commands/`):

- `/status-report` - Generate repo status summary with recently completed work, open PRs/issues, and recommendations
- `/pr-feedback` - Process PR review feedback with categorization and opinion-forming
- `/pr-followups` - Find unaddressed or deferred comments from merged PRs
- `/audit-codebase` - Check for AI-generated anti-patterns and Evergreen violations
- `/audit-tests` - Find redundant or stale tests
- `/audit-issues` - Categorize open issues as current or needing updates
- `/improve-workflow` - Suggest Claude Code features and config improvements
