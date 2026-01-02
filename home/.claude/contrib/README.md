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
