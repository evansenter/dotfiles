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
- Flags are mutually exclusive; if both are specified, defaults to running both (same as no flags)

## Instructions

When this skill is invoked:

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

### 3. Categorize Feedback

Classify each piece of feedback:

- **Critical**: Security issues, bugs, broken functionality, missing error handling
- **Important**: Test coverage gaps, API design issues, documentation gaps, code quality
- **Suggestions**: Style preferences, minor refactors, nice-to-haves, optimizations

### 4. Form Opinions

For each item, assess:
- Does this feedback understand the context and purpose of the change?
- Is this a genuine improvement or unnecessary complexity?
- Does implementing this align with project conventions (check CLAUDE.md)?
- Is the effort proportional to the benefit?

### 5. Present Opinion Table

Output findings grouped by action, with continuous numbering across groups:

```markdown
## PR Feedback Review

### Implement

#### 1. [Critical] `path:123` (Remote)
> Summary of the feedback
**Opinion**: Agree - [reason]

#### 2. [Important] `path:456` (Local)
> Summary of the feedback
**Opinion**: Agree - [reason]

### Discuss

#### 3. [Important] `path:789` (Remote)
> Summary of the feedback
**Opinion**: Disagree - [reason why this needs discussion]

### Skip

#### 4. [Suggestion] `path:012` (Local)
> Summary of the feedback
**Opinion**: Trivial / Out of scope / Already addressed
```

**Source indicators**: `(Local)` = from pr-review-toolkit, `(Remote)` = from external reviewers

Numbers are continuous across groups so items can be referenced easily (e.g., "let's discuss #3").

### 6. Implementation Rules

**Implement immediately** (no discussion needed):
- Critical items you agree with
- Important items you agree with
- Suggestions you agree with AND are trivial (<5 lines)

**Stop and discuss** (wait for user input):
- Critical items you disagree with or are uncertain about
- Important items you disagree with or are uncertain about
- Any feedback that seems to misunderstand the purpose of the change

**Skip** (note in summary but don't implement):
- Suggestions you disagree with
- Out-of-scope feedback (create GitHub issue instead)
- Feedback already addressed

### 7. After Discussion

Once the user provides input on disputed items:
- Implement items where you reached agreement
- Skip items the user agrees to skip
- Create issues for items deferred to future work

### 8. Push and Re-check

After implementing feedback:
1. Run project quality gates (linter, formatter, tests as defined in CLAUDE.md)
2. Commit with message referencing the feedback addressed
3. Push changes
4. Re-run `/pr-feedback` to verify no new comments

## Key Principle

You have context on the work's purpose that automated reviewers lack. If feedback seems to miss the point, add unnecessary complexity, or conflict with project conventions, flag it for discussion rather than blindly implementing. Honest disagreement is more valuable than compliance.
