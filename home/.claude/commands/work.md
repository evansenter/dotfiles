---
argument-hint: <issue-number | URL | "description" | --attach>
description: Workflow-aware task execution with checkpoints
---

# Work

Execute tasks with explicit workflow checkpoints: [guided development] → develop → `/pr-review local` → `/pr-create` → `/watch-ci` → `/pr-review remote` → merge → reflect.

Guided development (optional) runs exploration agents, asks clarifying questions, and designs architecture before implementation.

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

### 4. Derive Initial Tasks

ultrathink to break down into 2-6 implementation tasks. Use imperative form.

These are preliminary tasks. If user opts into guided development (step 6), these will be refined or replaced based on deeper codebase exploration.

### 5. Present Scope for Review

Before creating todos or broadcasting, present the scope to the user:

```
## Proposed Work Scope

**Source:** <issue reference OR ad-hoc description>
**Identifier:** [work:<identifier>]

### Initial Tasks (may be refined during guided development)
1. <task 1>
2. <task 2>
...

### Checkpoints
- Run /pr-review local
- Create PR with /pr-create
- Monitor CI with /watch-ci
- Process feedback with /pr-review remote
- Confirm merge with user (always asks via AskUserQuestion)
- Reflect with /improve-workflow

Proceed?
```

**Source formats:**
- Issue: `#42 - Fix authentication timeout`
- Ad-hoc: `"Add dark mode support"` (user's description)

Use `AskUserQuestion` with options:
- **Start work** - Proceed to guided development question
- **Modify scope** - Adjust tasks before starting
- **Cancel** - Abort without creating todos

Only proceed to step 6 if user approves.

### 6. Guided Development (Optional)

After user approves the scope, ask if they want guided development:

Use `AskUserQuestion`:
- **Yes, explore and architect first** - Launch exploration agents, ask clarifying questions, design architecture with agents, then document plan before implementing
- **No, proceed directly** - Skip to implementation

**Default to "Yes"** - the cost of exploration is usually worth it, especially since issues/RFCs may be stale and designs benefit from fresh review.

**Only recommend "No" if ALL of these are true:**
- You've already read the relevant code in this session
- The change touches ≤3 files
- No architectural decisions to make (clear, mechanical change)
- Requirements are unambiguous (user provided detailed spec or it's obvious)

**When skipping, justify it to the user:**
```
Recommending we skip guided development because:
- I've already explored [relevant area] earlier in this session
- This is a focused change to [N files]
- No architectural decisions needed - [brief reason]
```

If any doubt, use guided development. Catching design issues early saves rework.

If user selects **"Yes"**, proceed through the Guided Development Phases below. The initial tasks from step 4 will be refined or replaced based on what you learn.

If user selects **"No"**, skip to step 7 "Create Todos" using the initial tasks from step 4.

---

#### Guided Development Phases

These phases run when user opts in to guided development. They build deep codebase understanding and produce a documented architecture plan that replaces the initial task breakdown.

##### Phase 1: Codebase Exploration

**Goal**: Understand relevant existing code and patterns

Launch 2-3 code-explorer agents in parallel using the Task tool with `subagent_type="feature-dev:code-explorer"`. Each agent should:
- Target a different aspect: similar features, architecture/abstractions, integration points
- Trace through code comprehensively
- Return 5-10 key files to read

**Example prompts:**
- "Find features similar to [feature] and trace their implementation"
- "Map the architecture and abstractions for [feature area]"
- "Identify integration points and dependencies for [feature]"

After agents return, read all identified files to build deep understanding.

##### Phase 2: Clarifying Questions

**Goal**: Resolve all ambiguities before designing

**CRITICAL**: Do not skip this phase.

Review exploration findings + issue details. Identify:
- Edge cases and error handling
- Integration points and dependencies
- Scope boundaries and backward compatibility
- Performance requirements

Present questions to user in an organized list. Wait for answers before proceeding.

If user says "whatever you think is best", provide your recommendation and get explicit confirmation.

##### Phase 3: Architecture Design

**Goal**: Design multiple approaches with trade-offs

Launch 2-3 code-architect agents in parallel using the Task tool with `subagent_type="feature-dev:code-architect"`. Each agent should focus on a different approach:
- **Minimal changes**: Smallest change, maximum reuse
- **Clean architecture**: Maintainability, elegant abstractions
- **Pragmatic balance**: Speed + quality

Review all approaches and form your opinion on which fits best.

Present to user:
- Brief summary of each approach
- Trade-offs comparison table
- Your recommendation with reasoning

Ask user which approach they prefer.

##### Phase 4: Document Architecture Plan

**Goal**: Create formal plan artifact with chosen architecture

Use `EnterPlanMode` to document:
- Key files to modify/create
- Implementation sequence
- Decisions made from clarifying questions
- Chosen architecture approach

Use `ExitPlanMode` when plan is complete. User reviews and approves the documented plan.

##### Phase 5: Derive Final Tasks

Based on the architecture plan, derive the final implementation tasks. These replace the initial tasks from step 4.

Proceed to step 7 "Create Todos" with these refined tasks.

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
[work:${ID}] Reflect with /improve-workflow
```

### 8. Broadcast & Begin

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

### Confirm merge with user

1. Mark `in_progress`
2. **REQUIRED**: Use `AskUserQuestion` to confirm merge:
   - Options: "Merge now", "Wait" (do not proceed without explicit approval)
   - Never auto-merge, even if CI passes and PR is approved
3. If user selects "Merge now": `gh pr merge --squash`
4. If user selects "Wait": Keep checkpoint `in_progress`, inform user they can resume later
5. Broadcast `task_completed`
6. Mark `completed`
7. Suggest: `/commit-commands:clean_gone`

### Reflect with /improve-workflow

1. Mark `in_progress`
2. **Reflect on the work** - Answer these questions:

   **Difficulty**: Rate Easy / Medium / Hard and explain why. What was harder than expected?

   **Friction points**: What slowed you down?
   - Missing permissions or tooling?
   - Unclear or poorly documented code?
   - Inadequate test coverage or examples?
   - External dependencies or API limitations?

   **User steering**: Where did the user need to correct or redirect you?
   - Misunderstanding requirements?
   - Wrong approach or architecture?
   - Missing context you should have gathered?

   **Suggested improvements**: What would make this easier?
   - Codebase changes (refactoring, documentation, tests)
   - Tooling additions (new commands, agents, permissions)
   - Workflow tweaks (process changes, new checkpoints)

3. **Publish insights** to event bus:
   - `gotcha_discovered` - Non-obvious issues others should know
   - `pattern_found` - Useful patterns worth sharing
   - Include repo context so insights are findable via `/learnings`

4. Run `/improve-workflow` to generate data-driven suggestions
5. Mark `completed`

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
