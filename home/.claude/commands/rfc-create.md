---
argument-hint: [--post] [-R owner/repo]
description: Create RFC-style issues with structured analysis
---

# RFC Create

Create new RFC-style issues with structured analysis, blocking question resolution, and optional auto-posting.

## Usage

```
/rfc-create [--post] [-R owner/repo]
```

- `--post`: Automatically create after generating (skips review)
- `-R owner/repo`: Create RFC in a different repository (cross-repo)

## Instructions

### 1. Parse Arguments

From `$ARGUMENTS`, extract:
- `--post`: Auto-post without confirmation
- `-R owner/repo`: Target a different repository

```bash
TARGET_REPO=""  # Empty means current repo
if [[ "$ARGUMENTS" =~ -R[[:space:]]+([^[:space:]]+) ]]; then
  TARGET_REPO="${BASH_REMATCH[1]}"
fi
```

### 2. Gather Context

Analyze the current conversation for:
- **Problem identified**: What issue or improvement was discovered
- **Relevant code**: Files, functions, patterns discussed
- **Decisions made**: Any choices or constraints already established
- **Context**: How was this discovered (audit, feature work, bug fix)

### 3. Generate RFC Issue Body

ultrathink: Create an RFC-style issue body:

```markdown
## Summary

[One-paragraph description of the problem/improvement]

## Problem / Motivation

[What friction or issue was encountered that motivates this RFC]

## Context

- **Discovered during**: [audit/feature work/bug fix/etc.]
- **Relevant files**: [list key files]
- **Related issues/PRs**: [references if any]

## Proposed Solution

[High-level approach]

## Assumptions

| Assumption | Confidence | Impact if Wrong |
|------------|------------|-----------------|
| ... | High/Medium/Low | ... |

## Open Questions

1. [Question that needs human decision]
2. [Another question]

## Actionable Requirements

| # | Requirement | Owner | Blocked By |
|---|-------------|-------|------------|
| 1 | ... | Claude/Human | None |

## Test Requirements

[What test coverage is expected? Leave blank if not applicable]

- Unit tests: [specific functions/modules to test]
- Integration tests: [end-to-end scenarios]
- Edge cases: [specific edge cases to cover]

## Example Requirements

[What examples should demonstrate this feature? Leave blank if not applicable]

- [Example 1: description]
- [Example 2: description]

## Implementation Checklist

- [ ] [First step]
- [ ] [Next step]
- [ ] ...
```

### 4. Derive Title

Based on the RFC content you just drafted, generate 2-3 suggested titles that:
- Start with "RFC: " prefix
- Capture the core problem or proposed change
- Are concise (under 60 characters after the prefix)

Use `AskUserQuestion` to let the user choose or customize:
```json
{
  "questions": [
    {
      "question": "What should the RFC title be?",
      "header": "Title",
      "options": [
        {"label": "RFC: [derived from Summary]", "description": "Based on the problem summary"},
        {"label": "RFC: [derived from Problem]", "description": "Based on the motivation"},
        {"label": "RFC: [alternative]", "description": "Another angle on the issue"}
      ],
      "multiSelect": false
    }
  ]
}
```

The user can select a suggested title or provide their own via "Other".

### 5. Resolve Blocking Questions

Use `AskUserQuestion` to resolve any blocking decisions before creating:
- Confirm the problem statement is accurate
- Validate the proposed solution direction
- Get input on open questions

### 6. Determine Labels

Before creating, fetch available labels and select appropriate ones:

```bash
gh label list --json name,description
```

**Required**: Every RFC MUST have exactly one priority label:
- `priority:high` - Urgent, blocking other work
- `priority:medium` - Important but not urgent
- `priority:low` - Nice to have, backlog

**Additional labels**: Based on the RFC content and available repo labels, add relevant labels such as:
- `enhancement`, `bug`, `documentation` (issue type)
- `blocked` (if waiting on external factors)
- Any domain-specific labels from the repo

### 7. Create or Present

**If `--post` flag is present:**
```bash
# If TARGET_REPO is set, use -R flag
if [ -n "$TARGET_REPO" ]; then
  gh issue create -R "${TARGET_REPO}" --title "${TITLE}" --body "<body>" --label "priority:<level>,<other-labels>"
else
  gh issue create --title "${TITLE}" --body "<body>" --label "priority:<level>,<other-labels>"
fi
```

**Otherwise:**
Display the draft and ask:
```json
{
  "questions": [
    {
      "question": "Create this RFC issue?",
      "header": "Create",
      "options": [
        {"label": "Yes, create it", "description": "Create the issue on GitHub"},
        {"label": "No, just show me", "description": "Review only, don't create"}
      ],
      "multiSelect": false
    }
  ]
}
```

After creating, output the issue URL.

### 8. Broadcast Event

After successfully creating the RFC, broadcast to the event bus so parallel sessions are notified:

```
# Use TARGET_REPO if set, otherwise current repo
target_channel = TARGET_REPO if TARGET_REPO else current_repo_name

mcp__event-bus__publish_event(
  event_type: "rfc_created",
  payload: "RFC created: #<issue_number> in <repo> - <title>",
  channel: "repo:<target_channel>"
)
```

**For cross-repo RFCs**: Broadcasting to the target repo's channel ensures sessions working in that repo are notified and can pick up the RFC.

## Key Principles

- Reference specific code/PRs where relevant
- Propose solutions, don't just ask open-ended questions
- Identify blockers explicitly and resolve them interactively
- Separate "needs human decision" from "Claude can proceed"
- Use AskUserQuestion to get decisions before creating, not after
