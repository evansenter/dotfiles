---
argument-hint: [label-filter]
description: Audit open issues for staleness and relevance
---

Audit all open issues against the current codebase state.

Categorize into:
- **Current**: Accurately describes existing behavior/need
- **Needs Update**: Valid but details are stale
- **Stale**: No longer relevant, already fixed, or superseded
- **Blocked**: Depends on external factors
- **Quick Win**: Low effort, high value

For each issue, note what action is needed. For stale issues, draft a closing comment explaining why.

$ARGUMENTS

Output: Present the full triage for my review before making any changes. After approval, suggest any new labels we should create.
