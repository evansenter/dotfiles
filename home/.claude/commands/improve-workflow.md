---
argument-hint: [focus-area]
description: Suggest workflow improvements based on recent usage
---

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

## Analyze Recent Usage

Review how Claude Code was used recently in this repo to identify improvement opportunities:

```bash
# Recent commits to see work patterns
git log --oneline -20

# Check for repetitive patterns in commit messages
git log --oneline -50 | cut -d' ' -f2- | sort | uniq -c | sort -rn | head -10
```

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
