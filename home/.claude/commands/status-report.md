---
description: Generate repo status with recent work, open issues, and recommendations
---

# Status Report

Generate a status report for the current repository.

## Instructions

When this skill is invoked, gather information and produce a summary:

### 1. Recent Completed Work

Fetch recently closed PRs and issues. Show items closed in the last week, but always show at least 3 (going back further if needed).

```bash
# Recently closed PRs (last week, minimum 3)
gh pr list --state merged --limit 10 --json number,title,body

# Recently closed issues (last week, minimum 3)
gh issue list --state closed --limit 10 --json number,title,body
```

Filter to show:
- All items closed within the last 7 days, OR
- At least 3 most recently closed items (whichever gives more)

### 2. Work In Flight

```bash
# Active worktrees (in .worktrees/ directory)
git worktree list --porcelain

# Detect if running in a worktree
git rev-parse --git-dir
git rev-parse --git-common-dir

# Open PRs with branch info for cross-referencing
gh pr list --state open --json number,title,body,headRefName,baseRefName,statusCheckRollup

# Open issues
gh issue list --state open --json number,title,body,labels
```

For each worktree in `.worktrees/`:
```bash
# Check dirty status
git -C <worktree-path> status --short
```

To detect if running in a worktree (for marking `(current)`):
- If `git rev-parse --git-dir` differs from `git rev-parse --git-common-dir`, you're in a worktree
- Compare `pwd` with each worktree path to identify which one is current
- Mark the matching worktree with `(current)` in the output table

### 3. Output Format

For each item, generate a one-sentence summary based on the title and body.

Present the report in this format:

```markdown
## Status Report: [repo-name]

### Recently Completed
**Pull Requests**
| PR | Summary |
|----|---------|
| #N | One-sentence summary of what this PR accomplished |

**Issues**
| Issue | Summary |
|-------|---------|
| #N    | One-sentence summary of what was resolved |

### In Flight

**Active Worktrees** (N total) - *only show if worktrees exist in `.worktrees/`*
| Path | Branch | PR | CI | Status |
|------|--------|----|----|--------|
| .worktrees/feature-x (current) | feature-x | #42 | passing | clean |
| .worktrees/fix-bug | fix-bug | #45 | failing | 2 modified |

*Mark with `(current)` if running from that worktree. Cross-reference branches with PRs.*

**Stacked PRs** - *only show if any PR's baseRefName differs from default branch (use `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` to detect)*
| PR | Branch | Base | CI |
|----|--------|------|----|
| #46 | feature-part-2 | feature-part-1 | pending |
| #45 | feature-part-1 | main | passing |

**Open PRs** (N total)
| PR | Summary |
|----|---------|
| #N | One-sentence summary of what this PR does |

**Open Issues** (N total)

*Group issues by priority (high → medium → low → unlabeled):*

| Issue | Summary | Priority | Labels |
|-------|---------|----------|--------|
| #N    | One-sentence summary | priority:high | bug |
| #M    | Another issue summary | priority:medium | enhancement |
| #K    | Low priority issue | priority:low | documentation |
| #J    | Issue without priority | - | question |

**Label Summary**

| Label | Count |
|-------|-------|
| priority:high | N |
| priority:medium | N |
| priority:low | N |
| (no priority) | N |
| bug | N |
| enhancement | N |

*Note: Issues missing priority labels should be triaged with `/audit-issues`.*

### Recommendations

Based on the current state, here are suggested next actions:

1. **Work on #42 (priority:high)** - This high-priority issue has been open for 2 weeks and blocks feature X
2. **Run `/audit-issues`** - 3 issues are missing priority labels, need triage
3. **Clean up orphaned worktree** - `.worktrees/old-feature` has merged PR, run `/parallel-work cleanup`
```

### 4. Event Bus Activity (Optional)

If registered with the event bus, fetch recent events for context on parallel work:

```
mcp__event-bus__get_events(since_id=0, limit=10)
mcp__event-bus__list_sessions()
```

If there are active sessions or recent events, add a section:

```markdown
### Parallel Sessions

**Active Sessions:** N
| Session | Branch | Last Activity |
|---------|--------|---------------|
| dotfiles/issue-48 | issue-48 | 5 min ago |

**Recent Events:**
- [10 min ago] parallel_work_started: Started parallel work on issue-48
- [30 min ago] ci_completed: CI passed on PR #42
```

If not registered with event bus, skip this section.

### 5. Recommendation Logic

When making recommendations, consider and reference specific evidence:

**Priority-based:**
- **High priority issues**: Issues labeled `priority:high` should be addressed first
- **Missing priority labels**: Suggest running `/audit-issues` to triage unlabeled issues

**PR health:**
- **Stale PRs**: Open PRs that may need attention (review, merge, or close)
- **Failed CI in worktrees**: Worktrees with failing CI should be fixed
- **Stacked PR updates**: If a base PR in a stack was updated, dependent PRs may need rebase

**Workflow hygiene:**
- **Dirty worktrees**: Worktrees with uncommitted changes need attention
- **Orphaned worktrees**: Worktrees for merged/closed PRs can be cleaned up with `/parallel-work cleanup`
- **Blocked issues**: Issues with "blocked" labels

**Strategic:**
- **Issue patterns**: If many similar issues exist, suggest consolidation
- **Momentum**: If recent work focused on a feature area, suggest continuing there
- **Quick wins**: Small issues or PRs that could be resolved easily

Each recommendation MUST include:
1. The specific evidence (e.g., "3 issues missing priority labels", "#42 is priority:high")
2. The concrete action to take
3. Brief reasoning why this matters
