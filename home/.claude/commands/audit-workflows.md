---
argument-hint: [focus-area]
description: Audit workflow commands for contradictions and inconsistencies
---

# Audit Workflows

Audit workflow commands for contradictions and inconsistencies.

## Usage

```
/audit-workflows [focus-area]
```

- `focus-area`: Optional area to prioritize (e.g., "work flow", "audits", "coordination")

---

## Instructions

Launch the `audit-workflows` agent to handle scanning, analysis, and interactive resolution.

### 1. Launch Agent

`Task(subagent_type="audit-workflows", prompt="Audit workflow commands. Focus: $ARGUMENTS. Repo: [current repo]")`

### 2. Report Result

When the agent completes, share its summary with the user:
- Files analyzed
- Issues found by category
- Actions taken (implemented/skipped/deferred)
- Any patterns worth noting
