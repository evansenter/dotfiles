---
name: gog
description: Use when working with Google Workspace - Gmail, Calendar, Drive, Docs, Sheets. Requires gws CLI to be installed.
---

# Google Workspace Integration (gog)

Interact with Google Workspace services via the `gws` CLI.

## Prerequisites

Install the gws CLI:
```bash
npm install -g gws-cli
```

First run requires OAuth authentication:
```bash
gws auth login
```

## Available Services

### Gmail
```bash
gws gmail messages list --query "is:unread"
gws gmail messages get <id>
gws gmail messages send --to "user@example.com" --subject "Subject" --body "Body"
gws gmail drafts create --to "user@example.com" --subject "Subject" --body "Body"
```

### Calendar
```bash
gws calendar events list --calendar-id primary --time-min "2026-03-18T00:00:00Z"
gws calendar events create --calendar-id primary --summary "Meeting" --start "2026-03-18T10:00:00" --end "2026-03-18T11:00:00"
gws calendar events delete --calendar-id primary --event-id <id>
```

### Drive
```bash
gws drive files list --query "name contains 'report'"
gws drive files get <file-id>
gws drive files upload --file <path> --parent <folder-id>
```

### Sheets
```bash
gws sheets values get --spreadsheet-id <id> --range "Sheet1!A1:D10"
gws sheets values update --spreadsheet-id <id> --range "Sheet1!A1" --values '[["a","b"],["c","d"]]'
```

### Docs
```bash
gws docs get --document-id <id>
gws docs create --title "New Document" --body "Content"
```

## Notes

- All commands output JSON by default — pipe through `jq` for formatting
- Use `gws <service> --help` to discover all available commands
- The CLI dynamically discovers Google APIs, so new services may be available
- If `gws` is not installed, inform the user and provide install instructions above
