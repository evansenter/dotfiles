# Work / Review Cycle

A guided development workflow for Claude Code that takes a task from issue to merge with structured checkpoints. Designed for solo developers who want CI-gated quality without manual review overhead.

## Overview

```
/work <issue>  →  [guided development]  →  implement  →  /pr-review local
                                                              ↓
                                              /pr-create  →  /watch-ci
                                                              ↓
                                              /pr-review remote  →  fix  →  push  (loop)
                                                              ↓
                                              merge  →  reflect
```

## Commands

| Command | Purpose |
|---------|---------|
| `/work <issue\|URL\|desc>` | Start guided development with checkpoints |
| `/work --attach` | Resume work on current branch's PR |
| `/pr-review local` | Self-review before pushing |
| `/pr-create` | Commit, push, open PR |
| `/watch-ci [PR#]` | Monitor CI in background, auto-trigger remote review |
| `/pr-review remote` | Process reviewer/bot feedback via AskUserQuestion |

## How It Works

### 1. Start Work (`/work <issue>`)

Parses the input (issue number, URL, or description), fetches context, and presents a scope proposal. Optionally runs **guided development** — a multi-phase process:

1. **Explore** — Launch parallel `code-explorer` agents to understand the codebase
2. **Clarify** — Structured design conversation (edge cases, integration points, scope)
3. **Architect** — Parallel `code-architect` agents propose approaches; you pick one
4. **Document** — Structured implementation plan
5. **Context Check** — Warn if context window is >70% full before implementation
6. **Derive Tasks** — Break plan into implementation todos

Creates a task list with `[work:ID]` prefix and checkpoint tasks (review, PR, CI, merge, reflect).

### 2. Implement

Work through tasks. The task list tracks progress. WIP state is automatically checkpointed by the `PreCompact` hook before context compaction — sessions can resume with `/work --attach`.

### 3. Self-Review (`/pr-review local`)

Before pushing:
- Summarize changes
- Run `pr-review-toolkit:code-reviewer` agent
- Check test/example coverage gaps
- Security spot-check (scans for auth, crypto, config, dependency changes)
- Loop until clean

### 4. Create PR (`/pr-create`)

- Verify quality gates pass
- Check for main drift (optionally rebase)
- Commit, push, open PR via `commit-push-pr` skill
- Auto-start `/watch-ci`

### 5. Monitor CI (`/watch-ci`)

Runs `gh pr checks --watch` in the background. When CI completes:
- Notifies via system notification
- Auto-triggers `/pr-review remote`
- If CI failed, investigates alongside review (independent concerns)

### 6. Process Feedback (`/pr-review remote`)

Fetches reviewer comments and bot reviews (inline + summary):
- Filters already-resolved items via "Feedback Addressed" comment history
- Forms opinions on each finding (Agree/Disagree/Uncertain)
- Presents findings via `AskUserQuestion` with options: Implement / Skip / Defer / Elaborate
- Implements approved changes, creates issues for deferred items
- Posts "Feedback Addressed" comment with Implemented/Skipped/Deferred sections
- Pushes fixes → triggers new CI → cycle repeats until clean

### 7. Merge

- Spawns `summarize-work` agent for merge review
- Asks user via `AskUserQuestion` (never auto-merges)
- Publishes `task_completed` to event bus
- Suggests branch cleanup

### 8. Reflect

- Rate difficulty, identify friction points, note user steering
- Pull session analytics metrics for grounded reflection
- Publish gotchas/patterns to event bus
- Persist repo-specific gotchas to auto-memory
- Run `/revise-claude-md` to capture learnings
- Spawn `improve-workflow` agent

## Automated Review (CI)

The `claude-code-review.yml` workflow runs on every PR push:

1. Fetches the review prompt from `claude-review.md` on main
2. Runs Claude Code via `claude-code-action` to review the diff
3. Posts a **native GitHub review** with inline file/line comments via `gh api`
4. Sets review status: APPROVE or REQUEST_CHANGES

**Review standards:**
- Critical or Important issues → REQUEST_CHANGES (blocks merge)
- Suggestions only → APPROVE (inline comments posted but non-blocking)
- Previously addressed items are filtered via semantic matching against "Feedback Addressed" comments

**Branch protection:**
- Requires 1 approving review (bot counts)
- Dismisses stale reviews on new pushes (bot re-reviews automatically)
- Admin bypass available if bot is down

## Event Bus Integration

The workflow publishes events for cross-session coordination:
- `task_started` / `task_completed` — track work across sessions
- `ci_completed` — notify when CI finishes
- `feedback_addressed` — track review cycles
- `gotcha_discovered` / `pattern_found` — share learnings
- `wip_checkpoint` — auto-saved before context compaction

Sessions register on startup. Other sessions can see active work via `/event-bus-status` and send messages via `/broadcast`.

## Porting to Other Projects

### Required files

Copy from `home/.claude/`:

```
commands/
  work.md           # Main workflow orchestrator
  pr-review.md      # Local + remote review
  pr-create.md      # Commit, push, PR creation
  watch-ci.md       # Background CI monitoring
  im-lost.md        # Show workflow position
```

### Required CI

Copy from `.github/workflows/`:

```
claude-code-review.yml    # Automated review workflow
```

And the review prompt:

```
contrib/prompts/claude-review.md    # Review instructions
```

### Required infrastructure

| Component | Purpose | Required? |
|-----------|---------|-----------|
| Event bus | Cross-session coordination, WIP checkpoints | Optional (gracefully degrades) |
| Session analytics | Grounded reflection metrics | Optional |
| `claude-code-action` | CI review bot | Required for automated review |
| Branch protection | Review gating | Recommended |

### Required plugins

```json
{
  "enabledPlugins": {
    "feature-dev@claude-plugins-official": true,
    "pr-review-toolkit@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "superpowers@claude-plugins-official": true
  }
}
```

### Customization points

- **Review prompt** (`claude-review.md`) — adjust review standards, severity rules, output format
- **Guided development phases** — skip/add phases in `work.md` based on project complexity
- **Security patterns** — customize file globs in `pr-review.md` security spot-check
- **Effort guidance** — tune reasoning depth per phase in `work.md`
