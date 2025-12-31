---
argument-hint: <issue-number | URL | "description"> | resume
description: Workflow-aware task execution with checkpoints
---

# Work

Execute tasks with explicit workflow checkpoints, ensuring the development flow is followed (develop, `/pr local`, `/pr create`, `/watch-ci`, `/pr remote`).

## Usage

```
/work <issue-number | URL | "description">
/work resume
```

- `issue-number`: GitHub issue number to work on (e.g., `42`)
- `URL`: Full GitHub issue URL
- `"description"`: Ad-hoc task description in quotes
- `resume`: Resume the current work session from existing todo state

## Instructions

Parse the input argument:

```bash
ARG="$1"
```

---

### Mode: Resume

If `ARG` is `resume`:

1. **Check for existing todos**:
   - Read the current todo list
   - Filter to todos with `[work:*]` prefix pattern (ignore non-work todos)
   - If no `[work:*]` todos exist, inform user: "No active work session. Start one with `/work <issue-number>` or `/work \"description\"`"

2. **Extract issue context**:
   - Parse the issue number or `adhoc` from the `[work:N]` prefix
   - For issue-based work, optionally fetch issue title for display

3. **Display current state**:
   ```markdown
   ## Work Session Status: #42 - Add dark mode toggle

   **Completed:**
   - [x] [work:42] Implement: Add validation function
   - [x] [work:42] Implement: Update tests

   **In Progress:**
   - [ ] [work:42] Checkpoint: Run /pr local before pushing

   **Remaining:**
   - [ ] [work:42] Checkpoint: Create PR with /pr create
   - [ ] [work:42] Checkpoint: Monitor CI with /watch-ci
   - [ ] [work:42] Checkpoint: Process feedback with /pr remote
   - [ ] [work:42] Checkpoint: Merge when approved
   ```

4. **Continue from current task**: Pick up from the first incomplete `[work:*]` item.

---

### Mode: Start New Work

#### 1. Check for Existing Work Session

Before starting new work, check if there's already an active `/work` session:
- Read current todo list
- Look for todos with `[work:*]` prefix pattern (indicates active `/work` session)
- If incomplete `[work:*]` todos exist, inform user with the existing issue context:
  ```
  Active work session exists for issue #<N>. Use `/work resume` to continue, or complete current work first.
  ```
- Exit without creating new todos
- Note: Other todos without `[work:*]` prefix don't block new work (including subagent todos)
- Note: Multi-session support (concurrent work on different issues) is out of scope; any `[work:*]` todos block new work

#### 2. Parse Input Type

Determine input type:
- If `ARG` matches `^[0-9]+$`: Issue number
- If `ARG` contains `github.com`: Issue URL - extract number with:
  ```bash
  ISSUE_NUMBER=$(echo "$ARG" | grep -oE '[0-9]+$')
  if [[ -z "$ISSUE_NUMBER" ]]; then
    echo "Could not extract issue number from URL: $ARG"
    exit 1
  fi
  ```
- Otherwise: Ad-hoc description

#### 3. Fetch Issue Details (if applicable)

For issue-based work, use MCP to fetch issue details:

```
mcp__github__get_issue(owner: "<owner>", repo: "<repo>", issue_number: <number>)
```

Get owner/repo from:
```bash
REPO_INFO=$(gh repo view --json owner,name -q '.owner.login + "/" + .name')
OWNER="${REPO_INFO%%/*}"
REPO="${REPO_INFO##*/}"
```

**Error handling**:
- If MCP unavailable, fall back to: `gh issue view "${ISSUE_NUMBER}" --json title,body,labels`
- If issue not found, inform user: `Issue #<number> not found. Check the issue number and try again.`
- If repo can't be determined, inform user: `Could not determine repository. Ensure you're in a git directory with a GitHub remote.`

Extract from response:
- Title
- Body (for context on requirements)
- Labels (for categorization)

For ad-hoc work, use the provided description.

#### 4. Derive Implementation Tasks

ultrathink: Analyze the issue body or description to identify discrete implementation tasks.

**Guidelines for task derivation:**
- Break down into logical, completable units
- Each task should be independently verifiable
- Don't over-decompose (aim for 2-6 implementation tasks)
- Use imperative form: "Add X", "Update Y", "Fix Z"

**Example for issue "Add dark mode toggle":**
```
- Implement: Add toggle component to settings
- Implement: Create dark mode CSS variables
- Implement: Wire up state management
- Implement: Add tests for toggle behavior
```

#### 5. Create Work Plan with TodoWrite

Use TodoWrite to create the full work plan with both implementation tasks AND workflow checkpoints:

```json
{
  "todos": [
    {"content": "[work:${ISSUE}] Implement: <task 1>", "status": "pending", "activeForm": "Implementing <task 1>"},
    {"content": "[work:${ISSUE}] Implement: <task 2>", "status": "pending", "activeForm": "Implementing <task 2>"},
    {"content": "[work:${ISSUE}] Checkpoint: Run /pr local before pushing", "status": "pending", "activeForm": "Running /pr local before pushing"},
    {"content": "[work:${ISSUE}] Checkpoint: Create PR with /pr create", "status": "pending", "activeForm": "Creating PR with /pr create"},
    {"content": "[work:${ISSUE}] Checkpoint: Monitor CI with /watch-ci", "status": "pending", "activeForm": "Monitoring CI with /watch-ci"},
    {"content": "[work:${ISSUE}] Checkpoint: Process feedback with /pr remote", "status": "pending", "activeForm": "Processing feedback with /pr remote"},
    {"content": "[work:${ISSUE}] Checkpoint: Merge when approved", "status": "pending", "activeForm": "Merging when approved"}
  ]
}
```

Where `${ISSUE}` is:
- The issue number for issue-based work (e.g., `[work:42]`)
- `adhoc` for ad-hoc work without an issue number (e.g., `[work:adhoc]`)

#### 6. Display Work Plan

Output the full plan for user visibility:

```markdown
## Work Plan: #42 - Add dark mode toggle

**Implementation Tasks:**
- [ ] [work:42] Implement: <task 1>
- [ ] [work:42] Implement: <task 2>

**Workflow Checkpoints:**
- [ ] [work:42] Checkpoint: Run /pr local before pushing
- [ ] [work:42] Checkpoint: Create PR with /pr create
- [ ] [work:42] Checkpoint: Monitor CI with /watch-ci
- [ ] [work:42] Checkpoint: Process feedback with /pr remote
- [ ] [work:42] Checkpoint: Merge when approved

Starting work on first task...
```

#### 7. Begin Implementation

Mark the first task as `in_progress` and start working on it.

---

### Checkpoint Handling

When reaching a checkpoint:

#### Checkpoint: Run /pr local

1. Mark checkpoint as `in_progress`
2. Run `/pr local` to execute local code analysis
3. If issues found, add new implementation tasks to fix them
4. When clean, mark checkpoint as `completed`

#### Checkpoint: Create PR with /pr create

1. Mark checkpoint as `in_progress`
2. Run `/pr create` to commit changes and create/update PR
3. Note the PR number from output (can retrieve later with `gh pr view --json number -q .number`)
4. Mark checkpoint as `completed`

#### Checkpoint: Monitor CI with /watch-ci

1. Mark checkpoint as `in_progress`
2. Execute: `/watch-ci <PR#>` (runs in background)
3. Mark checkpoint as `completed` (monitoring continues in background)

#### Checkpoint: Process feedback with /pr remote

1. Mark checkpoint as `in_progress`
2. Wait for CI to pass (check via `gh pr checks`)
3. Execute: `/pr remote` to fetch and process reviewer comments
4. If changes made:
   - Add new `[work:${ISSUE}] Checkpoint: Run /pr local before pushing` todo (for the iteration)
   - Add new `[work:${ISSUE}] Checkpoint: Push and re-run CI` todo
   - Work through these new checkpoints before returning here
5. When approved or no feedback, mark checkpoint as `completed`

#### Checkpoint: Merge when approved

1. Mark checkpoint as `in_progress`
2. Check PR status: `gh pr view --json state,reviewDecision`
3. If approved, ask user: "PR is approved. Merge now?"
4. If user confirms, merge: `gh pr merge --squash`
5. Mark checkpoint as `completed`
6. Suggest cleanup: "Run `/commit-commands:clean_gone` to remove stale branches"

---

### Skipping Checkpoints

If user wants to skip a checkpoint:

1. Ask for confirmation: "Skip `/pr local`? This may miss issues before pushing."
2. If confirmed, mark checkpoint as `completed` with note
3. Continue to next item

---

### Error Handling

**No issue found:**
```
Issue #42 not found. Check the issue number and try again.
```

**Already have active work:**
```
Active work session exists for issue #<N>. Use `/work resume` to continue, or complete/abandon current work first.
```

**Checkpoint failed:**
- Don't auto-mark as complete
- Add diagnostic tasks to fix the issue
- Retry checkpoint after fixes

---

## Output Format

### Starting Work
```markdown
## Starting Work: #42 - Add dark mode toggle

**Source:** https://github.com/owner/repo/issues/42
**Labels:** enhancement, UI

### Implementation Tasks
1. [work:42] Implement: Add toggle component to settings
2. [work:42] Implement: Create dark mode CSS variables
3. [work:42] Implement: Wire up state management
4. [work:42] Implement: Add tests for toggle behavior

### Workflow Checkpoints
5. [work:42] Checkpoint: Run /pr local before pushing
6. [work:42] Checkpoint: Create PR with /pr create
7. [work:42] Checkpoint: Monitor CI with /watch-ci
8. [work:42] Checkpoint: Process feedback with /pr remote
9. [work:42] Checkpoint: Merge when approved

---

Starting with task 1: Add toggle component to settings...
```

### Resuming Work
```markdown
## Resuming Work: #42 - Add dark mode toggle

**Progress:** 3/9 complete

### Completed
- [x] [work:42] Implement: Add toggle component to settings
- [x] [work:42] Implement: Create dark mode CSS variables
- [x] [work:42] Implement: Wire up state management

### Current
- [ ] [work:42] Implement: Add tests for toggle behavior

### Remaining
- [ ] [work:42] Checkpoint: Run /pr local before pushing
- [ ] [work:42] Checkpoint: Create PR with /pr create
- [ ] [work:42] Checkpoint: Monitor CI with /watch-ci
- [ ] [work:42] Checkpoint: Process feedback with /pr remote
- [ ] [work:42] Checkpoint: Merge when approved

---

Continuing with: Add tests for toggle behavior...
```
