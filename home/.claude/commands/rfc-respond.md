---
argument-hint: <issue-number | URL> [--post]
description: Respond to RFC-style issues with structured analysis
---

# RFC Respond

Respond to existing RFC-style issues with structured analysis.

## Usage

```
/rfc-respond <issue-number | URL> [--post]
```

- `--post`: Auto-post without confirmation
- If no arguments: Infer from PR body, active `[work:N]` todo, or recent conversation

---

## Instructions

Launch the `rfc-respond` agent to handle research, drafting, and posting.

### 1. Gather Context

Before launching, collect from the current conversation:
- **Issue**: Number, URL, or "infer" if not specified
- **Learnings**: Relevant discoveries from current work
- **Context**: What prompted this response

### 2. Launch Agent

`Task(subagent_type="rfc-respond", prompt="Respond to RFC [issue]. Learnings: [discoveries]. Context: [current work]. Flags: $ARGUMENTS")`

### 3. Report Result

When the agent completes, share its summary with the user:
- Issue responded to (number, title, URL)
- Key points from the response
- Any follow-up actions identified
