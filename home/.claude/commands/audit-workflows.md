---
argument-hint: [focus-area]
description: Audit workflow commands for contradictions and inconsistencies
---

ultrathink: Audit all workflow command files for contradictions, inconsistencies, and ambiguities.

## Scope

Analyze `.md` files in `~/.claude/commands/`, `~/.claude/CLAUDE.md`, and project `CLAUDE.md` files.

## Check For

**Contradictions** (within/across files): Conflicting instructions, impossible phase ordering, steps that undo previous steps, checkpoint ownership conflicts.

**Ambiguities**: Vague instructions, missing decision criteria, undefined references, unclear Claude vs Human ownership.

**Staleness**: References to non-existent commands, outdated tool/MCP names, instructions contradicting codebase reality.

**Consistency**: Naming conventions, output formats, terminology, AskUserQuestion vs autonomous patterns.

## Related Command Groups

- **Work flow**: /work, /pr-create, /pr-review, /watch-ci
- **Audits**: /audit-codebase, /audit-tests, /audit-issues, /audit-workflows
- **Coordination**: /parallel-work, /broadcast, /event-bus-status

$ARGUMENTS

## Output

### 1. Summary

```markdown
## Audit Summary

- **Critical:** N contradictions
- **Important:** N ambiguities
- **Minor:** N staleness/consistency issues
```

### 2. Process Interactively

Present findings in batches (1-4) via AskUserQuestion, starting with Critical.

For each: file:line reference, recommended fix, severity opinion.

Options: Implement (Recommended) / Skip / Defer

### 3. Act on Choices

- **Implement**: Fix immediately
- **Skip**: Note and move on
- **Defer**: Create GitHub issue

### 4. Final Summary

Report: N implemented, N skipped, N deferred (with issue links).
