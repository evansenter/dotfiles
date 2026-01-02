---
argument-hint:
description: Audit open issues for staleness and relevance
---

Audit all open issues against the current codebase state.

## Steps

### 1. Fetch All Open Issues

Use `mcp__github__list_issues` to get all open issues with their labels, created date, and updated date.

### 2. Deep Analysis of Each Issue

For EACH issue, perform thorough analysis before making any recommendations:

1. **Read the full issue** using `mcp__github__get_issue` to get:
   - Complete issue body (not just title)
   - All comments and discussion
   - Linked PRs or issues mentioned

2. **Verify against codebase** when the issue references specific:
   - Files, functions, or code paths - check if they still exist
   - Bugs or behaviors - verify if the issue is still reproducible
   - Feature requests - check if already implemented
   - Documentation gaps - verify current state

3. **Consider context from comments**:
   - Has there been recent discussion or updates?
   - Are there unresolved questions or blockers mentioned?
   - Has someone claimed the issue or started work?

### 3. Categorize Issues

Based on the deep analysis, categorize each issue:
- **Current**: Accurately describes existing behavior/need (verified against codebase)
- **Needs Update**: Valid but details are stale (e.g., file paths changed)
- **Stale**: No longer relevant, already fixed, or superseded (verified in code)
- **Blocked**: Depends on external factors (mentioned in comments/body)
- **Quick Win**: Low effort, high value (based on scope in body)

### 4. Assess Priority Labels

Every issue MUST have exactly one priority label:
- `priority:high` - Urgent, blocking other work, or critical bug
- `priority:medium` - Important but not urgent
- `priority:low` - Nice to have, backlog items

Base priority on:
- Severity/impact described in the issue body
- How many users/workflows are affected
- Whether it blocks other work (check comments for mentions)
- Age and activity level

**Flag for priority review** if:
- **Missing**: Issue has no `priority:*` label at all
- **Misaligned**: Current priority doesn't match the issue content (e.g., critical bug marked low, trivial enhancement marked high)

### 5. Present Triage Table

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

For each issue, include a brief note explaining the categorization based on your analysis.

### 6. Priority Review Section

After the triage tables, show issues needing priority attention:

```
## Priority Review Needed

### Missing Priority Label

| # | Summary | Current Labels | Suggested Priority | Rationale |
|---|---------|----------------|-------------------|-----------|
| 58 | Add webhook support | enhancement | priority:medium | Useful feature, not blocking |

### Priority May Be Misaligned

| # | Summary | Current Priority | Suggested Priority | Rationale |
|---|---------|-----------------|-------------------|-----------|
| 43 | Data loss on crash | priority:low | priority:high | Critical bug affecting data integrity |
| 51 | Update copyright year | priority:high | priority:low | Trivial change, not user-impacting |
```

For each flagged issue, explain:
- **Why** the current priority (or lack thereof) seems wrong
- **What** priority you recommend based on the issue content
- **Evidence** from the issue body/comments supporting your assessment

### 7. Tag Summary View

After the priority review, show tag statistics:

```
## Tag Summary

| Tag | Count |
|-----|-------|
| priority:high | 3 |
| priority:medium | 5 |
| priority:low | 2 |
| (no priority) | 2 |
| bug | 4 |
| enhancement | 6 |
```

Note: Include a "(no priority)" row if any issues are missing priority labels.

### 8. Recommendations

For each issue, provide specific recommendations with rationale:

```
## Recommendations

### #42: Fix auth bug
- **Category**: Stale
- **Evidence**: Checked `src/auth.ts:45` - the bug was fixed in PR #38
- **Action**: Close with comment explaining fix
- **Priority**: N/A (closing)

### #56: Add Python permissions
- **Category**: Quick Win
- **Evidence**: Just needs 3 lines in settings.json, no dependencies
- **Action**: Implement
- **Priority**: priority:low (nice-to-have, not blocking)
- **Labels to add**: quick-win, priority:low
```

$ARGUMENTS

## Output

Present the full triage for review before making any changes. After approval:
1. Add missing priority labels to flagged issues
2. Update misaligned priority labels (remove old, add new)
3. Close stale issues with explanation (reference the evidence)
4. Create any new labels needed
5. Update issue bodies/comments if details are stale
