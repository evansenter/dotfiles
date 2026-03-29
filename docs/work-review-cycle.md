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

Parses the input (issue number, URL, event bus ID, or description), fetches context, and presents a scope proposal. Numbers are checked as GitHub issues first, then event bus events — so `/work 2883` on a `test_flaky` event works without manually explaining context. Optionally runs **guided development** — a multi-phase process:

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

**Always runs after CI completes**, regardless of review verdict. An APPROVED review can still have inline suggestions that should be presented to the user before merging.

Fetches reviewer comments and bot reviews (inline + summary):
- Checks both review status AND inline comments (APPROVE with suggestions is common)
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

### What's shared vs repo-specific

Most of the workflow lives in `~/.claude/` which is symlinked by `bootstrap.sh` from the dotfiles repo. This means commands, hooks, skills, agents, and plugins are **shared across all repos automatically**.

| Component | Location | Shared? |
|-----------|----------|---------|
| Commands (`/work`, `/pr-review`, etc.) | `~/.claude/commands/` | Yes — via dotfiles symlink |
| Hooks (session-start, pre-compact, etc.) | `~/.claude/hooks/` | Yes — via dotfiles symlink |
| Skills (shell-scripting, hook-authoring, etc.) | `~/.claude/skills/` | Yes — via dotfiles symlink |
| Agents (audit-*, rfc-*, etc.) | `~/.claude/agents/` | Yes — via dotfiles symlink |
| Plugins (superpowers, feature-dev, etc.) | `~/.claude/settings.json` | Yes — via dotfiles symlink |
| Review prompt (`claude-review.md`) | Fetched from dotfiles GitHub URL | Yes — centralized |
| `claude-code-review.yml` workflow | `.github/workflows/` per repo | **No — must copy** |
| `claude.yml` workflow (@claude mentions) | `.github/workflows/` per repo | **No — must copy** |
| Branch protection rules | GitHub repo settings | **No — must configure** |
| `CLAUDE.md` | Repo root | **No — project-specific** |

### Per-repo setup checklist

After running `bootstrap.sh` (which sets up the shared components):

1. **Copy the CI workflow** to `.github/workflows/claude-code-review.yml`:
   ```yaml
   # Fetches review prompt from dotfiles — no need to copy the prompt itself
   env:
     PROMPT_URL: https://raw.githubusercontent.com/evansenter/dotfiles/main/home/.claude/contrib/prompts/claude-review.md
   ```
   Use the version from dotfiles as a template. Key: include `Bash(gh pr review:*)` and `Bash(gh api:*)` in allowed tools for native reviews with inline comments.

2. **Add the `CLAUDE_CODE_OAUTH_TOKEN` secret** to the repo (Settings > Secrets > Actions).

3. **Configure branch protection** on `main`:
   - Require 1 approving review (bot counts)
   - Dismiss stale reviews on push
   - Don't enforce for admins (escape hatch if bot is down)

4. **Write a project-specific `CLAUDE.md`** covering:
   - Build/test/lint commands
   - Architecture overview
   - Project conventions Claude wouldn't infer

### Updating existing repos

If a repo already has `claude-code-review.yml` from before the native review migration, update it:
- Add `Bash(gh pr review:*)` to `claude_args --allowed-tools`
- Remove the "Check review verdict" step (if present) — the review status is the signal now
- The centralized prompt is fetched from `main` on dotfiles, so prompt changes apply to all repos automatically

### Example: genai-rs

genai-rs already has most of this set up. The only gap is the `claude-code-review.yml` still has the old comment-parsing verdict step. Updating that one file brings it fully in line.

### Required infrastructure

| Component | Purpose | Required? |
|-----------|---------|-----------|
| Event bus | Cross-session coordination, WIP checkpoints | Optional (gracefully degrades) |
| Session analytics | Grounded reflection metrics | Optional |
| `claude-code-action` | CI review bot | Required for automated review |
| Branch protection | Review gating | Recommended |

### Customization points

- **Review prompt** (`claude-review.md`) — centralized in dotfiles, changes apply to all repos
- **Guided development phases** — skip/add phases in `work.md` based on project complexity
- **Security patterns** — customize file globs in `pr-review.md` security spot-check
- **Effort guidance** — tune reasoning depth per phase in `work.md`
- **Project CLAUDE.md** — repo-specific conventions, commands, architecture
