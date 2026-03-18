---
argument-hint: [PR_NUMBER]
description: Monitor CI in background and notify when complete
---

# Watch CI

Monitor CI status for a PR in the background and notify when complete.

## Usage

```
/watch-ci [PR_NUMBER]
```

If PR_NUMBER is omitted, uses the current branch's PR.

## Instructions

1. Determine the PR number:
   - If provided as argument, use that
   - Otherwise, get current PR with `gh pr view --json number -q .number`

2. Wait for CI checks to exist (avoids race condition after fresh push):
   ```bash
   # Poll until at least one check exists (max 30s)
   for i in {1..6}; do
     count=$(gh pr checks <PR_NUMBER> 2>/dev/null | wc -l)
     [ "$count" -gt 0 ] && break
     sleep 5
   done
   ```

3. Run CI check in background:
   ```bash
   gh pr checks <PR_NUMBER> --watch --interval 10
   ```

   Use the Bash tool with `run_in_background: true` parameter.

4. Confirm to user that CI is being monitored and they'll receive a notification.

5. Continue with other work - do not block waiting for CI.

6. When you receive a `<system-reminder>` about background task output, check the output file to see if CI completed (all checks show pass/fail, no more "pending"). Use `TaskOutput(task_id, block=false)` or read the output file directly.

7. When CI completes:
   - Notify: `mcp__agent-event-bus__notify(title="CI", message="CI passed/failed on PR #<PR_NUMBER>")`
   - Broadcast the result to the event bus so parallel sessions are notified.
   - Include your session_id (from startup: "Registered on event bus as: <session_id>") for attribution:
     ```
     mcp__agent-event-bus__publish_event(
       event_type: "ci_completed",
       payload: "CI <passed/failed> on PR #<PR_NUMBER> - <PR_TITLE>",
       session_id: "<your-session-id>",
       channel: "repo:<repo_name>"
     )
     ```
   - If **passed**:
     - **CRITICAL**: Run `/pr-review remote` to process reviewer comments before declaring ready to merge
     - Automated reviewers (like claude-review) post new comments on each CI run
   - If **failed**: Investigate the failure and fix
