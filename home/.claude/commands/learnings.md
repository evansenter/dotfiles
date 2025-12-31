---
argument-hint: [--repo name] [--all] [--type gotcha|pattern|flaky]
description: Query historical discoveries from event bus
---

# Learnings

Query historical discoveries (gotchas, patterns, flaky tests) from the event bus.

## Usage

```
/learnings                      # Show learnings for current repo
/learnings --repo gemicro       # Show learnings for specific repo
/learnings --all                # Show all learnings across repos
/learnings --type gotcha        # Filter by type
/learnings --type pattern
/learnings --type flaky
```

## Instructions

### 1. Parse Arguments

From `$ARGUMENTS`, extract:
- **--repo**: Specific repo name to filter by
- **--all**: Show learnings across all repos
- **--type**: Filter by event type (gotcha, pattern, flaky)

If neither `--repo` nor `--all` is specified, use the current repo.

### 2. Get Current Repo (if needed)

```bash
gh repo view --json name -q .name 2>/dev/null || basename "$(git rev-parse --show-toplevel)"
```

### 3. Fetch Events

```
mcp__event-bus__get_events(since_id=0, limit=200)
```

### 4. Filter Events

Filter for learning-related event types:
- `gotcha_discovered` → Gotchas
- `pattern_found` → Patterns
- `test_flaky` → Flaky Tests
- `workaround_needed` → Workarounds

If `--type` is specified, filter to only that type:
- `gotcha` → `gotcha_discovered`
- `pattern` → `pattern_found`
- `flaky` → `test_flaky`
- `workaround` → `workaround_needed`

If not `--all`, filter by repo channel:
- Channel should contain `repo:<repo-name>`

### 5. Output Format

```markdown
## Learnings: [repo-name or "All Repos"]

### Gotchas (N)
- **[X days ago]** Description from payload
- **[Y days ago]** Another gotcha

### Patterns (N)
- **[X days ago]** Pattern description

### Flaky Tests (N)
- **[X days ago]** Test name or description
*Or: "No flaky tests recorded."*

### Workarounds (N)
- **[X days ago]** Workaround description
*Or: "No workarounds recorded."*

---
*Source: event-bus events (last 7 days)*
*Tip: Use `/broadcast` with type `gotcha_discovered` to record new learnings.*
```

If no learnings found:

```markdown
## Learnings: [repo-name]

No learnings recorded for this repository.

### How to Record Learnings

When you discover something non-obvious, broadcast it:

```
mcp__event-bus__publish_event(
  event_type: "gotcha_discovered",
  payload: "SQLite needs datetime adapters in Python 3.12+",
  channel: "repo:my-repo"
)
```

**Event types:**
- `gotcha_discovered` - Non-obvious issues or surprises
- `pattern_found` - Useful patterns discovered in the codebase
- `test_flaky` - Tests that sometimes fail, safe to retry
- `workaround_needed` - Temporary fixes for known issues
```

### 6. Time Formatting

Calculate relative time for display:
- Less than 1 hour: "X min ago"
- Less than 24 hours: "X hours ago"
- Less than 7 days: "X days ago"
- Older: Show date
