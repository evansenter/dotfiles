---
argument-hint: <local | remote>
description: Review code via local analysis or remote reviewer comments
---

# PR Review

Analyze feedback from local analysis or remote GitHub reviewers.

## Key Principle

You have context on the work's purpose that automated reviewers lack. Include your opinion in each question, but let the user make the final call.

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
Skill(pr-review-toolkit:code-reviewer)
```

### 3. Check Coverage Gaps

Analyze the diff for untested code paths. For each new/modified source file:

1. **Extract functions** - Identify new/modified functions (detect by language patterns)
2. **Find tests** - Check if corresponding test file exists and contains tests for those functions
3. **Detect user-facing** - Look for CLI flags, commands, public exports
4. **Verify examples** - Check for usage examples in README, examples/, or docs

**Severity:**
- **Critical** - Security-sensitive code (auth, validation, permissions) without tests
- **Important** - New public function without tests; new user-facing feature without example
- **Suggestion** - Modified function with incomplete coverage; private helpers without tests

### 4. Run Examples (if applicable)

For significant changes, run examples with debug logging (check CLAUDE.md for flags like `LOUD_WIRE=1`). Log output to `/tmp/` and share location with user for optional inspection. Flag issues found.

**Skip if:** Documentation-only changes.

### 5. Security Spot-Check

Check if the diff touches security-sensitive patterns:

```bash
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~1
```

Flag for extra scrutiny if changed files match:
- Auth/crypto: `*auth*`, `*crypt*`, `*token*`, `*secret*`, `*password*`, `*credential*`
- User input: `*handler*`, `*endpoint*`, `*route*`, `*api*`, `*input*`, `*form*`
- Config: `*.env*`, `*config*`, `*settings*`, `Dockerfile`, `docker-compose*`
- Dependencies: `*.lock`, `*lockfile*`, `Cargo.toml`, `package.json`, `requirements*.txt`, `Gemfile`

If any match, scan those files specifically for:
- Hardcoded secrets or API keys
- Missing input validation
- Unsafe deserialization
- SQL/command injection vectors
- Overly permissive CORS/permissions

Report as Critical or Important findings. Skip this step for documentation-only changes.

### 6. If Clean

"No issues found. Ready to create PR? Run `/pr-create`"

---

## Mode: `remote`

### 1. Get PR Info

```bash
PR_NUM=$(gh pr view --json number -q .number)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

### 2. Fetch Comments

```
mcp__github__get_pull_request_comments(owner, repo, pull_number)  # inline code comments
mcp__github__get_pull_request_reviews(owner, repo, pull_number)   # review summaries
gh api "repos/${REPO}/issues/${PR_NUM}/comments"                  # general PR conversation
```

**Important:** An APPROVED review can still have inline suggestions. Always check `get_pull_request_comments` for inline comments even when the review verdict is APPROVE. Present any suggestions found — they're non-blocking but the user should see them before merging.

**If no feedback found (no reviews, no inline comments, no PR comments):** "No reviewer feedback found. PR is ready for merge or awaiting review." Exit early.

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
- [Scope creep, architectural decisions, security - reference specific files]

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

Continue until ALL items have answers, including Suggestions.

### 7. Act on Decisions

For **Implement** decisions, use `superpowers:receiving-code-review` before making changes. This ensures you verify the reviewer's suggestion is technically correct and won't introduce regressions — don't blindly implement feedback.

- **Implement**: Verify via receiving-code-review, then fix
- **Skip**: Note and move on
- **Defer**: Create GitHub issue with appropriate label:
  - `priority:high` - Blocks other work, critical bug
  - `priority:medium` - Important but not urgent
  - `priority:low` - Nice to have, backlog
  - Run `gh label list` first. Prefer existing labels.
- **Elaborate**: Explain, then re-ask same question

---

## Post-Processing

### 8. Post Resolution Comment to PR

```markdown
## Feedback Addressed

### Implemented
- [Critical] item - how fixed

### Skipped
- [Suggestion] item - reason

### Deferred
- [Suggestion] item - tracked in #N
```

Only include sections with items. Also reply to inline PR comments explaining what was done or answering questions.

### 9. Broadcast (remote only)

Publish `feedback_addressed` to event bus.

### 10. Final Steps

**Local**: If fixes made, run `/pr-review local` again.

**Remote** (if fixes were made):
1. Run quality gates (linter, formatter, tests)
2. Commit with message referencing feedback addressed
3. Push changes
4. Run `/watch-ci` — this auto-triggers another `/pr-review remote` cycle when CI completes

