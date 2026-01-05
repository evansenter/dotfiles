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

Output 2-3 sentence summary of what changed and why.

### 2. Run Analysis

```
Skill(pr-review-toolkit:review-pr)
```

### 3. Check Coverage Gaps

**Test coverage:**
- Find new/modified source files, check for corresponding tests
- Flag: new public APIs without tests (Important), missing edge cases (Suggestion)

**Example coverage:**
- Identify user-facing features (new commands, flags, public APIs)
- Flag: new user-facing feature without example (Important)

### 4. Run Examples (if applicable)

For significant changes, run examples with debug logging (check CLAUDE.md for flags like `LOUD_WIRE=1`). Flag issues found.

**Skip if:** Documentation-only changes or no debug flags defined.

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

**If no feedback found:** "No reviewer feedback found. PR is ready for merge or awaiting review." Exit early.

### 3. Filter Resolved Items

Check for previous "Feedback Addressed" comments. Parse to identify items under each section:
- `### Implemented` - Already fixed, do NOT re-present
- `### Skipped` - Intentionally not fixed, do NOT re-present
- `### Deferred` - Tracked in issue, do NOT re-present

Items are bullet points starting with `- [`. Match against new feedback by file path and issue text. Only present NEW feedback.

---

## Shared: Categorize and Present

### 4. Form Opinions

ultrathink: For each item:
- Classify: Critical / Important / Suggestion
- Form opinion: Agree / Disagree / Uncertain
- Note reasoning

Do additional research as needed to form and support your opinion.

### 5. Display Summary

Output ALL findings ordered by severity (Critical > Important > Suggestion):

```markdown
## [Local Analysis / PR Feedback] Summary

### What This PR Does
[2-3 sentences]

### Feedback Themes
- [Theme 1: e.g., "Error handling gaps"]
- [Theme 2: e.g., "Missing input validation"]

### Areas Requiring Human Attention
- [Scope creep, architectural decisions, security]

### Detailed Findings

#### #1. [Critical] `file.rs:42`
> Feedback text
**Opinion**: Agree - reasoning

#### #2. [Important] `api.rs:89`
> Feedback text
**Opinion**: Disagree - reasoning
```

### 6. Present via AskUserQuestion

Present ONE question per item. Use the same number (`#1`, `#2`) in both Detailed Findings and the question's `header` field.

**Batching:** Max 4 questions per call. If >4 items, present first 4, wait for answers, then continue (`#5`, `#6`, etc.).

**Options:**
- Implement (Recommended) - if you agree
- Skip - not worth fixing
- Defer - create issue for later
- Elaborate - explain topic, then re-ask

Make sure "Recommended" aligns with your opinion. If you said "Agree", recommend Implement.

**Elaborate handling:** Explain the topic in detail, then present the SAME question again (same number) for final decision.

Continue until ALL items have answers.

### 7. Act on Decisions

- **Implement**: Fix immediately
- **Skip**: Note and move on
- **Defer**: Create GitHub issue with appropriate label:
  - `priority:high` - Blocks other work, critical bug
  - `priority:medium` - Important but not urgent
  - `priority:low` - Nice to have, backlog
  - Run `gh label list` first. Prefer existing labels.
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

Only include sections with items.

### 9. Broadcast (remote only)

Publish `feedback_addressed` to event bus.

### 10. Final Steps

**Local**: If fixes made, run `/pr-review local` again.

**Remote**:
1. Run quality gates (linter, formatter, tests)
2. Commit with message referencing feedback addressed
3. Push changes
4. Run `/pr-review local` to verify clean
5. Run `/watch-ci` to monitor CI
6. Reshare PR URL to user

---

## Key Principle

You have context on the work's purpose that automated reviewers lack. Include your opinion in each question, but let the user make the final call.
