# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) for all sessions.

## Decision-Making

- Proactively suggest improvements when you notice opportunities.
- Feel free to use git and gh directly. Ask before pushing, merging, or creating/closing PRs.

## Quality Gates

- Always run linter, formatter, and all tests before pushing.

## PR Workflow

- After pushing a PR, watch CI with `gh pr checks <PR#> --watch --interval 5`, then fetch comments with `gh pr view <PR#> --comments`.
- Implement all reviewer feedback that's topical to the PR, regardless of priority. Use GitHub issues only for out-of-scope work or unrelated bugs discovered along the way.
