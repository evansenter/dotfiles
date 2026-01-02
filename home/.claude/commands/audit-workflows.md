---
argument-hint: [focus-area]
description: Audit workflow commands for contradictions and inconsistencies
---

ultrathink: Audit all workflow command files for contradictions, inconsistencies, and ambiguities.

## Scope

Analyze all `.md` files in:
- `~/.claude/commands/` (custom commands)
- `~/.claude/CLAUDE.md` (global workflow guidance)
- Project `CLAUDE.md` files (project-specific guidance)

## Check For

### Contradictions Within a Workflow
- Instructions that conflict with each other in the same file
- Phase ordering that loops or is impossible to follow
- Conditions that can never be satisfied or are always true
- Steps that undo previous steps without explanation

### Contradictions Across Workflows
- Same action described differently in different commands
- Conflicting instructions between related commands (e.g., /work says "always X", /pr-review says "skip X")
- Phase ordering inconsistencies across command groups
- Checkpoint definitions that conflict (e.g., /work vs /pr-review ownership of a step)

### Ambiguities
- Vague instructions that could be interpreted multiple ways
- Missing decision criteria (when to use option A vs B)
- Undefined terms or references to non-existent commands/phases
- Unclear ownership (Claude vs Human) for decisions

### Staleness
- References to commands/phases that no longer exist
- Outdated tool names or MCP server references
- Instructions that contradict current codebase reality
- Dead links or broken references

### Consistency
- Naming conventions (checkpoints, phases, stages)
- Output format inconsistencies across similar commands
- Different terminology for same concepts
- Inconsistent use of AskUserQuestion vs proceeding autonomously

## Related Command Groups

Pay special attention to consistency within these groups:
- **Work flow**: /work, /pr-create, /pr-review, /watch-ci
- **Audits**: /audit-codebase, /audit-tests, /audit-issues, /audit-workflows
- **Coordination**: /parallel-work, /broadcast, /event-bus-status

$ARGUMENTS

## Output

### 1. Present Summary

First, show a brief summary of findings by category:

```markdown
## Audit Summary

- **Critical:** N contradictions found
- **Important:** N ambiguities found
- **Minor:** N staleness/consistency issues found
```

### 2. Process Findings Interactively

Present findings in batches of 1-4 via AskUserQuestion, starting with Critical issues.

For each finding, include:
- The issue with file:line references
- Your recommended fix
- Your opinion on severity/importance

```json
{
  "questions": [
    {
      "question": "#1 [Critical]: work.md:45 ↔ work.md:120 - Phase 3 requires X but Phase 5 says skip X. Fix: Add condition. (My take: This causes real confusion)",
      "header": "#1",
      "options": [
        {"label": "Implement (Recommended)", "description": "Fix it now"},
        {"label": "Skip", "description": "Not worth fixing"},
        {"label": "Defer", "description": "Create issue for later"}
      ],
      "multiSelect": false
    },
    {
      "question": "#2 [Important]: improve-workflow.md:45 - Unclear when to ask friction question. Fix: Add criteria. (My take: Causes inconsistent behavior)",
      "header": "#2",
      "options": [
        {"label": "Implement (Recommended)", "description": "Fix it now"},
        {"label": "Skip", "description": "Not worth fixing"},
        {"label": "Defer", "description": "Create issue for later"}
      ],
      "multiSelect": false
    }
  ]
}
```

### 3. Act on Choices

For each finding based on user's choice:
- **Implement**: Fix it immediately, then continue
- **Skip**: Note it was skipped, move on
- **Defer**: Create a GitHub issue with the finding details

### 4. Final Summary

After processing all findings:

```markdown
## Audit Complete

**Implemented:** N fixes applied
**Skipped:** N issues
**Deferred:** N issues created

[List of changes made and issues created]
```
