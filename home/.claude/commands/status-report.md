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
# Open PRs
gh pr list --state open --json number,title,body

# Open issues
gh issue list --state open --json number,title,body,labels
```

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
**Open PRs** (N total)
| PR | Summary |
|----|---------|
| #N | One-sentence summary of what this PR does |

**Open Issues** (N total)
| Issue | Summary | Labels |
|-------|---------|--------|
| #N    | One-sentence summary of the issue | bug, enhancement |

### Recommendations

Based on the current state, here are suggested next actions:

1. **[Action]** - [Brief reasoning why this is recommended]
2. **[Action]** - [Brief reasoning why this is recommended]
3. **[Action]** - [Brief reasoning why this is recommended]
```

### 4. Recommendation Logic

When making recommendations, consider:
- **Stale PRs**: Open PRs that may need attention (review, merge, or close)
- **Blocked issues**: Issues with "blocked" labels
- **Issue patterns**: If many similar issues exist, suggest consolidation
- **Momentum**: If recent work focused on a feature area, suggest continuing there
- **Quick wins**: Small issues or PRs that could be resolved easily

Each recommendation should include a brief reason explaining why it's suggested based on the data gathered.
