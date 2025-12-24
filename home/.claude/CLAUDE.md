# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) for all sessions.

## Workflow Preferences

- For any implementation task with multiple phases or steps, prefer using the `/feature-dev` skill to guide the work.
- After pushing a PR, watch CI status with `gh pr checks <PR#> --watch --interval 5`, then fetch review comments with `gh pr view <PR#> --comments`. Address all sensible feedback from the code review, and open GitHub issues for items that should be deferred.
- When discovering bugs, technical debt, or improvements that won't be addressed right away, create GitHub issues to track them so they aren't forgotten.
