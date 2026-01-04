---
argument-hint: <local | remote>
description: Review code via local analysis or remote reviewer comments
---

# PR Review

Analyze feedback from local analysis or remote GitHub reviewers.

## Usage

```
/pr-review local   # Self-review before pushing
/pr-review remote  # Process reviewer comments after CI
```

---

## Mode: `local`

### 1. Summarize Changes

```bash
git diff --stat HEAD~1 2>/dev/null || git diff --stat main...HEAD
```

Output 2-3 sentence summary.

### 2. Run Analysis

```
Skill(pr-review-toolkit:review-pr)
```

### 3. Check Coverage Gaps

- **Tests**: New public APIs without tests? Missing edge cases?
- **Examples**: New user-facing features without examples?

### 4. Run Examples (if applicable)

For significant changes, run examples with debug logging (check CLAUDE.md for flags like `LOUD_WIRE=1`). Flag issues found.

### 5. If Clean

"No issues found. Ready to create PR? Run `/pr-create`"

---

## Mode: `remote`

### 1. Get PR Info

```bash
PR_NUM=$(gh pr view --json number -q .number)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

### 2. Fetch Comments

```bash
gh api "repos/${REPO}/pulls/${PR_NUM}/comments"
gh api "repos/${REPO}/pulls/${PR_NUM}/reviews"
gh api "repos/${REPO}/issues/${PR_NUM}/comments"
```

### 3. Filter Resolved Items

Check for previous "Feedback Addressed" comments. Don't re-present items already marked Implemented/Skipped/Deferred.

---

## Shared: Categorize and Present

### 4. Form Opinions

ultrathink: For each item:
- Classify: Critical / Important / Suggestion
- Form opinion: Agree / Disagree / Uncertain
- Note reasoning

### 5. Display Summary

```markdown
## [Local Analysis / PR Feedback] Summary

### What This PR Does
[2-3 sentences]

### Feedback Themes
- [Theme 1]
- [Theme 2]

### Areas Requiring Human Attention
- [Scope creep, architectural decisions, security]

### Detailed Findings

#### #1. [Critical] `file.rs:42`
> Feedback text
**Opinion**: Agree - reasoning
```

### 6. Present via AskUserQuestion

One question per item. Batch max 4 at a time.

Options: Implement (Recommended if agree) / Skip / Defer / Elaborate

### 7. Act on Decisions

- **Implement**: Fix immediately
- **Skip**: Note and move on
- **Defer**: Create GitHub issue with priority label
- **Elaborate**: Explain, then re-ask same question

---

## Post-Processing

### 8. Post Resolution Comment

```markdown
## Feedback Addressed

### Implemented
- [Critical] item - how fixed

### Skipped
- [Suggestion] item - reason

### Deferred
- [Suggestion] item - tracked in #N
```

### 9. Broadcast (remote only)

Publish `feedback_addressed` to event bus.

### 10. Final Steps

**Local**: If fixes made, run `/pr-review local` again.

**Remote**: Run quality gates, commit, push, `/pr-review local`, `/watch-ci`.
