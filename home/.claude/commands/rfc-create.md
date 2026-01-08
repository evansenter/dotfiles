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

Launch the `rfc-create` agent to handle research, drafting, and issue creation.

### 1. Gather Context Summary

Before launching, collect from the current conversation:
- **Topic**: The problem or feature being discussed
- **Relevant files**: Any code paths or files mentioned
- **Decisions**: Conclusions already reached
- **Discovery context**: What triggered this RFC (audit, bug, feature work)

### 2. Launch Agent

```
Task(
  subagent_type="rfc-create",
  prompt="Create an RFC for: [topic summary]

    Context from conversation:
    - Problem: [description]
    - Relevant files: [list]
    - Decisions made: [list]
    - Discovered during: [context]

    Flags: $ARGUMENTS"
)
```

### 3. Report Result

When the agent completes, share its summary with the user:
- RFC title and issue URL (if created)
- Key decisions made
- Any follow-up actions
