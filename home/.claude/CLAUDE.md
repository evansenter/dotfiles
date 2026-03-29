# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) for all sessions.

## Decision-Making

- Use git and gh freely. Never merge or close PRs without explicit user approval.
- All repos have branch protection—create PRs, never push to main directly.
- Prefer MCP tools for structured data; use gh CLI for `--watch` flags, runs, and arbitrary API calls.

### Proactive Improvements

Don't wait to be asked. When you notice these patterns, surface them unprompted:
- Gap in tooling coverage (e.g., missing agent for a common audit pattern)
- Repeated manual work that could be automated
- Cross-repo patterns that could be shared
- Documentation drifted from reality
- Workflow friction you experienced during the session

Propose concrete solutions, not just observations.

### Autonomous Decisions

Default: act without asking for file operations, git, tests, linters, PRs, issues, web searches.

Non-obvious autonomy:
- Re-run flaky CI once (`gh run rerun <id> --failed`); investigate if it fails twice
- After completing work: summarize and run `/pr-review local` before pushing
- After creating/pushing to PR: run `/watch-ci <PR#>` immediately
- When making issues: check for relevant labels, suggest new ones

### Requires Discussion

- Design trade-offs with multiple valid approaches
- Disagreements with reviewer feedback on Critical/Important items

## Quality Gates

- Run quality gates (linter, formatter, tests) before pushing.
- New code needs tests. User-facing features need examples. Flag gaps.

## Reflection

After significant work: share what caused friction, where you were redirected (indicates missing guidance), and what's missing. Publish insights to event bus (`gotcha_discovered`, `pattern_found`, `improvement_suggested`). When an Insight (★) is a reusable gotcha or cross-session pattern — not just a local code explanation — publish it too.

## PR Workflow

Use `/work <issue-number>` for guided development. `/work --attach` to join an existing PR.

- **Before pushing**: `/pr-review local`, update docs if needed
- **After push**: `/pr-create` (or just push) → `/watch-ci` → CI completes → `/pr-review remote`
- **On feedback**: Present via AskUserQuestion. Form your own opinion—you have context reviewers lack
- **After fixes**: Push → auto-cycle repeats until clean

## Event Bus

Cross-session coordination. Sessions auto-register on startup.

**Broadcast model:** All sessions see all events. Channels are priority metadata:
- `session:<id>` (high), `repo:<name>` (medium), `machine:<host>`/`all` (low)

**Behaviors:**
- Publish discoveries proactively: gotchas, patterns, flaky tests, blockers, improvement ideas
- When creating cross-repo issues, broadcast to `repo:<target>`
- When user says "ask/tell `<repo>` XYZ", send `help_needed` to `repo:<repo>`

**Handling events** (from `<recent-events>` tags):

On each turn, scan incoming events *before* responding. For relevant events, briefly acknowledge them at the start of your response. When in doubt, overshare—it's better to mention something the user already knows than to silently drop important context.

- **Act on immediately**: DMs (`session:<your-id>`), `help_needed` to your repo, CI failures you caused, blockers
- **Mention to user**: `help_response`, `gotcha_discovered`, `pattern_found`, `test_flaky`, `improvement_suggested`
