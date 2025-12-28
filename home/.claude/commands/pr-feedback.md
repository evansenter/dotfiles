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

# Fetch all review comments
gh api repos/{owner}/{repo}/pulls/$PR_NUM/comments
gh api repos/{owner}/{repo}/pulls/$PR_NUM/reviews
gh api repos/{owner}/{repo}/issues/$PR_NUM/comments
```

### 3. Categorize and Form Opinions

For each piece of feedback:

1. **Classify severity**: Critical / Important / Suggestion
2. **Form opinion**: Agree, Disagree, or Uncertain
3. **Note reasoning**: Why you think this way given context

### 4. Present All Items via AskUserQuestion

Use `AskUserQuestion` to get user decisions on ALL feedback items. The tool supports 1-4 questions per call, so batch items in groups of 4 if there are more (prioritize Critical → Important → Suggestion). Act on each batch's decisions before presenting the next group.

```json
{
  "questions": [
    {
      "question": "[Critical] Fix notify.sh JSON interface - Agree, should fix",
      "header": "#1",
      "options": [
        {"label": "Implement", "description": "Fix it now"},
        {"label": "Skip", "description": "Not worth it"},
        {"label": "Defer", "description": "Create issue for later"}
      ],
      "multiSelect": false
    },
    {
      "question": "[Suggestion] Add error handling for missing PR - Disagree, edge case",
      "header": "#2",
      "options": [
        {"label": "Implement", "description": "Fix it now"},
        {"label": "Skip", "description": "Not worth it"},
        {"label": "Defer", "description": "Create issue for later"}
      ],
      "multiSelect": false
    }
  ]
}
```

Include your opinion in the question text so user has context, but let them decide.

Always include a final open-ended question: "Any other comments or questions?" with options like "None, proceed" and "Yes, let me add something".

### 5. Act on User Decisions

Based on user's choices:
- **Implement**: Fix the item immediately
- **Skip**: Note it was skipped, move on
- **Defer**: Create a GitHub issue with title summarizing the feedback, body containing the original comment and PR link, and appropriate labels

### 6. Push and Re-check

After implementing feedback:
1. Run project quality gates (linter, formatter, tests as defined in CLAUDE.md)
2. Commit with message referencing the feedback addressed
3. Push changes
4. Re-run `/pr-feedback --local` to verify changes are clean

## Key Principle

You have context on the work's purpose that automated reviewers lack. Include your opinion in the question text, but let the user make the final call. Your reasoning helps inform their decision.
