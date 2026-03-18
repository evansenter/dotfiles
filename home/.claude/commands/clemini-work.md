---
argument-hint: <issue-number | "description">
description: Delegate work to clemini with supervised review and bookkeeping
---

# Clemini Work

Delegate implementation to clemini (Gemini), then review, test, and handle bookkeeping.

## Usage

```
/clemini-work #46
/clemini-work "add a --verbose flag to the CLI"
```

## Workflow

1. **Fetch context** - Get issue details if issue number provided
2. **Delegate** - Send task to `clemini_chat`
3. **Review** - Assess clemini's changes via `git diff`
4. **Rebuild** - Run `clemini_rebuild`
5. **Test** - Verify the feature works
6. **Iterate** - If issues found, send feedback to clemini
7. **Bookkeeping** - Commit, push, update issue

---

## Step 1: Parse Input

- Number or `#N` → fetch issue with `gh issue view N`
- String → use as task description directly

Extract:
- `TASK_DESCRIPTION`: Issue body or provided description
- `ISSUE_NUMBER`: If applicable (for bookkeeping)

## Step 2: Confirm Scope

Present to user:

```markdown
## Clemini Work

**Task:** <title or description>
**Issue:** #N (if applicable)

I'll delegate this to clemini, then:
1. Review the implementation
2. Rebuild and test
3. Commit and push (with your approval)

Proceed?
```

Ask via AskUserQuestion: **Yes** / **Modify task** / **Cancel**

## Step 3: Delegate to Clemini

Generate a focused prompt for clemini:

```
Work on this task:

<TASK_DESCRIPTION>

Requirements:
- Read relevant files before editing
- Make minimal, focused changes
- Run quality gates when done: `make clippy && make fmt && make test`
- Report what you changed
```

Call `mcp__clemini__clemini_chat(message: <prompt>)`

Store the `interaction_id` from response for potential follow-up (check logs at `~/.clemini/logs/` if not visible in MCP response).

## Step 4: Review Changes

After clemini completes:

1. Run `git diff` to see all changes
2. Run `git diff --stat` for summary
3. Assess the implementation:
   - Does it address the task?
   - Are there obvious issues?
   - Is scope appropriate (no over-engineering)?
   - **Did clemini add tests?** New functions/features should have unit tests

Present findings to user:

```markdown
## Clemini's Changes

**Files modified:**
- src/mcp.rs (+12, -45)
- src/main.rs (+3, -1)

**Summary:** <your assessment>

**Issues found:** <any concerns, or "None">
```

## Step 5: Iterate if Needed

If issues found, ask user:
- **Send feedback to clemini** - Continue with same session
- **Fix manually** - You take over
- **Abort** - Discard changes

For feedback, call `mcp__clemini__clemini_chat(message: <feedback>, interaction_id: <stored_id>)`

**Common follow-ups** (always use same interaction_id for context continuity):
- Missing tests: "Add unit tests for the new functions you added"
- Coverage gaps: "The X function has no test coverage, please add tests"
- Edge cases: "Add tests for error conditions and edge cases"

Loop back to Step 4.

## Step 6: Rebuild and Test

Once changes look good:

1. Run `mcp__clemini__clemini_rebuild()`
2. Wait for rebuild (sleep 3-5 seconds)
3. Run quality gates: `make clippy && make test` (clemini should have already formatted)
4. **Feature-specific testing** (not just "does it respond"):

### Testing Requirements by Change Type

**MCP tool changes:**
- Test the specific functionality being changed, not just basic response
- If multi-turn/session related: test conversation continuity with interaction_id
- If new parameters: test with and without the new parameters
- Check logs (`~/.clemini/logs/`) to verify expected behavior

**Tool behavior changes:**
- Test the exact scenario from the issue
- Test edge cases (empty input, large input, error conditions)
- Verify error messages are helpful

**Logging/output changes:**
- View actual log output, don't just trust compilation
- test with `make logs`

**Stateful features:**
- Test state creation, persistence, and retrieval
- Test with valid and invalid state references

### Test Checklist

Before marking complete, verify:
- [ ] Core feature works as described in issue
- [ ] At least one edge case tested
- [ ] Logs show expected behavior (if applicable)
- [ ] No regressions in related functionality

Report results:

```markdown
## Verification

- Rebuild: ✓
- Compilation: ✓
- Feature test: <specific test performed and result>
- Edge case: <what was tested>
- Logs verified: <yes/no/n/a>
```

## Step 7: Bookkeeping

Ask user via AskUserQuestion:
- **Commit and push** (Recommended)
- **Commit only** - Don't push yet
- **Skip** - Leave changes uncommitted

If committing:

1. `git add -A`
2. Generate commit message from changes:
   ```
   <type>(<scope>): <description>

   <body if needed>

   Fixes #N (if issue number)

   Co-Authored-By: Claude <noreply@anthropic.com>
   Co-Authored-By: Gemini <noreply@google.com>
   ```
3. `git commit`
4. If pushing: `git push`

If issue number provided:
- Comment on issue with summary of changes
- Or close issue if fully resolved (ask user)

## Step 8: Complete

```markdown
## Done

- Committed: <hash>
- Pushed: <yes/no>
- Issue #N: <updated/closed/unchanged>

Changes by clemini, reviewed by Claude Code.
```

---

## Error Handling

| Error | Response |
|-------|----------|
| clemini_chat fails | Show error, ask to retry or abort |
| clemini_rebuild fails | Show build errors, offer to fix manually |
| Quality gates fail | Send errors to clemini for fixing (clippy warnings, test failures, format issues) |

---

## Session Management

- Store `interaction_id` from first clemini response (check logs if not visible in response)
- Use same interaction_id for follow-up feedback
- Pass as `interaction_id` parameter to subsequent calls
- Interaction enables clemini to remember conversation context

---

## Notes

- **Always rebuild before testing** - clemini_rebuild replaces the running process
- **Review gate** - Never commit without reviewing changes
- **User approval** - Always ask before committing/pushing
- **Dual attribution** - Both Claude and Gemini get credit in commits
