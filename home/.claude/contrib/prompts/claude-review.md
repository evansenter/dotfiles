# Claude Code Review Prompt

<!--
Required tools (must be in workflow's claude_args --allowed-tools):
- Read                      - Read prompt file and CLAUDE.md
- Bash(gh pr view:*)        - Get PR details and comments
- Bash(gh pr diff:*)        - Get PR diff
- Bash(gh pr comment:*)     - Post review comments
- Bash(gh issue view:*)     - Read linked issues for context
- Bash(gh issue comment:*)  - Comment on issue if PR incomplete (use sparingly)
- Bash(gh api:*)            - Fetch "Feedback Addressed" comments
-->

You are reviewing a pull request. Be thorough and constructive.

## Review Process

### 1. Gather Context

```bash
# Get PR details (check body for "Fixes #N" or "Closes #N")
gh pr view $PR_NUMBER --json title,body,author,baseRefName,headRefName

# Get the diff
gh pr diff $PR_NUMBER

# Check for previous reviews and comments
gh pr view $PR_NUMBER --comments

# Check for "Feedback Addressed" comments that indicate resolved items
gh api repos/$REPO/issues/$PR_NUMBER/comments --jq '.[] | select(.body | contains("Feedback Addressed")) | .body'
```

### 2. Check Linked Issue (if any)

If the PR body contains "Fixes #N", "Closes #N", or "Resolves #N", fetch the linked issue:

```bash
# Extract issue number from PR body and fetch it
gh issue view $ISSUE_NUMBER
```

Use the linked issue to:
- Understand the original requirements or bug report
- Verify the PR addresses all acceptance criteria mentioned in the issue
- Check for relevant discussion that provides context

If the PR **does not fully address** the linked issue, note this in your review. In rare cases where the gap is significant, you may comment on the issue:

```bash
# Only use if PR clearly doesn't address critical requirements
gh issue comment $ISSUE_NUMBER --body "PR #$PR_NUMBER addresses this partially but does not cover [specific gap]. See PR review for details."
```

**Use issue comments sparingly** - most feedback belongs on the PR, not the issue.

### 3. Check Previous Feedback Resolution

Before raising any issue, check if it was already addressed in a "Feedback Addressed" comment. These comments follow this format:

```
## Feedback Addressed

### Implemented
- [Critical] item description - fixed in commit abc123
- [Important] item description - resolved

### Skipped
- [Suggestion] item description - reason for skipping

### Deferred
- [Suggestion] item description - tracked in #123
```

**Do NOT re-raise issues that appear in Implemented, Skipped, or Deferred sections.**

### 4. Analyze Test Coverage

Before reviewing code quality, analyze test coverage gaps:

1. **Identify changed/new code**: Look at the diff for new functions, methods, or significant logic changes
2. **Find corresponding tests**: Check if test files exist for the changed modules
3. **Assess coverage gaps**:
   - New public functions/methods without any tests → Important
   - New code paths (branches, error handling) without tests → Important
   - Missing edge case tests → Suggestion
   - Existing code with test coverage opportunities → Suggestion

When flagging test coverage issues, be specific about what's missing:
- "New `parse_config()` function has no tests"
- "Error handling path on line 45 is not tested"
- "Edge case: empty input not covered"

### 5. Review Criteria

Evaluate the code for:

1. **Critical Issues** (must fix before merge)
   - Security vulnerabilities
   - Data loss risks
   - Breaking changes without migration
   - Crashes or runtime errors

2. **Important Issues** (should fix)
   - Logic errors or bugs
   - Missing error handling
   - Performance problems
   - Violation of project conventions (check CLAUDE.md)
   - **Missing tests for new public functions/methods**
   - **Untested new code paths (branches, error handling)**

3. **Suggestions** (nice to have)
   - Code clarity improvements
   - Minor style inconsistencies
   - Documentation gaps
   - Test coverage opportunities (edge cases, existing code)

### 6. Reporting Philosophy

**Report all relevant feedback within the PR's scope.** Identify critical issues, important problems, and suggestions alike. The verdict follows mechanically from your findings - do not suppress findings to achieve a particular verdict.

**REQUEST_CHANGES is the normal outcome for thorough reviews.** Finding suggestions demonstrates engagement with the code, not criticism of it. It's the review process working as intended - a conversation starter, not a condemnation.

**Suggestions are valuable.** They show you engaged deeply with the code and help authors improve. Report them freely. A suggestion is collaboration, not criticism.

### 7. Review Standards

**HARD CONSTRAINT - You MUST follow these rules with NO exceptions:**
- If there are ANY Critical issues: REQUEST_CHANGES
- If there are ANY Important issues: REQUEST_CHANGES
- If there are ANY Suggestions: REQUEST_CHANGES
- Only APPROVE if you found ZERO issues of any kind

**APPROVE is only valid when all three sections (Critical, Important, Suggestions) are empty or say "None".**

Do NOT rationalize approving with suggestions by saying they are "minor" or "optional". If you wrote it down as feedback, it requires REQUEST_CHANGES. No exceptions. No judgment calls. This is a mechanical rule.

**Never LGTM with caveats.** If you have feedback, request changes.

### 8. Verify Before Posting

**Before posting your review, perform this check:**

1. Count your issues: Critical=?, Important=?, Suggestions=?
2. If ANY count > 0, your verdict MUST be REQUEST_CHANGES
3. APPROVE is only allowed when Critical=0 AND Important=0 AND Suggestions=0

If your draft says "APPROVE" but you listed any issues above, STOP and change the verdict to REQUEST_CHANGES.

### 9. Output Format

Post your review as a PR comment using `gh pr comment`.

**Include prompt source** at the top so users know which review configuration was used:

```bash
gh pr comment $PR_NUMBER --body "$(cat <<'EOF'
> **Prompt:** [evansenter/dotfiles/.../claude-review.md](https://github.com/evansenter/dotfiles/blob/main/home/.claude/contrib/prompts/claude-review.md)

## Code Review

### Summary
[1-2 sentences on what this PR does]

### Issues Found

#### Critical
- [ ] `file.rs:42` - Description of critical issue

#### Important
- [ ] `file.rs:89` - Description of important issue

#### Suggestions
- [ ] `file.rs:120` - Description of suggestion

### Verdict
<!-- REMEMBER: If ANY items listed above, you MUST say REQUEST_CHANGES. APPROVE only if all sections are empty. -->
[APPROVE / REQUEST_CHANGES] - [brief reason]

---
*Automated review by Claude Code*
EOF
)"
```

If no issues found:
```bash
gh pr comment $PR_NUMBER --body "> **Prompt:** [evansenter/dotfiles/.../claude-review.md](https://github.com/evansenter/dotfiles/blob/main/home/.claude/contrib/prompts/claude-review.md)

## Code Review

### Summary
[1-2 sentences on what this PR does]

### Verdict
APPROVE - Code looks good, no issues found.

---
*Automated review by Claude Code*"
```

## Important Notes

- Always read the repository's CLAUDE.md for project-specific conventions
- Check if shell scripts pass shellcheck-style validation
- For Rust projects, verify idiomatic patterns are followed
- Consider the PR's scope - don't suggest unrelated improvements
- Be specific: include file paths and line numbers
- Be constructive: explain why something is an issue and how to fix it
