---
argument-hint: [label-filter]
description: Audit open issues for staleness and relevance
---

Audit all open issues against the current codebase state.

## Steps

### 1. Fetch All Open Issues

Use `mcp__github__list_issues` to get all open issues with their labels, created date, and updated date.

### 2. Categorize Issues

For each issue, determine its category:
- **Current**: Accurately describes existing behavior/need
- **Needs Update**: Valid but details are stale
- **Stale**: No longer relevant, already fixed, or superseded
- **Blocked**: Depends on external factors
- **Quick Win**: Low effort, high value

### 3. Assess Priority Labels

Every issue MUST have exactly one priority label:
- `priority:high` - Urgent, blocking other work, or critical bug
- `priority:medium` - Important but not urgent
- `priority:low` - Nice to have, backlog items

Flag any issues missing a priority label or having multiple priority labels.

### 4. Present Triage Table

Display issues grouped by category in table format:

```
## [Category Name]

| # | Summary | Created | Updated | Tags |
|---|---------|---------|---------|------|
| 42 | Fix auth bug | 2024-12-01 | 2024-12-15 | priority:high, bug |
```

- **#**: Issue number (link format: #42)
- **Summary**: Issue title (truncate to ~50 chars if needed)
- **Created**: Creation date (YYYY-MM-DD)
- **Updated**: Last update date (YYYY-MM-DD)
- **Tags**: Comma-separated labels

### 5. Tag Summary View

After the triage tables, show tag statistics:

```
## Tag Summary

| Tag | Count |
|-----|-------|
| priority:high | 3 |
| priority:medium | 5 |
| priority:low | 2 |
| bug | 4 |
| enhancement | 6 |
```

### 6. Priority Gaps

List any issues missing priority labels:

```
## Issues Missing Priority

- #42: Fix auth bug - Suggest: priority:high (blocking)
- #56: Add feature X - Suggest: priority:low (nice to have)
```

$ARGUMENTS

## Output

Present the full triage for review before making any changes. After approval:
1. Apply suggested priority labels
2. Close stale issues with explanation
3. Create any new labels needed
