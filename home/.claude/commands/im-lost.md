---
description: Show workflow position, feedback staleness, and suggested next action
---

# I'm Lost

Show current workflow position and context when you've lost track of where you are.

## Instructions

Gather state and present a concise orientation summary.

### 1. Gather State

Run these commands in parallel:

```bash
# Current branch
git branch --show-current

# Uncommitted changes
git status --short

# Recent commits on this branch (vs main)
git log main..HEAD --oneline 2>/dev/null || git log -3 --oneline

# Check for open PR on current branch (includes linked issue)
gh pr view --json number,title,state,statusCheckRollup,reviewDecision,comments,body 2>/dev/null

# Check active todos
# (Read from conversation context)
```

Parse the PR body for issue references (e.g., "Fixes #123", "Closes #45", or issue URLs). If found, fetch the linked issue including labels:

```bash
gh issue view <issue-number> --json title,labels
```

### 2. Determine Workflow Position

Based on gathered state, identify the current step:

| State | Workflow Step |
|-------|---------------|
| On main, no changes | 1-2: Orient/Pick work |
| On branch, uncommitted changes | 3: Develop |
| On branch, committed, no PR | 4-6: Self-review/Iterate/Create PR |
| PR open, CI running | 7: Monitor CI |
| PR open, CI passed, has unaddressed comments | 8: Process feedback |
| PR open, CI passed, no comments | 9: Ready to merge |
| PR open, CI failed | Fix CI failures |
| PR merged, on main | 10: Reflect (run /improve-workflow) |

### 3. Output Format

Present in this format:

```markdown
## Where You Are

**Branch:** [branch-name]
**Status:** [uncommitted changes summary or "clean"]
**PR:** [#N - title (CI status, N comments)] or "none"
**Issue:** [#N - title] or "none"
**Labels:** priority:high, bug, ... *(or "none" if no linked issue)*

### Workflow Position

1. ○ Orient - `/status-report`
2. ○ Start work - `/work`
3. ○ Develop
4. ○ Self-review - `/pr-review local`
5. ○ Iterate
6. ○ Create PR - `/pr-create`
7. ○ Monitor CI - `/watch-ci`
8. ○ Process feedback - `/pr-review remote`
9. ○ Merge & cleanup
10. ○ Reflect - `/improve-workflow`

← YOU ARE HERE: [Step N - brief explanation of why]

### Context

[2-3 sentences summarizing recent work based on branch name, commits, PR description, and linked issue if any. Reference the issue number when describing what problem is being solved.]

### Suggested Next Action

[One concrete action to take, with the command to run if applicable. If working on an issue, frame the action in terms of completing that issue.]
```

### 4. Guidelines

- Keep output concise - this is for quick orientation
- Use ● for current step, ○ for others
- If on main with no changes, suggest running `/status-report` to find work
- If stuck between steps, pick the earlier one
- Reference active todos if any exist in the conversation
- If working on an issue, always mention the issue number in Context and Suggested Next Action
- Always show all labels from the linked issue (helps surface priority at a glance)
