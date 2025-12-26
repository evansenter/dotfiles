# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) for all sessions.

## Decision-Making

- Proactively suggest improvements when you notice opportunities.
- Feel free to use git and gh directly. Ask before pushing, merging, or creating/closing PRs.

## Quality Gates

- Always run linter, formatter, and all tests before pushing.

## PR Workflow

- After pushing a PR, watch CI with `gh pr checks <PR#> --watch --interval 5`, then fetch comments with `gh pr view <PR#> --comments`.
- After CI code review completes, summarize all reviewer feedback and suggestions in a table with columns: #, Feedback, Opinion, Recommendation (address/skip).
- When considering the code reviewer's feedback, provide honest analysis of each suggestion: assess whether it's worth addressing, explain the trade-offs, and recommend skipping items that don't provide proportional value.
- Implement all reviewer feedback that's topical to the PR, regardless of priority (issues, recommendations, and suggestions). Use GitHub issues only for out-of-scope work or unrelated bugs discovered along the way.
- Never merge a PR without explicitly asking the user for permission first.

## Issue Workflow

- When making an issue, check if there are relevant labels to put on the issue. Suggest new labels as needed.

