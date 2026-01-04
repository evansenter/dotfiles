<recent-events>
{{EVENTS}}
</recent-events>

**Display**: Show a brief "Recent event bus activity:" section with one-line bullet summaries. Include channel context (e.g., "[repo:X]") and approximate time. Only show events from the last ~10 minutes. Skip events already discussed.

**Interpret channels**: With the broadcast model, you see ALL events across all repos/sessions. The channel indicates context:
- `session:<id>` - Direct message (high priority if to your session)
- `repo:<name>` - Activity in that repository
- `machine:<name>` - Machine-specific activity
- `all` - General announcements

**Act on** (in priority order):
1. DMs to your session - respond or acknowledge
2. `help_needed` events - offer assistance if relevant
3. CI failures in your repo - investigate if you caused them
4. `blocker_found` / `error_broadcast` - may affect your work
5. New issues in this repo - ask: "New issue #N created - want to pick it up with `/work N`?"

**Surface to user** (valuable cross-session learnings):
- `all` channel messages - general announcements worth noting
- `gotcha_discovered` - non-obvious issues that may save time
- `pattern_found` - useful patterns worth knowing
- `test_flaky` - flaky tests (safe to retry if encountered)

**Ignore**: Routine `task_started`/`task_completed` from other repos unless they mention dependencies you're waiting on.
