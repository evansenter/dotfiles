---
argument-hint: [--global] [focus-area]
description: Suggest workflow improvements based on recent usage
---

ultrathink: Based on our recent work together, suggest Claude Code features and configurations that would improve autonomy and reduce back-and-forth.

## Arguments

Parse arguments from: $ARGUMENTS

- `--global` - Analyze all projects instead of just the current one
- `focus-area` - Optional focus area for suggestions (e.g., "permissions", "automation")

## 1. Gather Data

### Session Analytics

Use the session-analytics MCP server for quantitative insights:

```
mcp__session-analytics__get_insights(days=7, refresh=false)
mcp__session-analytics__get_tool_frequency(days=7, expand=true)
mcp__session-analytics__get_permission_gaps(days=7, min_count=5)
```

If `--global` was passed, omit the `project` parameter.

**Fallback**: If MCP is unavailable:
```bash
session-analytics-cli frequency --days 7
session-analytics-cli permissions --days 7 --min-count 5
```

**Important**: Session logs are historical. Cross-reference with current settings.json to filter stale recommendations.

### Git History

```bash
git log --oneline -20
git log --oneline -50 | cut -d' ' -f2- | sort | uniq -c | sort -rn | head -10
```

### Current Configuration

Read existing setup to filter stale recommendations:

```bash
cat ~/.claude/CLAUDE.md
cat ~/.claude/settings.json
ls ~/.claude/commands/
```

Read command files to understand current patterns. Skip suggestions for workflows, permissions, or commands that already exist.

## 2. Identify Friction

### From Data

Extract from session analytics:
- Permission gaps (commands used repeatedly without approval)
- Tool patterns suggesting missing automation
- Error clusters indicating problematic workflows

### From Reflection

Review the current conversation and identify friction YOU experienced:
- Commands that required multiple attempts or workarounds
- Capabilities you wished existed but had to work around
- Awkward multi-step processes that could be streamlined
- Information you needed but couldn't easily access
- Approvals that blocked autonomous work

For each friction point, note:
1. What you were trying to accomplish
2. What was awkward or missing
3. How you worked around it
4. Suggested improvement

### From User (Optional)

After presenting your observations, ask if the user experienced additional friction:

```json
{
  "question": "Did you experience friction that I didn't catch?",
  "header": "Friction",
  "options": [
    {"label": "Yes", "description": "There were other pain points"},
    {"label": "No", "description": "You covered it"}
  ],
  "multiSelect": false
}
```

## 3. Review Configuration Quality

Check Claude files for clarity issues:
- `~/.claude/CLAUDE.md` - Is documentation clear and actionable?
- `~/.claude/commands/*.md` - Are instructions unambiguous?
- `~/.claude/settings.json` - Do permissions match documented workflows?

Look for inconsistencies between what's documented and what's configured.

## 4. Output

For each suggestion, include the specific friction that motivates the change.

### Local Improvements

Specific to the current repository:
- Repository-specific CLAUDE.md additions
- Project-specific hooks or automation

### Global Improvements

Apply to all Claude Code sessions:
- Commands for `~/.claude/commands/`
- Permissions for `~/.claude/settings.json`
- Hook improvements for `~/.claude/hooks/`
- CLAUDE.md workflow updates

### Infrastructure Improvements

Feature requests for supporting tools. Check existing issues first:

```
mcp__github__list_issues(owner="evansenter", repo="claude-session-analytics", state="open")
mcp__github__list_issues(owner="evansenter", repo="claude-event-bus", state="open")
```

For gaps not already tracked, consider whether friction points to missing capabilities in:

- **Session Analytics** (`evansenter/claude-session-analytics`) - Data analysis, pattern detection, outcome tracking
- **Event Bus** (`evansenter/claude-event-bus`) - Cross-session coordination, learning persistence
- **Dotfiles** (`evansenter/dotfiles`) - Workflow commands, integration glue

## 5. Follow-up

For Global Improvements, create issues against `evansenter/dotfiles` with:
- The specific friction encountered
- Session context
- Proposed fix with concrete changes

Local improvements should be tracked in the current repository's issues.

After creating an issue in another repo, broadcast so sessions there can pick it up:
```
mcp__event-bus__publish_event(
  event_type: "issue_created",
  payload: "Created issue #<N> in <repo>: <title>",
  channel: "repo:<target_repo>"
)
```
