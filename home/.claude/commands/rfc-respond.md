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

### 1. Fetch the Issue

```bash
gh issue view "${ISSUE_NUM}" --json title,body,number,comments
```

Read carefully, including linked PRs and existing comments.

### 2. Draft Response

ultrathink: Generate response with:

- **Context/Learnings**: What we learned relevant to this RFC
- **Assumptions**: Table with Confidence and Impact if Wrong
- **Questions**: Why it matters, proposed solutions, what needs confirmation
- **Blocking Decisions**: What blocks progress and why
- **Actionable Requirements**: Table with Owner (Claude/Human) and Blocked By

### 3. Resolve Blocking Questions

Before posting, use AskUserQuestion for blocking decisions (max 4 at a time). Include recommended option first with "(Recommended)" suffix.

### 4. Update and Post

Incorporate decisions, update blocking/requirements sections.

**If `--post`**: Post with `gh issue comment` and broadcast `rfc_responded` to `repo:<name>`.

**Otherwise**: Display and ask if user wants to post.

## Key Principles

- Reference specific code/PRs
- Propose solutions, don't just ask questions
- Resolve blockers interactively before posting
- Separate "needs human decision" from "Claude can proceed"
