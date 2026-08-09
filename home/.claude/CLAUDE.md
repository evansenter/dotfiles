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

Propose concrete solutions, not just observations. For low-trigger-rate fixes, prefer memory/event-bus/docs over skill-prompt edits — skill edits tax every invocation across all sessions.

Surface and propose — don't fold the improvement into the current task's diff. Proactive means noticing unprompted, not widening scope unprompted (see Model Policy → Scope).

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

## Model Policy

Default is opus (Claude Opus 5) — `settings.json` for interactive sessions, `--model opus` in `claude-code-review.yml` for the CI reviewer. Agents pin a tier in their frontmatter: opus for `audit-*` / `rfc-*` / `improve-workflow` (judgment-heavy sweeps), sonnet for `summarize-work`, haiku for `status-report`. Fable is ~2x opus per token; use it only when asked for by name. The `@claude` mention workflow is deliberately unpinned and tracks the action default.

### Working with Opus 5

Behaviors worth counteracting — see the migration guide in the `claude-api` skill for the full list:

- **Length.** Keep responses focused and brief; put most of the response on the main answer rather than caveats. Match written deliverables (especially Markdown files) to what the task needs — no filler sections or redundant summaries. Lowering effort does not reliably shorten visible output; say so in the prompt instead.
- **Scope.** Deliver what was asked at the scope intended. Make routine judgment calls; check in only when readings diverge materially. If the ask looks mistaken, say so in a sentence and keep going rather than quietly widening or narrowing it. Finish the whole task and report completion only when it's actually done.
- **Delegation.** Subagents multiply cost and latency — each re-establishes context and reports back. Delegate genuinely independent, sizeable tracks; do the rest inline. Never fan out more than 20 agents unless explicitly asked. Verification belongs in the main loop, not in a subagent.
- **Verification.** Don't add "double-check your answer" instructions — Opus 5 verifies its own work, and telling it to causes over-verification.
- **Corrections.** Only correct an earlier statement when the error changes the user's code or decisions. State it plainly and move on; don't ruminate or tally past mistakes. A follow-up question is not by itself a signal that something was wrong.

## Quality Gates

- Run quality gates (linter, formatter, tests) before pushing.
- New user-facing behavior needs tests; user-facing features need examples. Flag gaps. An untested internal helper or branch is a suggestion, not a blocker — treating every new line as a coverage defect makes fix→re-review cycles unable to converge.

## Reflection

After significant work: share what caused friction, where you were redirected (indicates missing guidance), and what's missing. Publish insights to event bus (`gotcha_discovered`, `pattern_found`, `improvement_suggested`).

**★ Insight → Event Bus:** Insights worth emitting are worth publishing. When you emit an `★ Insight` block, publish it via `mcp__agent-event-bus__publish_event` in the same response. Exception: if the insight is purely about a specific line in a specific file with zero cross-session value, don't emit the block at all. A Stop hook (`enforce-insight-publish.sh`) enforces this — violations block the turn until you publish.

## PR Workflow

Use `/work <issue-number>` for guided development. `/work --attach` to join an existing PR.

- **Before pushing**: `/pr-review local`, update docs if needed
- **After push**: `/pr-create` (or just push) → `/watch-ci` → CI completes → `/pr-review remote`
- **On feedback**: Present via AskUserQuestion. Form your own opinion—you have context reviewers lack
- **After fixes**: Push → auto-cycle repeats until clean, capped at ~5 rounds. Each push triggers the next review, and each fix is new surface for it. From round 3, only fix findings with a concrete failure scenario; when a round yields only polish, the PR has converged — ask the user to merge rather than pushing again

## Loops & Automation

A loop is repeating cycles of work until a stop condition is met. Pick the lightest primitive that fits, and write the verification check *before* handing work to a loop — if "done" can't be checked deterministically, keep it turn-based.

- **Turn-based** (default): user steers each iteration. For exploratory or judgment-heavy work.
- **Goal-based** (`/goal`): work with a checkable done-condition. Use deterministic criteria (tests pass, CI green, zero Critical findings) — the evaluator blocks premature "good enough" stops. Set a turn cap.
- **Time-based** (`/loop <interval>`): polling external systems only. Prefer event-driven signals (event bus, background task notifications, `--watch` flags) over time-driven polling; when you must poll, use the longest interval that works.
- **Scheduled** (`/schedule` Routines): recurring maintenance on a calendar — e.g., weekly `audit-*` agent sweeps (`/schedule-audits`), dependency freshness checks.
- **Dynamic workflows** (ask for a workflow): fan out many agents for wide sweeps — audits, migrations, multi-lens reviews. Monitor with `/workflows`. Keep spawn counts to what the sweep needs (see Model Policy → Delegation).

After a loop runs, note where it stalled or over-reached, then tighten the stop condition or interval. Never busy-wait with foreground `sleep` — background the watcher or use `/loop`.

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
