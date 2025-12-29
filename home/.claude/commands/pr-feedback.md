---
argument-hint: [PR_NUMBER] [--local | --remote]
description: Process PR review feedback with categorization and opinion-forming
---

# PR Feedback Review

Process and respond to PR review feedback with critical thinking.

## Usage

```
/pr-feedback [PR_NUMBER] [--local | --remote]
```

- If PR_NUMBER is omitted, uses the current branch's PR.
- **Default**: Run both local analysis AND fetch remote comments in parallel
- `--local`: Only run local analysis (via `/pr-review-toolkit:review-pr`)
- `--remote`: Only fetch remote comments from external reviewers
- If both `--local` and `--remote` are specified, runs both (same as default)

## Instructions

### 1. Run Analysis

**Default (both)**: In parallel:
- Spawn `/pr-review-toolkit:review-pr` skill for local code analysis
- Fetch remote review comments (step 2 below)

**--local only**: Run `/pr-review-toolkit:review-pr` and skip remote fetching.

**--remote only**: Skip local analysis and proceed directly to fetching remote comments.

### 2. Fetch Review Comments (unless --local)

```bash
# Get PR number if not provided
PR_NUM="${1:-$(gh pr view --json number -q .number 2>/dev/null)}"

# Get owner/repo from current directory
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# Fetch all review comments
gh api repos/$REPO/pulls/$PR_NUM/comments
gh api repos/$REPO/pulls/$PR_NUM/reviews
gh api repos/$REPO/issues/$PR_NUM/comments
```

If no feedback is found, inform the user and exit early.

### 3. Categorize and Form Opinions

For each piece of feedback:

1. **Classify severity**: Critical / Important / Suggestion
2. **Form opinion**: Agree, Disagree, or Uncertain
3. **Note reasoning**: Why you think this way given context

### 4. Display Summary

Before presenting interactive questions, output ALL feedback items ordered by severity (Critical → Important → Suggestion):

```markdown
## PR Feedback Summary

#### #1. [Critical] `notify.sh:15` (Remote)
> Fix JSON interface to handle missing fields
**Opinion**: Agree - breaking change needs fix

#### #2. [Important] `bootstrap.sh:42` (Local)
> Validate input before processing
**Opinion**: Agree - defensive programming

#### #3. [Suggestion] `utils.ts:89` (Remote)
> Add error handling for missing PR
**Opinion**: Disagree - edge case, unlikely to occur
```

**Important**: Items MUST be numbered in severity order - all Critical items first, then Important, then Suggestion. The `#N` numbering follows this order.

**Source indicators**: `(Local)` = from pr-review-toolkit, `(Remote)` = from external reviewers

### 5. Present All Items via AskUserQuestion

Present ONE question for EACH item in the PR Feedback Summary, plus the final open-ended question. Do not skip items you think should be skipped—the user makes the final call on every item.

The tool supports 1-4 questions per call, so batch items in groups of up to 4 (prioritize Critical → Important → Suggestion). Collect all responses before acting.

**Critical**: The `header` field MUST use the same `#N` number from the summary. If the summary shows items #2, #5, #7, the question headers must be `#2`, `#5`, `#7` (not renumbered as #1, #2, #3). This ensures users can cross-reference the summary.

```json
{
  "questions": [
    {
      "question": "[Critical] Fix notify.sh JSON interface - Agree, breaking change",
      "header": "#1 JSON fix",
      "options": [
        {"label": "Implement (Recommended)", "description": "Fix it now"},
        {"label": "Skip", "description": "Not worth it"},
        {"label": "Defer", "description": "Create issue for later"},
        {"label": "Elaborate", "description": "Explain this topic, then re-ask"}
      ],
      "multiSelect": false
    },
    {
      "question": "[Suggestion] Add error handling for missing PR - Disagree, edge case",
      "header": "#3 err hand",
      "options": [
        {"label": "Implement", "description": "Fix it now"},
        {"label": "Skip (Recommended)", "description": "Not worth it"},
        {"label": "Defer", "description": "Create issue for later"},
        {"label": "Elaborate", "description": "Explain this topic, then re-ask"}
      ],
      "multiSelect": false
    }
  ]
}
```

Keep options in consistent order (Implement / Skip / Defer / Elaborate) and add "(Recommended)" to your recommended option. Include your opinion in the question text for context.

Always include a final open-ended question: "Any other comments or questions?" with options like "None, proceed" and "Yes, let me add something".

**Important**: Complete ALL questions before taking action. If the user selects "Elaborate" on any item or provides open-ended input that needs discussion, address that first—do not proceed to implementation. Once discussion is complete, re-present all items via AskUserQuestion to confirm final selections before implementing.

### 6. Act on User Decisions

Based on user's choices:
- **Implement**: Fix the item immediately
- **Skip**: Note it was skipped, move on
- **Defer**: Create a GitHub issue with title summarizing the feedback, body containing the original comment and PR link, and appropriate labels
- **Elaborate**: Explain the topic in detail (what it means, why it matters, trade-offs), then re-ask the question

### 7. Push and Re-check

After implementing feedback:
1. Run project quality gates (linter, formatter, tests as defined in CLAUDE.md)
2. Commit with message referencing the feedback addressed
3. Push changes
4. Re-run `/pr-feedback --local` to verify changes are clean

## Key Principle

You have context on the work's purpose that automated reviewers lack. Include your opinion in the question text, but let the user make the final call. Your reasoning helps inform their decision.
