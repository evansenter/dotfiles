---
argument-hint: <local | remote>
description: Review code via local analysis or remote reviewer comments
---

# PR Review

Analyze and process feedback from local code analysis or remote GitHub reviewers.

## Usage

```
/pr-review <local | remote>
```

- `local`: Run local code analysis via pr-review-toolkit (pre-push self-review)
- `remote`: Fetch and process reviewer comments from GitHub (post-CI)

## Instructions

Parse the mode from the first argument:

```bash
MODE="$1"
```

If `MODE` is empty or not one of `local`, `remote`:

```bash
echo "Usage: /pr-review <local | remote>"
echo "  local  - Run local code analysis (self-review before pushing)"
echo "  remote - Fetch and process reviewer comments (after CI passes)"
exit 1
```

---

## Phase 1: Gather Feedback

### Mode: `local`

#### 1a. Summarize Changes

```bash
git diff --stat HEAD~1 2>/dev/null || git diff --stat main...HEAD
```

**Handle edge cases:**
- **No commits yet**: Use `git diff --stat` (unstaged) or `git diff --cached --stat` (staged)
- **No changes at all**: Inform user: "No changes to analyze. Make changes first."

Output a 2-3 sentence summary of what was changed and why.

#### 2a. Run Analysis

```
Skill(pr-review-toolkit:review-pr)
```

**If no issues found:**
- Inform user: "No issues found. Code looks clean."
- Suggest: "Ready to create PR? Run `/pr-create`"
- Exit early

---

### Mode: `remote`

#### 1b. Get PR Info

```bash
PR_NUM=$(gh pr view --json number -q .number)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

**Handle failures:**
- **Not a git repo**: "Not in a git repository. Navigate to a project directory first."
- **No remote**: "No GitHub remote found. Push your branch first."
- **No PR exists**: "No PR found for this branch. Run `/pr-create` first."

#### 2b. Fetch Review Comments

```bash
gh api "repos/${REPO}/pulls/${PR_NUM}/comments"
gh api "repos/${REPO}/pulls/${PR_NUM}/reviews"
gh api "repos/${REPO}/issues/${PR_NUM}/comments"
```

**If no feedback found:**
- Inform user: "No reviewer feedback found. PR is ready for merge or awaiting review."
- Exit early

#### 3b. Filter Already-Resolved Items

Check for "Feedback Addressed" comments that indicate previously resolved items:

```bash
gh api "repos/${REPO}/issues/${PR_NUM}/comments" --jq '.[] | select(.body | contains("Feedback Addressed")) | .body'
```

Parse these comments to identify items in each section:
- **Implemented** (under `### Implemented`) - Already fixed, do NOT re-present
- **Skipped** (under `### Skipped`) - Intentionally not fixed, do NOT re-present
- **Deferred** (under `### Deferred`) - Tracked in issue, do NOT re-present

Items are bullet points starting with `- [` under each header. Extract the description and match against new feedback by file path and issue text.

Only present NEW feedback not covered by previous "Feedback Addressed" comments. This prevents re-raising issues that have already been handled.

---

## Phase 2: Categorize and Present (Shared)

This phase is identical for both modes.

### 3. Categorize and Form Opinions

ultrathink: For each feedback item:
1. **Classify severity**: Critical / Important / Suggestion
2. **Form opinion**: Agree, Disagree, or Uncertain
3. **Note reasoning**: Why you think this way given context

### 4. Display Summary

Output ALL findings ordered by severity (Critical > Important > Suggestion):

```markdown
## [Local Analysis / PR Feedback] Summary

### What This PR Does
[2-3 sentences summarizing changes and purpose]

### Feedback Themes
- [Theme 1: e.g., "Error handling gaps"]
- [Theme 2: e.g., "Missing input validation"]

### Areas Requiring Human Attention
- [Scope creep concerns]
- [Deviations from codebase patterns]
- [Architectural decisions needing validation]
- [Security-sensitive changes]

---

### Detailed Findings

#### #1. [Critical] `file.rs:42`
> Feedback text here
**Opinion**: Agree - reasoning

#### #2. [Important] `api.rs:89`
> Feedback text here
**Opinion**: Disagree - reasoning
```

### 5. Present via AskUserQuestion

Present ONE question for EACH item, batched in groups of up to 4. Include your opinion in the question text.

```json
{
  "questions": [
    {
      "question": "[Critical] file.rs:42 - Issue description - Agree, reasoning",
      "header": "#1",
      "options": [
        {"label": "Implement (Recommended)", "description": "Fix it now"},
        {"label": "Skip", "description": "Not worth fixing"},
        {"label": "Defer", "description": "Create issue for later"},
        {"label": "Elaborate", "description": "Explain this topic, then re-ask"}
      ],
      "multiSelect": false
    }
  ]
}
```

Always include a final open-ended question for any additional comments.

### 6. Act on User Decisions

- **Implement**: Fix the item immediately
- **Skip**: Note it was skipped, move on
- **Defer**: Create a GitHub issue with appropriate labels:
  - `priority:high` - Blocks other work, critical bug
  - `priority:medium` - Important but not urgent
  - `priority:low` - Nice to have, backlog
  - **Note**: Run `gh label list` first. Prefer existing labels.
- **Elaborate**: Explain the topic, then re-ask

---

## Phase 3: Post-Processing

### 7. Post Feedback Resolution Comment

If a PR exists, post a structured comment summarizing how feedback was addressed:

```bash
PR_NUM=$(gh pr view --json number -q .number 2>/dev/null)
if [ -n "$PR_NUM" ]; then
  gh pr comment "$PR_NUM" --body "$(cat <<'EOF'
## Feedback Addressed

### Implemented
- [Critical/Important] item - how it was fixed

### Skipped
- [Suggestion] item - reason for skipping

### Deferred
- [Suggestion] item - tracked in #issue_number
EOF
)"
fi
```

Only include sections that have items.

### 8. Broadcast (remote mode only)

For `remote` mode, broadcast that feedback was addressed:

```
mcp__event-bus__publish_event(
  event_type: "feedback_addressed",
  payload: "Addressed reviewer feedback on PR #<pr_number>: <N> implemented, <M> skipped, <K> deferred",
  channel: "repo:<repo_name>"
)
```

### 9. Final Steps

**For `local` mode:**
- If fixes were made, run `/pr-review local` again to verify clean

**For `remote` mode:**
1. Run quality gates (linter, formatter, tests)
2. Commit with message referencing feedback addressed
3. Push changes
4. Run `/pr-review local` to verify changes are clean
5. Run `/watch-ci` to monitor CI for the new push

---

## Key Principle

You have context on the work's purpose that automated reviewers lack. Include your opinion in each question, but let the user make the final call.
