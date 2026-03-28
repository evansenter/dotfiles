---
argument-hint: <start|list|cleanup> [branch-name] [base-branch]
description: Manage git worktrees for parallel PR development
---

# Parallel Work

Manage git worktrees for parallel PR development.

## Usage

```
/parallel-work start <branch-name> [base-branch]
/parallel-work list
/parallel-work cleanup
```

---

## Subcommand: `start`

Create a new worktree and branch for parallel development.

### 1. Setup

```bash
BRANCH_NAME="$2"
BASE_BRANCH="${3:-main}"
REPO_ROOT=$(git rev-parse --show-toplevel)
WORKTREE_DIR="$REPO_ROOT/.worktrees"
```

Check if worktree or branch already exists. If branch exists without worktree, ask user preference.

### 2. Create Worktree

```bash
mkdir -p "$WORKTREE_DIR"
git fetch origin "$BASE_BRANCH"
git worktree add -b "$BRANCH_NAME" "$WORKTREE_DIR/$BRANCH_NAME" "origin/$BASE_BRANCH"
```

### 3. Extract Context

Before asking questions, analyze current conversation for:
- Decisions made, constraints discovered
- Relevant code locations
- Related PRs/issues

Summarize into "Context from Parent Session".

### 4. Gather Task Details

**Issue Detection:** Extract issue number from branch name if present:
```
# Patterns to detect: issue-317, issue-317-foo, fix-317, feat-317, etc.
DETECTED_ISSUE=$(echo "$BRANCH_NAME" | grep -oE '(issue|fix|feat|feature|bug|refactor|ci)-([0-9]+)' | grep -oE '[0-9]+' | head -1)
```

Ask user via AskUserQuestion:
- What task will the new session work on?
- Issue number to track? (if detected: show as default, else "None")
- Special instructions?

**Issue question options:**
- If `DETECTED_ISSUE`: `["$DETECTED_ISSUE (detected)", "None - no issue tracking"]`
- If no detection: `["None - no issue tracking"]`
- Always allow "Other" for manual entry

Store result as `ISSUE_NUMBER` (empty string if "None" selected).

### 5. Write Context File

Write `.parallel-context.md` to the new worktree:

```markdown
# Parallel Work Context

## Task
[User's task description]

## Branch Info
- **Branch:** [branch-name]
- **Base:** [base-branch]
- **Issue:** [#ISSUE_NUMBER or "None"]
- **Created:** [timestamp]

## Context from Parent Session
[Extracted context]

---
**Session Start:** This session will auto-launch with the appropriate workflow.
```

### 6. Launch Session

Check if zellij is available. Ask user:
- New zellij tab (Recommended)
- New zellij pane
- Manual

For zellij options:
```bash
# Tab (default):
zellij action new-tab --cwd "[worktree-path]"
# Pane:
zellij action new-pane --direction right --cwd "[worktree-path]"

# Then launch based on issue (NEW session, not resume):
if [ -n "$ISSUE_NUMBER" ]; then
  # Issue provided - use /work for guided development
  zellij action write-chars "claude '/work $ISSUE_NUMBER'"
  zellij action write 10  # Enter key
else
  # No issue - generic parallel work start
  zellij action write-chars "claude 'ultrathink: Starting parallel work. Read .parallel-context.md for context.'"
  zellij action write 10  # Enter key
fi
```

Broadcast `parallel_work_started` to `repo:<name>` (include issue number if present).

Output summary with location, branch, and tips.

---

## Subcommand: `list`

Show all active worktrees with status.

### 1. Gather Info

```bash
git worktree list --porcelain
gh pr list --state open --limit 20 --json number,headRefName,title,statusCheckRollup
```

For each worktree in `.worktrees/`:
```bash
git -C "$WORKTREE_DIR/<name>" log -1 --format="%cr"
cat "$WORKTREE_DIR/<name>/.parallel-context.md" 2>/dev/null
```

### 2. Determine Purpose

Priority: `.parallel-context.md` Task → PR title → last commit message

### 3. Output

```markdown
## Active Worktrees

| Branch | Purpose | PR | CI | Last Activity |
|--------|---------|----|----|---------------|
| feature-auth | Add user auth | #42 | passing | 2 hours ago |
| fix-bug | Fix parsing error | - | - | 1 day ago |

### Quick Actions
- Open: `cd .worktrees/<branch>`
- Resume session: `cd .worktrees/<branch> && claude --resume`
- Create PR: `/pr-create`
- Cleanup: `/parallel-work cleanup`
```

### Merging PRs in Worktrees

Use the GitHub API:
```bash
gh api repos/{owner}/{repo}/pulls/{number}/merge -X PUT -f merge_method=squash
```

---

## Subcommand: `cleanup`

Remove worktrees for merged or closed PRs.

### 1. Categorize Worktrees

For each worktree, check PR status and uncommitted changes:

- **✓ Merged** - Safe to remove
- **⚠ Closed** - Confirm before removing
- **? No PR** - Check for uncommitted work
- **🚫 Dirty** - Has uncommitted changes
- **Active** - PR still open, don't remove

### 2. Output Summary

Same table format as `list`, with Category column.

### 3. Confirm Removal

Ask per non-empty category:
- Remove merged? (Yes/No)
- Remove closed? (Yes/No)
- Remove no-PR? (Yes/No)
- Remove dirty? (No recommended/Yes delete anyway)

### 4. Execute

```bash
git worktree remove "$WORKTREE_DIR/<branch>" --force
git branch -d "<branch>"  # May fail if not fully merged
```

### 5. Report Results

```markdown
## Cleanup Complete

**Removed:**
- `.worktrees/feature-auth` (branch deleted)

**Kept:**
- `.worktrees/fix-parsing` (PR still open)
```
