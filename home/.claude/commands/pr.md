---
argument-hint: <create | local | remote>
description: Create PRs or review local/remote feedback
---

# PR

Create pull requests or review feedback from local analysis and remote reviewers.

## Usage

```
/pr <create | local | remote>
```

- `create`: Commit changes and create/update PR (invokes commit-push-pr skill)
- `local`: Run local code analysis via pr-review-toolkit
- `remote`: Fetch and process remote reviewer comments from GitHub

## Instructions

Parse the subcommand from the first argument:

```bash
SUBCOMMAND="$1"
```

If `SUBCOMMAND` is empty or not one of `create`, `local`, `remote`:

```bash
echo "Usage: /pr <create | local | remote>"
echo "  create - Commit and create/update PR"
echo "  local  - Run local code analysis"
echo "  remote - Fetch and process reviewer comments"
exit 1
```

---

### Subcommand: `create`

Invoke the `/commit-commands:commit-push-pr` skill to commit outstanding changes and create or update a PR.

```
Skill(commit-commands:commit-push-pr)
```

**Handle edge cases:**
- **Nothing to commit**: If working tree is clean, inform user: "No changes to commit. Make changes first or run `/pr local` to review existing code."
- **Skill fails**: Report the error and suggest manual steps

**After success:**
Run `/watch-ci` to monitor CI status in background.

---

### Subcommand: `local`

Run local code analysis using the pr-review-toolkit.

#### 1. Summarize Changes

```bash
git diff --stat HEAD~1 2>/dev/null || git diff --stat main...HEAD
```

**Handle edge cases:**
- **No commits yet**: Use `git diff --stat` (unstaged changes) or `git diff --cached --stat` (staged)
- **No changes at all**: Inform user: "No changes to analyze. Make changes first."

Output a 2-3 sentence summary of what was changed and why.

#### 2. Run Analysis

Invoke the pr-review-toolkit skill:

```
Skill(pr-review-toolkit:review-pr)
```

#### 3. Handle Results

**If no issues found:**
- Inform user: "No issues found. Code looks clean."
- Suggest next step: "Ready to create PR? Run `/pr create`"
- Exit early

**If issues found**, continue to categorize:

#### 4. Categorize and Form Opinions

ultrathink: For each issue found:
1. **Classify severity**: Critical / Important / Suggestion
2. **Form opinion**: Agree, Disagree, or Uncertain
3. **Note reasoning**: Why you think this way given context

#### 5. Display Summary

Output ALL findings ordered by severity (Critical → Important → Suggestion). Start with context, then list every finding:

```markdown
## Local Analysis Summary

### What This PR Does
[2-3 sentences summarizing the changes and their purpose, derived from commits and diff]

### Feedback Themes
- [Theme 1: e.g., "Error handling gaps in new API endpoints"]
- [Theme 2: e.g., "Missing input validation"]
- [Theme 3: if applicable]

### Areas Requiring Human Attention
- [Any scope creep concerns - changes beyond the stated purpose]
- [Deviations from codebase patterns/conventions]
- [Architectural decisions that need validation]
- [Security-sensitive changes]

---

### Detailed Findings

#### #1. [Critical] `config.json:15`
> Fix JSON interface to handle missing fields
**Opinion**: Agree - breaking change needs fix

#### #2. [Important] `bootstrap.sh:42`
> Validate input before processing
**Opinion**: Agree - defensive programming

#### #3. [Suggestion] `utils.ts:89`
> Add error handling for edge case
**Opinion**: Disagree - unlikely to occur
```

#### 6. Present via AskUserQuestion

Present ONE question for EACH item, batched in groups of up to 4. Include your opinion in the question text.

```json
{
  "questions": [
    {
      "question": "[Critical] config.json:15 - Fix JSON interface - Agree, breaking change",
      "header": "#1",
      "options": [
        {"label": "Implement (Recommended)", "description": "Fix it now"},
        {"label": "Skip", "description": "Not worth fixing"},
        {"label": "Defer", "description": "Create RFC/issue for later"},
        {"label": "Elaborate", "description": "Explain this topic, then re-ask"}
      ],
      "multiSelect": false
    },
    {
      "question": "[Important] bootstrap.sh:42 - Validate input - Agree, defensive programming",
      "header": "#2",
      "options": [
        {"label": "Implement (Recommended)", "description": "Fix it now"},
        {"label": "Skip", "description": "Not worth fixing"},
        {"label": "Defer", "description": "Create RFC/issue for later"},
        {"label": "Elaborate", "description": "Explain this topic, then re-ask"}
      ],
      "multiSelect": false
    },
    {
      "question": "[Suggestion] utils.ts:89 - Add error handling - Disagree, unlikely to occur",
      "header": "#3",
      "options": [
        {"label": "Implement", "description": "Fix it now"},
        {"label": "Skip (Recommended)", "description": "Not worth fixing"},
        {"label": "Defer", "description": "Create RFC/issue for later"},
        {"label": "Elaborate", "description": "Explain this topic, then re-ask"}
      ],
      "multiSelect": false
    }
  ]
}
```

Always include a final open-ended question for any additional comments.

#### 7. Act on User Decisions

- **Implement**: Fix the item immediately
- **Skip**: Note it was skipped, move on
- **Defer**: Use `/rfc --create` to create an RFC issue, or create a simpler issue with:
  - A priority label based on severity/impact:
    - `priority:high` - Blocks other work, critical bug
    - `priority:medium` - Important but not urgent
    - `priority:low` - Nice to have, backlog
  - Any relevant type labels (bug, enhancement, etc.)
  - **Note**: Run `gh label list` to check existing repo labels. Prefer existing labels, but suggest new ones if appropriate and notify the user before creating them.
- **Elaborate**: Explain the topic, then re-ask

#### 8. Re-check

After implementing fixes, run `/pr local` again to verify changes are clean.

---

### Subcommand: `remote`

Fetch and process feedback from GitHub reviewers.

#### 1. Get PR Info

```bash
PR_NUM=$(gh pr view --json number -q .number)
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

Handle failures with specific error messages:
- **Not a git repo**: "Not in a git repository. Navigate to a project directory first."
- **No remote**: "No GitHub remote found. Push your branch to GitHub first."
- **No PR exists**: "No PR found for this branch. Run `/pr create` to create one."

#### 2. Fetch Review Comments

```bash
gh api "repos/${REPO}/pulls/${PR_NUM}/comments"
gh api "repos/${REPO}/pulls/${PR_NUM}/reviews"
gh api "repos/${REPO}/issues/${PR_NUM}/comments"
```

If no feedback found, inform user and exit early.

#### 3. Categorize and Form Opinions

ultrathink: For each piece of feedback:
1. **Classify severity**: Critical / Important / Suggestion
2. **Form opinion**: Agree, Disagree, or Uncertain
3. **Note reasoning**: Why you think this way given context

#### 4. Display Summary

Output ALL feedback items ordered by severity (Critical → Important → Suggestion). Start with context, then list every item:

```markdown
## PR Feedback Summary

### What This PR Does
[2-3 sentences summarizing the changes and their purpose, derived from PR description and commits]

### Feedback Themes
- [Theme 1: e.g., "Reviewers concerned about error handling"]
- [Theme 2: e.g., "Questions about test coverage"]
- [Theme 3: if applicable]

### Areas Requiring Human Attention
- [Any scope creep concerns raised by reviewers]
- [Deviations from codebase patterns/conventions flagged]
- [Architectural decisions reviewers questioned]
- [Security concerns raised]

---

### Detailed Findings

#### #1. [Critical] `config.json:15`
> Fix JSON interface to handle missing fields
**Opinion**: Agree - breaking change needs fix

#### #2. [Important] `bootstrap.sh:42`
> Validate input before processing
**Opinion**: Agree - defensive programming

#### #3. [Suggestion] `utils.ts:89`
> Add error handling for edge case
**Opinion**: Disagree - unlikely to occur
```

#### 5. Present via AskUserQuestion

Present ONE question for EACH item, batched in groups of up to 4. Include your opinion in the question text.

```json
{
  "questions": [
    {
      "question": "[Critical] config.json:15 - Fix JSON interface - Agree, breaking change",
      "header": "#1",
      "options": [
        {"label": "Implement (Recommended)", "description": "Fix it now"},
        {"label": "Skip", "description": "Not worth fixing"},
        {"label": "Defer", "description": "Create RFC/issue for later"},
        {"label": "Elaborate", "description": "Explain this topic, then re-ask"}
      ],
      "multiSelect": false
    },
    {
      "question": "[Important] bootstrap.sh:42 - Validate input - Agree, defensive programming",
      "header": "#2",
      "options": [
        {"label": "Implement (Recommended)", "description": "Fix it now"},
        {"label": "Skip", "description": "Not worth fixing"},
        {"label": "Defer", "description": "Create RFC/issue for later"},
        {"label": "Elaborate", "description": "Explain this topic, then re-ask"}
      ],
      "multiSelect": false
    },
    {
      "question": "[Suggestion] utils.ts:89 - Add error handling - Disagree, unlikely to occur",
      "header": "#3",
      "options": [
        {"label": "Implement", "description": "Fix it now"},
        {"label": "Skip (Recommended)", "description": "Not worth fixing"},
        {"label": "Defer", "description": "Create RFC/issue for later"},
        {"label": "Elaborate", "description": "Explain this topic, then re-ask"}
      ],
      "multiSelect": false
    }
  ]
}
```

Always include a final open-ended question for any additional comments.

#### 6. Act on User Decisions

- **Implement**: Fix the item immediately
- **Skip**: Note it was skipped, move on
- **Defer**: Use `/rfc --create` to create an RFC issue, or create a simpler issue with:
  - A priority label based on severity/impact:
    - `priority:high` - Blocks other work, critical bug
    - `priority:medium` - Important but not urgent
    - `priority:low` - Nice to have, backlog
  - Any relevant type labels (bug, enhancement, etc.)
  - **Note**: Run `gh label list` to check existing repo labels. Prefer existing labels, but suggest new ones if appropriate and notify the user before creating them.
- **Elaborate**: Explain the topic, then re-ask

#### 7. Push and Re-check

After implementing:
1. Run quality gates (linter, formatter, tests)
2. Commit with message referencing feedback addressed
3. Push changes
4. Run `/pr local` to verify changes are clean

#### 8. Reply to Reviewers (Optional)

If feedback was addressed, consider replying to acknowledge:

```bash
gh pr comment "${PR_NUM}" --body "Addressed feedback: <summary of changes>"
```

Or reply to specific review comments via the GitHub UI.

## Key Principle

You have context on the work's purpose that automated reviewers lack. Include your opinion in each question, but let the user make the final call.
