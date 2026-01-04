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

2. Run CI check in background:
   ```bash
   gh pr checks <PR_NUMBER> --watch --interval 10
   ```

   Use the Bash tool with `run_in_background: true` parameter.

3. When the background task completes, notify the user:
   - Try `mcp__event-bus__notify(title="CI", message="CI passed/failed on PR #<PR_NUMBER>")`
   - If event-bus unavailable, skip notification - user will see result when checking task output

4. Confirm to user that CI is being monitored and they'll receive a notification.

5. Continue with other work - do not block waiting for CI.

6. When CI completes (you receive the background task notification):
   - Broadcast the result to the event bus so parallel sessions are notified.
   - Include your session_id (from startup: "Registered on event bus as: <session_id>") for attribution:
     ```
     mcp__event-bus__publish_event(
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
