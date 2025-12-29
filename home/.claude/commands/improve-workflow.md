Based on our recent work together, suggest Claude Code features and configurations that would improve autonomy and reduce back-and-forth.

Consider:
- MCP servers I should enable
- CLAUDE.md improvements (global and local)
- Hooks or automation opportunities
- Memory/context patterns that would help
- Tool configurations I might be underutilizing

References:
- Claude Code docs
- https://github.com/anthropics/claude-plugins-official

$ARGUMENTS

## Check Global Setup First

Before making suggestions, read the global Claude configuration to filter out stale recommendations:

```bash
cat ~/.claude/CLAUDE.md
```

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

When suggesting to create an issue against `evansenter/dotfiles`, **only include Global Improvements**. Local improvements should be tracked in the current repository's issues.
