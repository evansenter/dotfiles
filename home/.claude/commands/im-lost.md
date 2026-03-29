---
description: Show workflow position, feedback staleness, and suggested next action
---

# I'm Lost

Show current workflow position and context when you've lost track.

## Instructions

### 1. Gather State (parallel)

```bash
git branch --show-current
git status --short
git log main..HEAD --oneline 2>/dev/null || git log -3 --oneline
gh pr view --json number,title,state,statusCheckRollup,reviewDecision,comments,body 2>/dev/null
```

If PR body references an issue (`Fixes #N`), fetch it: `gh issue view <N> --json title,labels`

### 2. Determine Position

| State | Step |
|-------|------|
| On main, no changes | Orient/Pick work |
| On branch, uncommitted | Develop |
| Committed, no PR | Self-review → Create PR |
| PR open, CI running, no comments | Monitor CI |
| PR open, has comments | Process feedback (independent of CI status) |
| PR open, CI passed, no comments, review done | Ready to merge |
| PR open, CI failed | Fix failures (review can proceed in parallel) |
| PR merged | Reflect (improve-workflow agent) |

### 3. Output

```markdown
## Where You Are

**Branch:** [name]
**Status:** [changes or "clean"]
**Context:** [low/moderate/high if available, otherwise omit]
**PR:** [#N - title (CI status)] or "none"
**Issue:** [#N - title] or "none"
**Labels:** [priority, type, etc.]

### Workflow Position

1. ○ Orient - status-report agent
2. ○ Start work - `/work`
3. ○ Develop
4. ○ Self-review - `/pr-review local`
5. ○ Iterate
6. ○ Create PR - `/pr-create`
7. ○ Monitor CI - `/watch-ci`
8. ○ Process feedback - `/pr-review remote`
9. ○ Merge & cleanup
10. ○ Reflect - improve-workflow agent

← YOU ARE HERE: [Step N - why]

### Context
[2-3 sentences summarizing recent work, referencing issue if any]

### Suggested Next Action
[One concrete action with command]
```

Use ● for current step, ○ for others. Reference issue number in Context and Suggested Next Action when applicable.
