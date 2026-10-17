---
argument-hint: <issue-number | URL | "description" | --attach>
description: Workflow-aware task execution with checkpoints
---

# Work

Execute tasks with checkpoints: [guided development] → develop → `/pr-review local` → `/pr-create` → `/watch-ci` → `/pr-review remote` → merge → reflect.

Guided development (optional) explores the code, resolves open questions with the user, and settles the design before implementation.

## Usage

```
/work <issue-number | URL | "description">
/work --attach
```

## Identifiers

Tasks (created via TaskCreate) use `[work:ID]` subject prefix:

| Input | Identifier | Example |
|-------|------------|---------|
| Issue number | `issue-<N>` | `[work:issue-42]` |
| Ad-hoc | `adhoc` → `pr-<N>` | `[work:adhoc]` then `[work:pr-118]` |
| Attach to PR | `issue-<N>` or `pr-<N>` | `[work:pr-118]` |

Ad-hoc work transitions to `pr-<N>` after PR creation.

---

## Attach Mode (`--attach`)

Join existing PR on current branch, restoring WIP context if available.

1. **Check for WIP checkpoint**: Look for `<wip-checkpoint-restored>` tags from session start
2. Get PR info: `gh pr view --json number,title,state`
   - If no PR: "No PR found. Use `/work <issue-number>` to start new work, or `/pr-create` first."
3. Determine identifier from PR body (`Fixes #N` → `issue-N`, otherwise `pr-N`)
4. Fetch recent `wip_progress` events for this session: `mcp__agent-event-bus__get_events(channel: "session:<session-id>", limit: 5)`
5. Determine position (from WIP events, or fall back to PR/CI state):

| State | Already Completed |
|-------|-------------------|
| PR exists, no CI run | Implementation, pr-review local, pr-create |
| PR exists, CI pending | Above + watch-ci (partial) |
| PR exists, CI passed, review requests changes | Above + watch-ci, need pr-review remote |
| PR exists, CI passed, review approved | Above + watch-ci + pr-review remote |

Note: Code checks (lint, test, etc.) and claude-review are separate CI jobs.
claude-review posts a native GitHub review (approve/request-changes) — check review status with `gh pr view --json reviews`.

6. Create remaining tasks only. Display resume plan showing what's done and what remains.

---

## Starting New Work

### 1. Check for Active Session

If incomplete `[work:*]` tasks exist (check TaskList), block new work.

**Note:** Other tasks without `[work:*]` prefix don't block (including subagent tasks).

### 2. Parse Input

- Number → check if it's a GitHub issue first (`gh issue view <N>`). If not found, try event bus (`mcp__agent-event-bus__get_events(cursor: "<N>", limit: 1)`). If event found, use its payload as context for ad-hoc work.
- GitHub URL → extract issue number
- `event:<ID>` → fetch event bus event by ID, use payload as work context
- Other → `adhoc`

### 3. Check for Parallel Context

If `.parallel-context.md` exists in cwd, read it. This file is created by `/parallel-work start` and contains:
- Task description from parent session
- Decisions and constraints already established
- Relevant code locations identified
- Whether exploration was already done

Store this as `PARALLEL_CONTEXT` for use in scope presentation and guided development.

### 4. Fetch Context

For issues: `mcp__github__issue_read(method: "get", owner, repo, issue_number)` for title, body, labels.

### 5. Derive Initial Tasks

ultrathink: Break down into 2-6 implementation tasks (imperative form).

These are preliminary - if user opts into guided development, they'll be refined.

### 6. Present Scope

```markdown
## Proposed Work Scope

**Source:** #42 - Fix authentication timeout
**Identifier:** [work:issue-42]

### Tasks
1. <task 1>
2. <task 2>

### Context from Parent Session (if PARALLEL_CONTEXT exists)
[Summary of decisions, constraints, and exploration from parent]

### Checkpoints
- /pr-review local → /pr-create → /watch-ci → /pr-review remote → merge → reflect
```

Ask via AskUserQuestion:
- **Start work** - Proceed to guided development question
- **Modify scope** - Adjust tasks before starting
- **Cancel** - Abort without creating tasks

### 6b. Create Feature Branch

After scope is confirmed, create the feature branch **immediately** — before any exploration or design work that might produce committable artifacts (specs, docs).

```bash
git checkout -b issue-<N>   # or adhoc-<slug>
```

This prevents design specs or other artifacts from being committed to main, which causes merge conflicts on squash-merge.

### 7. Guided Development (Optional)

Ask: **Yes, explore first (Recommended)** / No, proceed directly

Recommend exploring unless you've already read the relevant code this session, the change is small and unambiguous with no architectural decision, or `PARALLEL_CONTEXT` says the parent session already explored. Issues go stale, and designs benefit from a fresh look at the current code. When skipping, say why.

#### Guided Development Phases

**Explore.** Read the code the change touches: similar features, the abstractions involved, and integration points. Do it yourself; use one built-in `Explore` agent only when the search genuinely spans many directories or naming conventions you can't guess.

**Clarify.** Before designing, resolve what the issue leaves open — intent, edge cases, integration points, scope boundaries — with AskUserQuestion, recommended option first. If the user says "whatever you think is best", give your recommendation and get an explicit yes.

**Design.** When there's a real architectural choice, present 2-3 approaches (for example: smallest change with maximum reuse, cleaner structure, pragmatic middle) with their trade-offs and your recommendation, and ask which to take. When there isn't, state the approach in a few sentences and move on.

**Context check.** If more than 70% of the context window is used, suggest compacting before implementation: the pre-compact hook checkpoints WIP state, but a clean boundary is better than a mid-edit compaction.

**Derive tasks.** Turn the chosen approach into the final implementation tasks; they replace the initial tasks from step 5.

---

### 8. Create Tasks

Create via TaskCreate, one per item:

```
[work:${ID}] <task 1>
[work:${ID}] <task 2>
[work:${ID}] Run /pr-review local
[work:${ID}] Create PR with /pr-create
[work:${ID}] Monitor CI with /watch-ci
[work:${ID}] Process feedback with /pr-review remote
[work:${ID}] Confirm merge with user
[work:${ID}] Reflect with improve-workflow agent
```

### 9. Broadcast & Begin

Rename the zellij tab to reflect the work ID (if in zellij):

```bash
zellij action rename-tab "${ID}: <short title>" 2>/dev/null || true
```

Publish `task_started` with your session_id (from startup: "Registered on event bus as: <session_id>"):

```
mcp__agent-event-bus__publish_event(
  event_type: "task_started",
  payload: "Starting work on #<issue> - <title>",
  session_id: "<your-session-id>",
  channel: "repo:<repo_name>"
)
```

Mark first task `in_progress`.

---

## WIP State Checkpointing

WIP state is **automatically checkpointed** by the `pre-compact.sh` hook before context compaction.

**Auto-captured:** `[work:ID] | branch | pr: #N | files | time`

**On session resume:** Check `<wip-checkpoint-restored>` tags in session start. Combined with the persisted task list, this provides enough context to continue work.

---

## Checkpoint Handling

**Goal-based loops:** For a review→fix or CI→fix cycle expected to take more than one round, offer to set `/goal` with the deterministic stop condition (e.g., `CI green on PR #N and /pr-review local clean`) — see Loops & Automation. Judgment-heavy checkpoints (scope, merge confirmation, feedback triage) stay turn-based.

**Run /pr-review local**: Run, fix issues if found, loop until clean — cap at 3 rounds. Each fix is new surface for the next review, so a review→fix cycle can run forever on polish; once a round yields only Suggestions, it has converged.

**Create PR**: Run `/pr-create`. If adhoc, update remaining tasks to `[work:pr-N]`.

**Monitor CI**: Run `/watch-ci <PR#>` in background.

**Process feedback**: Run `/pr-review remote` (do not gate on CI status — review and CI are independent). If changes pushed, reset CI and feedback checkpoints, loop.

Track the round count. From round 3, only act on findings that name a concrete failure (inputs/state → wrong output); post the rest as acknowledged-but-skipped in the "Feedback Addressed" comment rather than fixing them. If rounds 5+ are still producing only polish findings — or you find yourself reworking the same construct across consecutive rounds — stop and surface it to the user via `AskUserQuestion`: merge as-is, or address a specific remaining item. Do not keep pushing; every push triggers the next review round.

**Confirm merge**: First, verify that `/pr-review remote` was run against the latest pushed commit. Check the PR comments for a "Feedback Addressed" or "No reviewer feedback" comment posted after the most recent push. If no such comment exists, run `/pr-review remote` now before proceeding. Never skip this — CI pass alone is not sufficient for merge.

Spawn summarize-work agent to show what's being merged:
- `Agent(subagent_type="summarize-work", prompt="Summarize work on this PR for merge review")`

When showing the output from summarize-work, always highlight the key files to look at, and the PR URL. Include any other relevant data as well.

**Always** ask user via AskUserQuestion (Merge now / Wait), adding a "Post summary to PR" option when summarize-work recommends posting (it returns the exact command). Never auto-merge. After merge:

```
mcp__agent-event-bus__publish_event(
  event_type: "task_completed",
  payload: "Merged PR #<N> - <title>",
  session_id: "<your-session-id>",
  channel: "repo:<repo_name>"
)
```

**Cleanup WIP state** (optional, prevents stale checkpoints):
```
mcp__agent-event-bus__publish_event(
  event_type: "wip_cleared",
  payload: "[work:<ID>] Work completed - merged PR #<N>",
  session_id: "<your-session-id>",
  channel: "session:<your-session-id>"
)
```

Suggest pruning merged branches: `git fetch --prune && git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | awk '$2 == "[gone]" {print $1}'` lists local branches whose remote is gone; delete them with `git branch -D` after confirming.

**Reflect**:
- **Difficulty**: Rate Easy/Medium/Hard. What was harder than expected?
- **Friction**: What slowed you down? (permissions, unclear code, missing tests)
- **User steering**: Where did the user redirect you?
- **Improvements**: What would make this easier?

Publish insights to event bus with session_id (`gotcha_discovered`, `pattern_found`).

Spawn improve-workflow agent — it handles memory persistence, session analytics, and workflow improvement suggestions:

`Agent(subagent_type="improve-workflow", prompt="Analyze this session for workflow improvements")`

Present its findings (at most 3) via AskUserQuestion — Implement / Skip / Defer (a GitHub issue labeled `improvement`) — and act on the answers.

---

## Skipping Checkpoints

If a checkpoint doesn't apply:
1. Confirm with user
2. Mark `completed` with note explaining why skipped
3. Continue to next checkpoint

---

## Error Handling

| Error | Response |
|-------|----------|
| Issue not found | "Issue #N not found. Check the number." |
| Active work exists | "Active session exists. Complete or clear first." |
| Checkpoint failed | Add fix tasks, retry after fixes |
