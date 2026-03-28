---
argument-hint: [PR_NUMBER]
description: Monitor CI in background and notify when complete
---

# Watch CI

Monitor CI status for a PR in the background. When CI completes, automatically runs `/pr-review remote`.

## Usage

```
/watch-ci [PR_NUMBER]
```

If PR_NUMBER is omitted, uses the current branch's PR.

## Instructions

1. Determine the PR number and repo name:
   - If provided as argument, use that
   - Otherwise, get current PR with `gh pr view --json number,title -q '.number,.title'`
   - Get repo name: `gh repo view --json name -q .name`

2. Wait for CI checks to exist (avoids race condition after fresh push):
   ```bash
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

4. Confirm to user that CI is being monitored and continue with other work.

5. When you receive a task notification about the background command completing, read the output to check results.

6. When CI completes:
   - Notify and broadcast:
     ```
     mcp__agent-event-bus__notify(title="CI", message="CI passed/failed on PR #<PR_NUMBER>")
     mcp__agent-event-bus__publish_event(
       event_type: "ci_completed",
       payload: "CI <passed/failed> on PR #<PR_NUMBER> - <PR_TITLE>",
       session_id: "<your-session-id>",
       channel: "repo:<repo_name>"
     )
     ```
   - **Always** spawn `/pr-review remote` — CI status and code review are independent concerns. Do not gate review on CI pass.
   - If CI **failed**: Also investigate the failure and fix. Review and CI fixes can happen in parallel or any order.
