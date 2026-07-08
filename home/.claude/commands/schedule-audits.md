---
argument-hint: [status | off]
description: Create (or manage) a weekly Routine that runs the audit-* agents
---

# Schedule Audits

Set up a weekly scheduled loop (Routine) that runs the `audit-*` agents against the current repo. Implements the "Scheduled" primitive from the Loops & Automation guidance in global CLAUDE.md: recurring maintenance with a fixed cadence, no user in the loop.

## Usage

```
/schedule-audits           # Create the weekly Routine for this repo
/schedule-audits status    # Show existing audit Routines
/schedule-audits off       # Remove this repo's audit Routine
```

## Instructions

### Mode: create (no args)

1. **Check for an existing Routine** with CronList. If one named `weekly-audit-<repo>` already exists for this repo, show it and stop — don't create a duplicate.

2. **Pick the audit set.** Default: `audit-docs` and `audit-issues` weekly (cheap, high drift-rate). Ask via AskUserQuestion whether to also include the heavier agents:
   - **Docs + issues (Recommended)** — audit-docs, audit-issues
   - **Full sweep** — adds audit-codebase, audit-tests, audit-workflows

3. **Create the Routine** with CronCreate:
   - Name: `weekly-audit-<repo>`
   - Schedule: `0 9 * * 1` (Monday 09:00 local)
   - Prompt (self-contained — the fired session starts fresh):

     ```
     Run the scheduled weekly audit for <repo>. Spawn the <chosen audit-*>
     agents in parallel via the Agent tool. For each Critical/Important
     finding: check for an existing GitHub issue first, then file one with
     appropriate labels. Publish an `improvement_suggested` event to the
     event bus (channel repo:<repo>) summarizing findings and issue links.
     Do NOT push code changes — audits only observe and file issues.
     ```

4. **Confirm**: show the Routine name, schedule, agents included, and how to remove it (`/schedule-audits off`).

### Mode: `status`

Run CronList and show any `weekly-audit-*` Routines: name, cron expression, next run. If none: "No audit Routines scheduled. Run `/schedule-audits` to create one."

### Mode: `off`

Run CronList, find `weekly-audit-<repo>` for the current repo, confirm with the user, then remove it with CronDelete. If not found, say so.

## Notes

- Findings flow through issues + event bus, so the next interactive session picks them up via `<recent-events>` — the Routine never needs to interrupt you.
- Keep the cadence weekly. Audits are loops with a fuzzy stop condition (the agents bound their own scope); the schedule is the token-spend control, per the loops guidance.
- If CronCreate is unavailable (older CC, API-key auth), fall back to telling the user to run `/schedule` interactively with the same prompt.
