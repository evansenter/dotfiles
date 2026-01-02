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

Present findings in priority order:

```
## Critical (Contradictions)

### Within Workflows
| File | Line A | Line B | Contradiction | Suggested Fix |
|------|--------|--------|---------------|---------------|
| work.md | 45 | 120 | Phase 3 requires X, Phase 5 says skip X | Clarify when to skip with condition |

### Across Workflows
| Location A | Location B | Contradiction | Suggested Fix |
|------------|------------|---------------|---------------|
| work.md:45 | pr-review.md:20 | Conflicting checkpoint order | Align on single source of truth in work.md |

## Important (Ambiguities)

| Location | Issue | Suggested Fix |
|----------|-------|---------------|
| work.md:78 | Unclear when to skip phase | Add decision criteria |

## Minor (Staleness/Consistency)

| Location | Issue | Suggested Fix |
|----------|-------|---------------|
| CLAUDE.md:120 | References old command name | Update to current name |
```

After presenting findings, offer to fix issues directly or create GitHub issues for tracking.
