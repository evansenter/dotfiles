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

### Contradictions
- Same action described differently in different places
- Conflicting instructions (e.g., "always do X" vs "skip X when...")
- Phase ordering inconsistencies across related commands
- Checkpoint definitions that conflict (e.g., /work vs /pr-review)

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

| Location A | Location B | Contradiction |
|------------|------------|---------------|
| work.md:45 | pr-review.md:20 | Conflicting checkpoint order |

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
