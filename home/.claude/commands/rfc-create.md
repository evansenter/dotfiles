---
argument-hint: [--post] [-R owner/repo]
description: Create RFC-style issues with structured analysis
---

# RFC Create

Create RFC-style issues with structured analysis.

## Usage

```
/rfc-create [--post] [-R owner/repo]
```

- `--post`: Auto-create without confirmation
- `-R owner/repo`: Create in different repository

---

## Instructions

### 1. Gather Context

Analyze current conversation for:
- Problem identified
- Relevant code/files
- Decisions already made
- Discovery context (audit, feature work, bug fix)

### 2. Generate RFC Body

ultrathink: Create RFC body:

```markdown
## Summary
[One paragraph]

## Problem / Motivation
[What friction was encountered]

## Context
- **Discovered during**: [context]
- **Relevant files**: [files]
- **Related issues/PRs**: [refs]

## Proposed Solution
[High-level approach]

## Assumptions
| Assumption | Confidence | Impact if Wrong |
|------------|------------|-----------------|

## Open Questions
1. [Needs human decision]

## Actionable Requirements
| # | Requirement | Owner | Blocked By |
|---|-------------|-------|------------|

## Test Requirements
- Unit: [functions to test]
- Integration: [scenarios]
- Edge cases: [specific cases]

## Implementation Checklist
- [ ] [Step 1]
- [ ] [Step 2]
```

### 3. Derive Title

Generate 2-3 title options starting with "RFC: ". Ask user to choose via AskUserQuestion.

### 4. Resolve Blocking Questions

Ask user to confirm problem statement, validate solution direction, answer open questions.

### 5. Determine Labels

```bash
gh label list --json name
```

Required: exactly one `priority:high/medium/low` label. Add relevant type labels.

### 6. Create or Present

**If `--post`**: Create immediately with `gh issue create`.

**Otherwise**: Display draft, ask "Create this RFC?" via AskUserQuestion.

Use `-R` flag if cross-repo target specified.

### 7. Broadcast

```
mcp__event-bus__publish_event(
  event_type: "rfc_created",
  payload: "RFC created: #N in <repo> - <title>",
  channel: "repo:<target>"
)
```

## Key Principles

- Reference specific code/PRs
- Propose solutions, don't just ask questions
- Resolve blockers before creating
- Separate "needs human decision" from "Claude can proceed"
