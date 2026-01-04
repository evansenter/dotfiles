# Claude Code Contrib

User-contributed helper scripts and utilities for Claude Code.

This directory is symlinked to `~/.claude/contrib/` by `bootstrap.sh`.

## MCP Server Data

MCP servers store their data under subdirectories here:

| Directory | MCP Server | Purpose |
|-----------|------------|---------|
| `analytics/` | [session-analytics](https://github.com/evansenter/claude-session-analytics) | Session log analysis and workflow insights |
| `event-bus/` | [event-bus](https://github.com/evansenter/claude-event-bus) | Cross-session communication and coordination |

## Scripts

- `repo-stats.sh` - Show codebase size (LoC) and recent activity across repositories

## Session Analytics CLI

The `session-analytics-cli` provides command-line access to workflow insights. Key commands:

| Command | Description |
|---------|-------------|
| `frequency` | Tool usage frequency with breakdowns |
| `permissions` | Commands that may need adding to settings.json |
| `agents` | Agent/subagent activity and token usage |
| `trends` | Compare current vs previous period metrics |
| `classify` | Classify sessions by activity type (debugging, development, research, maintenance) |
| `failures` | Error patterns, rework detection, and recovery times |

**Usage:**
```bash
session-analytics-cli <command> [--days N] [--project PATH]
```

**Examples:**
```bash
session-analytics-cli frequency --days 7
session-analytics-cli agents --days 3
session-analytics-cli failures --days 1
```
