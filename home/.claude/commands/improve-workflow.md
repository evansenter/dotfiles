---
argument-hint: [--global] [--days N] [focus-area]
description: Suggest workflow improvements based on recent usage
---

ultrathink: Identify friction, propose fixes, implement on approval.

## Core Principle

**Reduce friction that slows down work.** Friction sources:
- Repeated approvals for safe commands
- Manual multi-step processes that should be automated
- Missing guidance that causes wrong decisions
- Gaps in tooling that force workarounds

## Arguments

- `--global` - Analyze all projects (default: current project)
- `--days N` - Days to analyze (default: 1)
- `focus-area` - Optional focus (e.g., "permissions", "commands")

## 1. Gather Data

### Session Analytics

```
mcp__session-analytics__get_insights(days=<N>)
mcp__session-analytics__get_permission_gaps(days=<N>, min_count=3)
mcp__session-analytics__analyze_failures(days=<N>)
```

### Event Bus

```
mcp__event-bus__get_events(limit=50, order="desc")
```

Filter for `gotcha_discovered`, `pattern_found`, `improvement_suggested`.

### Current Config

Read `~/.claude/settings.json` and list `~/.claude/commands/` to skip existing.

## 2. Friction Checklist

### Permission Gaps
- Commands used 3+ times requiring approval each time
- Safe read-only commands not yet allowed
- Build/test commands for this project's stack
- CLI tools installed but not permitted

### Missing Commands
- Multi-step sequences repeated across sessions
- Workflows documented in CLAUDE.md but not automated
- Patterns from other repos that would help here

### CLAUDE.md Gaps
- Decisions you made that should be documented
- Conventions you had to infer from code
- Quality gates not specified
- Workflow preferences unclear

### Infrastructure Gaps
- Session analytics not capturing useful patterns
- Event bus missing helpful event types
- Audit agents missing coverage areas

### From This Session
- Workarounds you used
- Approvals that blocked flow
- Places you got stuck or redirected

## 3. Output Format

### Summary

| Category | Findings |
|----------|----------|
| Permissions | N commands to add |
| Commands | N to create |
| CLAUDE.md | N updates |
| Infrastructure | N issues |

### Critical

Issues blocking autonomy or causing repeated friction.

**[Permissions]**
- `Bash(foo:*)` - Used 12 times, approved each time
- **Fix**: Add to `~/.claude/settings.json`

**[Missing Guidance]**
- No guidance on when to create issues vs fix inline
- **Fix**: Add to CLAUDE.md Decision-Making section

### Important

Significant improvements worth implementing.

**[Commands]**
- Repeated 3-step process for X
- **Fix**: Create `~/.claude/commands/do-x.md`

**[Infrastructure]**
- Session analytics doesn't track Y
- **Fix**: Create issue in claude-session-analytics

### Suggestions

Nice-to-have improvements.

**[CLAUDE.md]**
- Could document Z convention
- **Fix**: Add to project CLAUDE.md

## 4. Implement

After user approval, for each category:

| Category | Action |
|----------|--------|
| Permissions | Edit `~/.claude/settings.json` |
| Commands | Create `~/.claude/commands/<name>.md` |
| CLAUDE.md | Edit file directly |
| Infrastructure | `mcp__github__create_issue()` |

Broadcast `improvement_suggested` for cross-repo learnings.
