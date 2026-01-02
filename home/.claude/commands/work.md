---
argument-hint: <issue-number | URL | "description" | --attach>
description: Workflow-aware task execution with checkpoints
---

# Work

Execute tasks with explicit workflow checkpoints: develop → `/pr-review local` → `/pr-create` → `/watch-ci` → `/pr-review remote` → merge → reflect.

## Usage

```
/work <issue-number | URL | "description">
/work --attach
```

## Work Identifiers

All todos use a `[work:ID]` prefix for tracking:

| Input | Identifier | Example |
|-------|------------|---------|
| Issue number | `issue-<N>` | `[work:issue-42]` |
| Ad-hoc (no issue) | `adhoc` → `pr-<N>` | `[work:adhoc]` then `[work:pr-118]` |
| Attach to PR | `issue-<N>` or `pr-<N>` | `[work:pr-118]` |

**Note:** Ad-hoc work starts as `adhoc` but transitions to `pr-<N>` after PR creation.

---

## Attach Mode (`--attach`)

Join an existing PR on the current branch, skipping completed checkpoints.

### 1. Detect PR

```bash
gh pr view --json number,title,state,headRefName 2>/dev/null
```

If no PR: `No PR found. Use /work <issue-number> to start new work, or /pr-create first.`

### 2. Determine Identifier

Check PR body for issue references (`Fixes #N`, `Closes #N`, `Resolves #N`):
- Found → `issue-<N>`
- Not found → `pr-<number>`

### 3. Determine Position

| State | Completed |
|-------|-----------|
| PR exists, CI not started | Implementation, pr-review local, pr-create |
| PR exists, CI passed | Above + watch-ci |
| PR exists, approved | Above + pr-review remote |

### 4. Create Remaining Todos

Only add checkpoints not yet completed. Display resume plan showing what's done and what remains.

---

## Starting New Work

### 1. Check for Active Session

Look for incomplete `[work:*]` todos. If found:
```
Active work session exists. Complete current work first, or clear todos to start fresh.
```

**Notes:**
- Other todos without `[work:*]` prefix don't block (including subagent todos)
- Multi-session support is out of scope; any `[work:*]` todos block new work

### 2. Parse Input

- Matches `^[0-9]+$` → Issue number → identifier: `issue-<N>`
- Contains `github.com` → Extract issue number from URL → identifier: `issue-<N>`
- Otherwise → Ad-hoc description → identifier: `adhoc`

### 3. Fetch Context

For issues: `mcp__github__get_issue()` or `gh issue view` to get title, body, labels.

For ad-hoc: Use the provided description.

### 4. Derive Tasks

ultrathink to break down into 2-6 implementation tasks. Use imperative form.

### 5. Present Plan for Review

Before creating todos or broadcasting, present the plan to the user:

```
## Proposed Work Plan

**Source:** <issue reference OR ad-hoc description>
**Identifier:** [work:<identifier>]

### Implementation Tasks
1. <task 1>
2. <task 2>
...

### Checkpoints
- Run /pr-review local
- Create PR with /pr-create
- Monitor CI with /watch-ci
- Process feedback with /pr-review remote
- Merge when approved
- Reflect with /improve-workflow

Proceed with this plan?
```

**Source formats:**
- Issue: `#42 - Fix authentication timeout`
- Ad-hoc: `"Add dark mode support"` (user's description)

Use `AskUserQuestion` with options:
- **Start work** - Create todos and begin
- **Modify plan** - Adjust tasks before starting
- **Cancel** - Abort without creating todos

Only proceed to step 6 if user approves.

### 6. Create Todos

```
[work:${ID}] Implement: <task 1>
[work:${ID}] Implement: <task 2>
[work:${ID}] Checkpoint: Run /pr-review local
[work:${ID}] Checkpoint: Create PR with /pr-create
[work:${ID}] Checkpoint: Monitor CI with /watch-ci
[work:${ID}] Checkpoint: Process feedback with /pr-review remote
[work:${ID}] Checkpoint: Merge when approved
[work:${ID}] Checkpoint: Reflect with /improve-workflow
```

### 7. Broadcast & Begin

```
mcp__event-bus__publish_event(event_type: "task_started", payload: "Started work on...", channel: "repo:<name>")
```

Mark first task `in_progress` and begin.

---

## Checkpoint Handling

### Run /pr-review local

1. Mark `in_progress`
2. Run `/pr-review local`
3. If issues found → add fix tasks, loop back
4. When clean → mark `completed`

### Create PR with /pr-create

1. Mark `in_progress`
2. Run `/pr-create`
3. **If identifier was `adhoc`**: Update ALL remaining todos from `[work:adhoc]` to `[work:pr-<N>]`
4. Mark `completed`

### Monitor CI with /watch-ci

1. Mark `in_progress`
2. Run `/watch-ci <PR#>` (background)
3. Mark `completed`

### Process feedback with /pr-review remote

1. Mark `in_progress`
2. Wait for CI to pass
3. Run `/pr-review remote`
4. **If changes pushed**:
   - Reset "Monitor CI" to `pending`
   - Reset this checkpoint to `pending`
   - Loop back
5. When no more changes → mark `completed`

### Merge when approved

1. Mark `in_progress`
2. Ask user: "Merge now?"
3. If confirmed: `gh pr merge --squash`
4. Broadcast `task_completed`
5. Mark `completed`
6. Suggest: `/commit-commands:clean_gone`

### Reflect with /improve-workflow

1. Mark `in_progress`
2. Run `/improve-workflow`
3. Mark `completed`

---

## Skipping Checkpoints

1. Confirm with user
2. Mark `completed` with note
3. Continue

---

## Error Handling

| Error | Response |
|-------|----------|
| Issue not found | `Issue #N not found. Check the number.` |
| Active work exists | `Active session exists. Complete or clear first.` |
| Checkpoint failed | Add fix tasks, retry after fixes |
