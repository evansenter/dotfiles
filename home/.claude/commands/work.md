---
argument-hint: <issue-number | URL | "description" | --attach>
description: Workflow-aware task execution with checkpoints
---

# Work

Execute tasks with checkpoints: [guided development] → develop → `/pr-review local` → `/pr-create` → `/watch-ci` → `/pr-review remote` → merge → reflect.

Guided development (optional) runs exploration agents, asks clarifying questions, and designs architecture before implementation.

## Usage

```
/work <issue-number | URL | "description">
/work --attach
```

## Identifiers

Todos use `[work:ID]` prefix:

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
4. Fetch recent `wip_progress` events for this session: `mcp__event-bus__get_events(channel: "session:<session-id>", limit: 5)`
5. Determine position (from WIP events, or fall back to PR/CI state):

| State | Already Completed |
|-------|-------------------|
| PR exists, CI not started | Implementation, pr-review local, pr-create |
| PR exists, CI passed | Above + watch-ci |
| PR exists, approved | Above + pr-review remote |

6. Create remaining todos only. Display resume plan showing what's done and what remains.

---

## Starting New Work

### 1. Check for Active Session

If incomplete `[work:*]` todos exist, block new work.

**Note:** Other todos without `[work:*]` prefix don't block (including subagent todos).

### 2. Parse Input

- Number → `issue-N`
- GitHub URL → extract issue number
- Other → `adhoc`

### 3. Fetch Context

For issues: `mcp__github__get_issue()` for title, body, labels.

### 4. Derive Initial Tasks

ultrathink: Break down into 2-6 implementation tasks (imperative form).

These are preliminary - if user opts into guided development, they'll be refined.

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

Ask via AskUserQuestion:
- **Start work** - Proceed to guided development question
- **Modify scope** - Adjust tasks before starting
- **Cancel** - Abort without creating todos

### 6. Guided Development (Optional)

Ask: **Yes, explore first (Recommended)** / No, proceed directly

**Default to "Yes"** - the cost of exploration is usually worth it, especially since issues may be stale and designs benefit from fresh review.

**Only skip if ALL of these are true:**
- You've already read the relevant code in this session
- The change touches ≤3 files
- No architectural decisions to make
- Requirements are unambiguous

**When skipping, justify it to the user.**

---

#### Guided Development Phases

##### Phase 1: Explore

Launch 2-3 `feature-dev:code-explorer` agents in parallel, each targeting different aspects:
- "Find features similar to [feature] and trace their implementation"
- "Map the architecture and abstractions for [feature area]"
- "Identify integration points and dependencies"

After agents return, read all identified files to build deep understanding.

##### Phase 2: Clarify

**CRITICAL: Do not skip this phase.**

Review exploration findings + issue details. Identify:
- Edge cases and error handling
- Integration points and dependencies
- Scope boundaries and backward compatibility
- Performance requirements

Present questions to user. Wait for answers before proceeding.

If user says "whatever you think is best", provide your recommendation and get explicit confirmation.

##### Phase 3: Architect

Launch 2-3 `feature-dev:code-architect` agents for different approaches:
- **Minimal changes**: Smallest change, maximum reuse
- **Clean architecture**: Maintainability, elegant abstractions
- **Pragmatic balance**: Speed + quality

Review all approaches and form your opinion on which fits best.

Present to user:
- Brief summary of each approach
- Trade-offs comparison
- Your recommendation with reasoning

Ask which approach they prefer.

##### Phase 4: Document

Use `EnterPlanMode` to document:
- Key files to modify/create
- Implementation sequence
- Decisions made from clarifying questions
- Chosen architecture approach

Use `ExitPlanMode` when complete.

##### Phase 5: Derive Tasks

Based on the architecture plan, derive final implementation tasks. These replace the initial tasks from step 4.

---

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

WIP state is **automatically checkpointed** by the `pre-compact.sh` hook before context compaction.

**Auto-captured:** `[work:ID] | branch | pr: #N | files | time`

**On session resume:** Check `<wip-checkpoint-restored>` tags in session start. Combined with the persisted todo list, this provides enough context to continue work.

---

## Checkpoint Handling

**Run /pr-review local**: Run, fix issues if found, loop until clean.

**Create PR**: Run `/pr-create`. If adhoc, update remaining todos to `[work:pr-N]`.

**Monitor CI**: Run `/watch-ci <PR#>` in background.

**Process feedback**: Wait for CI, run `/pr-review remote`. If changes pushed, reset CI and feedback checkpoints, loop.

**Confirm merge**: Spawn summarize-work agent to show what's being merged:
- `Task(subagent_type="summarize-work", prompt="Summarize work on this PR for merge review")`

When showing the output from summarize-work, always highlight the key files to look at, and the PR URL. Include any other relevant data as well.

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

**Reflect**:
- **Difficulty**: Rate Easy/Medium/Hard. What was harder than expected?
- **Friction**: What slowed you down? (permissions, unclear code, missing tests)
- **User steering**: Where did the user redirect you?
- **Improvements**: What would make this easier?

Publish insights to event bus with session_id (`gotcha_discovered`, `pattern_found`).

Spawn improve-workflow agent: `Task(subagent_type="improve-workflow", prompt="Analyze this session for workflow improvements")`

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
