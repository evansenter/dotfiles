---
argument-hint: <start|list|cleanup> [branch-name] [base-branch]
description: Manage git worktrees for parallel PR development
---

# Parallel Work

Manage git worktrees for parallel PR development, enabling multiple Claude sessions to work on different features simultaneously.

## Usage

```
/parallel-work start <branch-name> [base-branch]
/parallel-work list
/parallel-work cleanup
```

### Subcommands

- **start**: Create a new worktree for parallel development
- **list**: Show all active worktrees with status
- **cleanup**: Remove worktrees for merged/closed PRs

## Instructions

Parse the subcommand from the first argument:

```bash
SUBCOMMAND="$1"
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_DIR="$REPO_ROOT/.worktrees"
```

If `SUBCOMMAND` is empty or not one of `start`, `list`, `cleanup`, display usage and exit:

```
Usage: /parallel-work <start|list|cleanup> [args]

  start <branch> [base]  - Create new worktree for parallel development
  list                   - Show active worktrees with PR/CI status
  cleanup                - Remove worktrees for merged/closed PRs
```

---

### Subcommand: `start`

Create a new worktree and branch for parallel development.

#### 1. Parse Arguments

```bash
BRANCH_NAME="$2"
BASE_BRANCH="${3:-main}"
```

If `BRANCH_NAME` is empty, display usage and exit:
```
Usage: /parallel-work start <branch-name> [base-branch]
```

#### 2. Check for Existing Worktree or Branch

```bash
# Check if worktree already exists
ls "$WORKTREE_DIR/$BRANCH_NAME" 2>/dev/null

# Check if branch already exists in repo
git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"
```

If worktree exists, inform user and suggest using `/parallel-work list`.
If branch exists (but no worktree), ask if user wants to create worktree for existing branch or choose a different name.

#### 3. Create Worktree Directory and Branch

```bash
# Create .worktrees directory if needed
mkdir -p "$WORKTREE_DIR"

# Fetch latest from remote
git fetch origin "$BASE_BRANCH"

# Create worktree with new branch
git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR/$BRANCH_NAME" "origin/$BASE_BRANCH"
```

#### 4. Extract Context from Current Conversation

Before asking user questions, analyze the current conversation for relevant context to include in the new session:

- **Decisions made**: Any architectural or implementation choices discussed
- **Constraints discovered**: Limitations, requirements, or gotchas found
- **Code locations**: Key files, functions, or patterns identified
- **Dependencies**: Related PRs, issues, or features this work connects to

Summarize this into a "Context from Parent Session" section.

#### 5. Gather Additional Context from User

Use AskUserQuestion to gather task details:

```json
{
  "questions": [
    {
      "question": "What task will the new session work on?",
      "header": "Task",
      "options": [
        {"label": "Describe task", "description": "I'll provide a task description"}
      ],
      "multiSelect": false
    },
    {
      "question": "Any related issues or PRs to reference? (Enter numbers like #123, #456)",
      "header": "Related",
      "options": [
        {"label": "None", "description": "No related issues or PRs"},
        {"label": "Specify", "description": "I'll provide issue/PR numbers"}
      ],
      "multiSelect": false
    },
    {
      "question": "Any special instructions for the new session?",
      "header": "Instructions",
      "options": [
        {"label": "Standard workflow", "description": "Follow normal development flow"},
        {"label": "Custom", "description": "I'll provide specific instructions"}
      ],
      "multiSelect": false
    }
  ]
}
```

#### 6. Write Context File

Write `.parallel-context.md` to the new worktree. When writing, replace placeholders with actual values and execute the date command to get current timestamp:

```markdown
# Parallel Work Context

## Task
[User's task description]

## Branch Info
- **Branch:** [branch-name]
- **Base:** [base-branch]
- **Created:** [run: date '+%Y-%m-%d %H:%M' and insert result]

## Related
[Issue/PR references or "None"]

## Context from Parent Session
[Extracted context from step 4]
- Key decisions: ...
- Constraints: ...
- Relevant files: ...
- Dependencies: ...

## Instructions
[Special instructions or "Follow standard workflow"]

---
**Session Start:** Read this file for context, then begin work.
```

#### 7. Tmux Integration (if available)

Check if running inside tmux:

```bash
echo "$TMUX"
```

If `$TMUX` is set (non-empty), offer to auto-launch a new session:

```json
{
  "questions": [
    {
      "question": "How would you like to start the new Claude session?",
      "header": "Launch",
      "options": [
        {"label": "New tmux pane (Recommended)", "description": "Split current window, stay in view"},
        {"label": "New tmux window", "description": "Separate window in this session"},
        {"label": "Manual", "description": "I'll open it myself"}
      ],
      "multiSelect": false
    }
  ]
}
```

Based on user selection:

**For pane:**
```bash
# Create horizontal split, cd to worktree, and start claude
tmux split-window -h -c "[full-worktree-path]"
tmux send-keys "claude 'Starting parallel work on $BRANCH_NAME. Read .parallel-context.md for context.'" Enter
```

**For window:**
```bash
# Create new window, cd to worktree, and start claude
tmux new-window -c "[full-worktree-path]" -n "$BRANCH_NAME"
tmux send-keys "claude 'Starting parallel work on $BRANCH_NAME. Read .parallel-context.md for context.'" Enter
```

After launching, output:
```markdown
## Worktree Created

**Location:** `.worktrees/[branch-name]`
**Branch:** [branch-name] (based on [base-branch])

✓ Claude session started in new tmux [pane/window].

### Tips
- Each worktree is an independent working directory
- Commits go to their respective branches
- Use `/parallel-work list` from main repo to see all active work
- When done, create PR and run `/parallel-work cleanup`
```

#### 8. Manual Instructions (if not in tmux or user chose manual)

If `$TMUX` is not set, or user selected "Manual", output:

```markdown
## Worktree Created

**Location:** `.worktrees/[branch-name]`
**Branch:** [branch-name] (based on [base-branch])

### Start a New Claude Session

Open a new terminal and run:

\`\`\`bash
cd [full-worktree-path]
claude "Starting parallel work. Read .parallel-context.md for context from the parent session."
\`\`\`

### Tips
- Each worktree is an independent working directory
- Commits go to their respective branches
- Use `/parallel-work list` from main repo to see all active work
- When done, create PR and run `/parallel-work cleanup`
```

---

### Subcommand: `list`

Show all active worktrees with their status.

#### 1. Gather Worktree Information

Run these commands in parallel:

```bash
# Get all worktrees
git worktree list --porcelain

# Get open PRs with branch and CI status
gh pr list --state open --json number,headRefName,baseRefName,title,statusCheckRollup

# Get current directory to identify if in a worktree
pwd
```

#### 2. For Each Worktree in `.worktrees/`

```bash
# Get branch name
git -C "$WORKTREE_DIR/<name>" branch --show-current

# Get dirty status (count of changed files)
git -C "$WORKTREE_DIR/<name>" status --short | wc -l

# Get last commit time
git -C "$WORKTREE_DIR/<name>" log -1 --format="%cr"
```

#### 3. Cross-Reference with PRs

Match worktree branches to open PRs by `headRefName`. Extract:
- PR number and state
- CI status from `statusCheckRollup`

#### 4. Output Format

```markdown
## Active Worktrees

| Branch | PR | CI | Status | Last Activity |
|--------|----|----|--------|---------------|
| feature-auth | #42 Open | passing | clean | 2 hours ago |
| fix-parsing | #45 Open | running | 1 modified | 30 min ago |
| refactor-api | - | - | clean | 3 days ago |

### Legend
- **PR**: Pull request number and state, or `-` if none
- **CI**: passing/failing/running/pending, or `-` if no PR
- **Status**: clean or N modified files
- **Last Activity**: Time since last commit

### Quick Actions
- **Open worktree:** `cd .worktrees/<branch>`
- **Create PR:** In worktree, run `/commit-commands:commit-push-pr`
- **Cleanup merged:** `/parallel-work cleanup`
```

If no worktrees exist in `.worktrees/`:

```markdown
## Active Worktrees

No parallel worktrees found in `.worktrees/`.

### Create One
\`\`\`
/parallel-work start <branch-name> [base-branch]
\`\`\`
```

---

### Subcommand: `cleanup`

Remove worktrees for merged or closed PRs.

#### 1. List Worktrees and Check PR Status

```bash
# List all worktrees in .worktrees/
ls "$WORKTREE_DIR"

# For each branch, check PR status
gh pr list --head "<branch>" --state all --json number,state,mergedAt,closedAt
```

#### 2. Categorize Worktrees

Group into categories:
- **Merged**: PR was merged (safe to remove)
- **Closed**: PR was closed without merge (confirm)
- **No PR**: No PR exists (warn - may have uncommitted work)
- **Open**: PR still open (do not remove)

Also check for uncommitted changes in each worktree:
```bash
git -C "$WORKTREE_DIR/<branch>" status --short
```

#### 3. Display Summary

```markdown
## Worktree Cleanup

### Safe to Remove (PR Merged)
| Branch | PR | Merged |
|--------|-----|--------|
| feature-auth | #42 | 2 days ago |

### Requires Confirmation (PR Closed Without Merge)
| Branch | PR | Closed |
|--------|-----|--------|
| abandoned-feature | #38 | 1 week ago |

### Warning: No PR Found
| Branch | Status | Last Commit |
|--------|--------|-------------|
| local-experiment | clean | 5 days ago |

### ⚠️ Dirty Worktrees (Uncommitted Changes)
| Branch | Modified Files |
|--------|----------------|
| wip-feature | 3 files |

**Warning**: These worktrees have uncommitted changes that will be lost if removed.

### Active (Will Not Remove)
| Branch | PR | Status |
|--------|-----|--------|
| fix-parsing | #45 Open | running |
```

#### 4. Filter Empty Categories

Only include categories in the confirmation that have at least one worktree. Skip questions for empty categories entirely.

#### 5. Confirm Removal

For each **non-empty** category, use AskUserQuestion to confirm:

```json
{
  "questions": [
    {
      "question": "Remove worktrees with merged PRs?",
      "header": "Merged",
      "options": [
        {"label": "Yes, remove all", "description": "Clean up merged branches"},
        {"label": "No, keep", "description": "Skip this category"}
      ],
      "multiSelect": false
    },
    {
      "question": "Remove worktrees with closed (unmerged) PRs?",
      "header": "Closed",
      "options": [
        {"label": "Yes, remove", "description": "PR was closed without merge"},
        {"label": "No, keep", "description": "May want to reopen"}
      ],
      "multiSelect": false
    },
    {
      "question": "Remove worktrees with no PR? (Check for uncommitted work first)",
      "header": "No PR",
      "options": [
        {"label": "Yes, reviewed", "description": "Nothing to keep"},
        {"label": "No, keep", "description": "Need to review first"}
      ],
      "multiSelect": false
    },
    {
      "question": "⚠️ Remove DIRTY worktrees? This will DELETE uncommitted changes permanently!",
      "header": "Dirty",
      "options": [
        {"label": "No, keep (Recommended)", "description": "Preserve uncommitted work"},
        {"label": "Yes, delete anyway", "description": "I understand changes will be lost"}
      ],
      "multiSelect": false
    }
  ]
}
```

**Note**: Only ask about dirty worktrees if any exist. The "No, keep" option should be recommended by default to prevent accidental data loss.

#### 6. Execute Removal

For each confirmed removal:

```bash
# Remove worktree
git worktree remove "$WORKTREE_DIR/<branch>" --force

# Try to delete branch (only succeeds if fully merged)
git branch -d "<branch>"
```

Track whether the branch deletion succeeded or failed to report accurately in the output.

#### 7. Output Results

Report actual outcomes for each worktree:

```markdown
## Cleanup Complete

**Removed:**
- `.worktrees/feature-auth` (branch deleted)
- `.worktrees/abandoned-feature` (branch kept - not fully merged)

**Kept:**
- `.worktrees/local-experiment` (user choice)
- `.worktrees/fix-parsing` (PR still open)

Run `/parallel-work list` to see remaining worktrees.
```
