---
argument-hint: [--global] [focus-area]
description: Suggest workflow improvements based on recent usage
---

ultrathink: Based on our recent work together, suggest Claude Code features and configurations that would improve autonomy and reduce back-and-forth.

## Arguments

Parse arguments from: $ARGUMENTS

- `--global` - Analyze all projects instead of just the current one
- `focus-area` - Optional focus area for suggestions (e.g., "permissions", "automation")

Consider:
- MCP servers I should enable
- CLAUDE.md improvements (global and local)
- Hooks or automation opportunities
- Memory/context patterns that would help
- Tool configurations I might be underutilizing

References:
- Claude Code docs
- https://github.com/anthropics/claude-plugins-official

## Analyze Recent Usage

### Data-Driven Analysis

Use the session-analytics MCP server for quantitative insights:

```
# Get comprehensive insights (tool frequency, sequences, permission gaps, trends)
mcp__session-analytics__get_insights(days=7, refresh=false)

# Get detailed tool frequency with breakdowns
mcp__session-analytics__get_tool_frequency(days=7, expand=true)

# Get commands that may need permission configuration
mcp__session-analytics__get_permission_gaps(days=7, min_count=5)
```

If `--global` was passed, omit the `project` parameter. For project-specific analysis, pass the current project path.

**Fallback**: If MCP is unavailable, use the session-analytics CLI:
```bash
# Check if CLI is available
if command -v session-analytics-cli &>/dev/null; then
    session-analytics-cli frequency --days 7
    session-analytics-cli commands --days 7
    session-analytics-cli permissions --days 7 --min-count 5
fi
```

**Important**: Session logs are historical and may reflect outdated workflows. Patterns from days ago may have already been addressed by recent changes. Cross-reference with current settings.json to filter stale recommendations.

### Git History Analysis

```bash
# Recent commits to see work patterns
git log --oneline -20

# Check for repetitive patterns in commit messages
git log --oneline -50 | cut -d' ' -f2- | sort | uniq -c | sort -rn | head -10
```

### Conversation Analysis

Also consider the current conversation:
- What commands were run repeatedly?
- Where did friction occur (approvals, back-and-forth, clarifications)?
- What manual steps could be automated?
- Were there permissions that blocked autonomous work?

## Check Global Setup First

Before making suggestions, read the global Claude configuration to filter out stale recommendations:

```bash
cat ~/.claude/CLAUDE.md
cat ~/.claude/settings.json
ls ~/.claude/commands/
```

Then read existing commands to understand current patterns:

```bash
# List all command files
ls ~/.claude/commands/
```

Read each command file individually using the Read tool to understand patterns and find improvement opportunities.

Skip any suggestion that:
- Proposes a workflow already documented in the global CLAUDE.md
- Recommends a command or hook that already exists
- Suggests a permission that's already configured

## Review Claude File Language

Also review the language and clarity of global Claude files in `~/.claude/`:
- `CLAUDE.md` - Is the workflow documentation clear and actionable?
- `commands/*.md` - Are command instructions unambiguous? Do examples help?
- `settings.json` - Are there permissions that should be added based on documented workflows?

Look for:
- Inconsistencies between what's documented and what's configured
- Instructions that could be misinterpreted
- Missing context that would help Claude follow the workflow correctly

Include any language/clarity improvements in the Global Improvements section.

## Output

Be specific about what each suggestion enables and the setup required.

**Important**: For each suggestion, include the specific friction or issue encountered during the session that motivates the change. Reference specific commands that failed, approvals that blocked work, or back-and-forth that could have been avoided. This context is essential when creating issues against evansenter/dotfiles.

Group suggestions into two categories:

**Local Improvements** - Specific to the current repository:
- Repository-specific CLAUDE.md additions
- Project-specific hooks or automation
- Documentation for this codebase

**Global Improvements** - Apply to all Claude Code sessions:
- New commands or workflow enhancements for `~/.claude/commands/`
- Permission configuration changes for `~/.claude/settings.json`
- Hook improvements for `~/.claude/hooks/`
- Global CLAUDE.md workflow documentation updates

## Follow-up

When suggesting to create an issue against `evansenter/dotfiles`, **only include Global Improvements**. Each improvement MUST include:
- The specific friction encountered (what went wrong or was inefficient)
- Session context (what you were trying to do when the friction occurred)
- The proposed fix with concrete code/config changes

Local improvements should be tracked in the current repository's issues.

## Meta-Improvements

Beyond workflow improvements, identify gaps in the underlying infrastructure that limit analysis capabilities. These become feature requests for the respective repositories.

### Session Analytics (evansenter/claude-session-analytics)

Evaluate what additional insights would be valuable:

| Gap | Description | Benefit |
|-----|-------------|---------|
| **Stale recommendation filtering** | Auto-compare gaps against current settings.json | Avoid suggesting already-configured permissions |
| **Session outcome tracking** | Classify sessions as success/failure/abandoned based on signals | Understand which workflows lead to completion |
| **Rework detection** | Identify when same files are edited multiple times in sequence | Surface friction points needing automation |
| **Issue/PR correlation** | Link sessions to GitHub outcomes (merged PRs, closed issues) | Measure session effectiveness |
| **Learning extraction** | Auto-identify gotchas and patterns from session history | Build institutional knowledge |
| **Session comparison** | Diff two sessions to see workflow evolution | Track improvement over time |
| **Time-between-steps analysis** | Measure latency between tool calls | Identify slow operations |

### Event Bus (evansenter/claude-event-bus)

Evaluate coordination capabilities:

| Gap | Description | Benefit |
|-----|-------------|---------|
| **Learning persistence** | Store gotchas/patterns permanently beyond event TTL | Build long-term knowledge base |
| **Event search** | Query historical events by type, content, date range | Find past discoveries on demand |
| **Conflict detection** | Alert when sessions modify same files | Prevent merge conflicts |
| **Activity visualization** | Dashboard showing who's working on what | Situational awareness |
| **Channel statistics** | Track which channels are most active | Understand coordination patterns |
| **Event TTL customization** | Configure retention per event type | Keep learnings longer than noise |

### Dotfiles Integration

The dotfiles repo is the central hub for Claude Code configuration:
- **Global CLAUDE.md** - System-wide workflow preferences and instructions
- **claude-remote.md** - Prompt template for automated code review (claude-review workflow)
- **Commands** - All custom slash commands
- **Hooks** - Session lifecycle and event bus integration
- **Settings** - Permissions, plugins, model configuration

Evaluate how analytics and event bus integrate with this central configuration:

| Gap | Description | Benefit |
|-----|-------------|---------|
| **Combined status view** | Single command showing analytics + event bus status | Reduce context switching |
| **Auto-permission sync** | Periodically check for permission gaps and suggest additions | Proactive maintenance |
| **Cross-repo patterns** | Fetch related repo configurations for comparison | Learn from other projects |
| **Workflow templates** | Starter configurations for common project types | Faster onboarding |
| **Prompt versioning** | Track CLAUDE.md and claude-remote.md changes over time | Understand prompt evolution |
| **Prompt effectiveness** | Correlate prompt changes with session outcomes | Measure prompt improvements |

### Output

When meta-improvements are identified, include them in a separate section:

**Infrastructure Improvements** - Feature requests for supporting tools:
- `evansenter/claude-session-analytics` - Analytics and insight generation
- `evansenter/claude-event-bus` - Cross-session coordination
- `evansenter/dotfiles` - Integration and workflow commands

For each, specify:
1. What analysis or feature is missing
2. What friction it would eliminate
3. Concrete example from the current session
