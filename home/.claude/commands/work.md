---
argument-hint: <issue-number | URL | "description" | --attach>
description: Workflow-aware task execution with checkpoints
---

# Work

Execute tasks with checkpoints: [guided development] → develop → `/pr-review local` → `/pr-create` → `/watch-ci` → `/pr-review remote` → merge → reflect.

## Usage

```
/work <issue-number | URL | "description">
/work --attach
```

## Identifiers

Todos use `[work:ID]` prefix:
- Issue: `[work:issue-42]`
- Ad-hoc: `[work:adhoc]` → `[work:pr-N]` after PR creation

---

## Attach Mode (`--attach`)

Join existing PR on current branch, restoring WIP context if available.

1. **Check for WIP checkpoint**: Look for `<wip-checkpoint-restored>` tags from session start
2. Get PR info: `gh pr view --json number,title,state`
3. Determine identifier from PR body (`Fixes #N` → `issue-N`, otherwise `pr-N`)
4. Fetch recent `wip_progress` events for this session: `mcp__event-bus__get_events(channel: "session:<session-id>", limit: 5)`
5. Determine position (from WIP events, PR state, CI state)
6. Create remaining todos only, starting from last known position

---

## Starting New Work

### 1. Check for Active Session

If incomplete `[work:*]` todos exist, block new work.

### 2. Parse Input

- Number → `issue-N`
- GitHub URL → extract issue number
- Other → `adhoc`

### 3. Fetch Context

For issues: `mcp__github__get_issue()` for title, body, labels.

### 4. Derive Initial Tasks

ultrathink: Break down into 2-6 implementation tasks (imperative form).

### 5. Present Scope

```markdown
## Proposed Work Scope

**Source:** #42 - Fix authentication timeout
**Identifier:** [work:issue-42]

### Tasks
1. <task 1>
2. <task 2>

### Checkpoints
- /pr-review local → /pr-create → /watch-ci → /pr-review remote → merge → reflect
```

Ask: Start work / Modify scope / Cancel

### 6. Guided Development (Optional)

Ask: **Yes, explore first (Recommended)** / No, proceed directly

Skip only if: already explored this session, ≤3 files, no architectural decisions, unambiguous requirements.

**If Yes:**

1. **Explore**: Launch 2-3 `feature-dev:code-explorer` agents targeting different aspects
2. **Clarify**: Ask user about ambiguities, edge cases, scope
3. **Architect**: Launch 2-3 `feature-dev:code-architect` agents for different approaches, present trade-offs, get user choice
4. **Document**: Use `EnterPlanMode` to document chosen approach
5. **Derive Tasks**: Replace initial tasks with refined ones

### 7. Create Todos

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

### 8. Broadcast & Begin

Publish `task_started` with your session_id (from startup: "Registered on event bus as: <session_id>"):

```
mcp__event-bus__publish_event(
  event_type: "task_started",
  payload: "Starting work on #<issue> - <title>",
  session_id: "<your-session-id>",
  channel: "repo:<repo_name>"
)
```

Mark first task `in_progress`.

---

## WIP State Checkpointing

To preserve context across session compaction, checkpoint progress to the event bus:

**When to checkpoint:** After completing any significant todo, or before long-running operations.

**How to checkpoint:**
```
mcp__event-bus__publish_event(
  event_type: "wip_progress",
  payload: "[work:<ID>] Completed: <task>. In progress: <next_task>. Remaining: <count>",
  session_id: "<your-session-id>",
  channel: "session:<your-session-id>"
)
```

**On session resume after compaction:** Check `<wip-checkpoint-restored>` tags in session start for previous state.

---

## Checkpoint Handling

**Run /pr-review local**: Run, fix issues if found, loop until clean.

**Create PR**: Run `/pr-create`. If adhoc, update remaining todos to `[work:pr-N]`.

**Monitor CI**: Run `/watch-ci <PR#>` in background.

**Process feedback**: Wait for CI, run `/pr-review remote`. If changes pushed, reset CI and feedback checkpoints, loop.

**Confirm merge**: Spawn summarize-work agent to show what's being merged:
- `Task(subagent_type="summarize-work", prompt="Summarize work on this PR for merge review")`

**Always** ask user via AskUserQuestion (Merge now / Wait). Never auto-merge. After merge:

```
mcp__event-bus__publish_event(
  event_type: "task_completed",
  payload: "Merged PR #<N> - <title>",
  session_id: "<your-session-id>",
  channel: "repo:<repo_name>"
)
```

**Cleanup WIP state** (optional, prevents stale checkpoints):
```
mcp__event-bus__publish_event(
  event_type: "wip_cleared",
  payload: "[work:<ID>] Work completed - merged PR #<N>",
  session_id: "<your-session-id>",
  channel: "session:<your-session-id>"
)
```

Suggest `/commit-commands:clean_gone`.

**Reflect**: Answer: What was hard? What caused friction? Where did user redirect? What would help?
- Publish insights to event bus with session_id (e.g., `gotcha_discovered`, `pattern_found`)
- Spawn improve-workflow agent: `Task(subagent_type="improve-workflow", prompt="Analyze this session for workflow improvements")`

---

## Error Handling

| Error | Response |
|-------|----------|
| Issue not found | Check the number |
| Active work exists | Complete or clear first |
| Checkpoint failed | Add fix tasks, retry |
