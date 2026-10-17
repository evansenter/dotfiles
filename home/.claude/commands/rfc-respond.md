---
argument-hint: [issue-number | URL] [--post]
description: Respond to an RFC-style issue — evaluate the proposal, identify risks, and recommend a direction. Use when asked to review or comment on an existing RFC or design-proposal issue.
---

# RFC Respond

Post a structured response to an existing RFC issue, resolving blocking decisions with the user before posting.

## Usage

```
/rfc-respond [issue-number | URL] [--post]
```

- No issue given: infer it from the current PR's linked issue or an active `[work:N]` task; ask if still unclear
- `--post`: post as soon as blocking decisions are resolved, without a final "Post this response?" confirmation

## Process

### 1. Read the RFC

```bash
gh issue view <N> --json title,body,number,comments,url
```

Read the body, linked PRs (implementation may already be under way), and existing comments — don't repeat what's been said.

### 2. Research

Check the RFC against the code: current implementation state, the patterns it relies on, and blockers or complexity it doesn't mention.

### 3. Draft the Response

ultrathink: Draft the response, proposing solutions rather than only asking questions:

```markdown
## Response to RFC #N

### Context / Learnings
[What we found that bears on this RFC]

### Assumptions
| Assumption | Confidence | Impact if Wrong |
|------------|------------|-----------------|

### Questions
1. **[Question]** - Why it matters: [reason]. Proposed: [solution]. Needs confirmation: [yes/no]

### Blocking Decisions
| Decision | Blocker | Options |
|----------|---------|---------|

### Actionable Requirements
| # | Requirement | Owner (Claude/Human) | Blocked By |
|---|-------------|----------------------|------------|
```

### 4. Resolve Blocking Decisions

Ask about each blocking decision via AskUserQuestion (up to 4 per call), recommended option first with "(Recommended)". Update the Blocking Decisions and Requirements sections with the answers.

### 5. Post

With `--post`, post right away; otherwise show the final response and ask "Post this response?". Use `gh issue comment` with the body via `--body-file -` and a single-quoted heredoc so `[Question]`, parens, and tables aren't shell-evaluated.

Then publish `rfc_responded` (payload: `Responded to RFC #N in <repo>`) to `repo:<name>` with your session_id, and report the issue, the key points, decisions made, and follow-ups.
