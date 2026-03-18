---
name: gog
description: "Use when working with Google Workspace — Gmail, Calendar, Drive, Docs, Sheets, Chat, Tasks, Forms, Slides, Contacts. Also use when the user mentions email, checking mail, scheduling, meetings, shared documents, spreadsheets, or any Google service. Even if they don't say 'Google' explicitly — if they say 'check my email', 'what's on my calendar', 'find that doc', use this skill. Requires gog CLI (brew install gogcli/tap/gog)."
metadata:
  requires:
    bins: ["gog"]
---

# Google Workspace Integration (gog)

Interact with Google Workspace services via the `gog` CLI.

## Prerequisites

```bash
brew install gogcli/tap/gog
gog login your@email.com
```

## Quick Reference

### Gmail
```bash
gog gmail search "is:unread"                # Search unread messages
gog gmail search "from:boss subject:urgent" # Search with Gmail query syntax
gog gmail get <messageId>                   # Read a message
gog send --to "user@example.com" --subject "Hi" --body "Hello"
gog gmail messages reply <messageId> --body "Thanks"
```

### Calendar
```bash
gog calendar events                         # List upcoming events
gog calendar calendars                      # List calendars
gog calendar create <calendarId> --summary "Meeting" --start "2026-03-18T10:00" --end "2026-03-18T11:00"
```

### Drive
```bash
gog ls                                      # List Drive files
gog search "quarterly report"               # Search Drive
gog download <fileId>                       # Download a file
gog upload ./file.pdf                       # Upload a file
```

### Sheets
```bash
gog sheets get <spreadsheetId> --range "Sheet1!A1:D10"
gog sheets update <spreadsheetId> --range "Sheet1!A1" --values '[["a","b"]]'
```

### Docs
```bash
gog docs get <documentId>                   # Get document content
gog docs export <documentId> --format pdf   # Export as PDF
```

### Chat
```bash
gog chat spaces                             # List chat spaces
gog chat messages <spaceId>                 # List messages in a space
```

### Tasks
```bash
gog tasks list                              # List task lists
gog tasks get <taskListId>                  # Get tasks in a list
```

### Other Services
```bash
gog contacts list                           # Google Contacts
gog forms get <formId>                      # Google Forms
gog slides get <presentationId>             # Google Slides
gog classroom courses                       # Google Classroom
```

## Useful Flags

| Flag | Description |
|------|-------------|
| `-j, --json` | JSON output (best for scripting) |
| `-p, --plain` | TSV output (parseable, no colors) |
| `--results-only` | JSON mode: emit only primary result |
| `-n, --dry-run` | Preview without making changes |
| `-a, --account` | Specify account email |
| `--select` | Select specific JSON fields |

## Discovering Commands

```bash
gog --help                                  # All services
gog gmail --help                            # Gmail commands
gog calendar --help                         # Calendar commands
gog schema gmail.send                       # Machine-readable command schema
```

## Agent Helpers

```bash
gog agent exit-codes                        # Stable exit codes for scripting
gog schema <command>                        # JSON schema for any command
```

## Notes

- All commands support `-j` for JSON output — pipe through `jq` for formatting
- Use `gog login <email>` to add accounts, `gog status` to check auth
- Multiple accounts supported via `--account` flag
- If `gog` is not installed: `brew install gogcli/tap/gog`
