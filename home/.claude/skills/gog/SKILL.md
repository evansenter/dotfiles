---
name: gog
description: "Use when working with Google Workspace - Gmail, Calendar, Drive, Docs, Sheets, Chat, Admin. Requires gws CLI (npm install -g @googleworkspace/cli)."
metadata:
  requires:
    bins: ["gws"]
---

# Google Workspace Integration

Interact with Google Workspace services via the `gws` CLI. The CLI dynamically discovers all Google APIs through Google's Discovery Service and exposes them as a unified interface.

## Prerequisites

```bash
npm install -g @googleworkspace/cli
gws auth login
```

To generate per-service SKILL.md files with full API details:
```bash
gws generate-skills
```

## Quick Reference

### Gmail
```bash
gws gmail +triage                           # Show unread inbox summary
gws gmail +send --to "user@example.com" --subject "Hi" --body "Hello"
gws gmail +read <message-id>                # Read a message
gws gmail +reply <message-id> --body "Thanks"
gws gmail +forward <message-id> --to "other@example.com"
gws gmail users messages list --params '{"q": "is:unread"}'
```

### Calendar
```bash
gws calendar +agenda                        # Show upcoming events
gws calendar +insert --summary "Meeting" --start "2026-03-18T10:00:00" --end "2026-03-18T11:00:00"
gws calendar events list --params '{"calendarId": "primary", "timeMin": "2026-03-18T00:00:00Z"}'
gws calendar events delete --params '{"calendarId": "primary", "eventId": "<id>"}'
```

### Drive
```bash
gws drive files list --params '{"q": "name contains '\''report'\''"}'
gws drive files get --params '{"fileId": "<id>"}'
```

### Sheets
```bash
gws sheets spreadsheets.values get --params '{"spreadsheetId": "<id>", "range": "Sheet1!A1:D10"}'
gws sheets spreadsheets.values update --params '{"spreadsheetId": "<id>", "range": "Sheet1!A1"}' --json '[["a","b"],["c","d"]]'
```

### Docs
```bash
gws docs documents get --params '{"documentId": "<id>"}'
```

### Chat
```bash
gws chat spaces list
gws chat spaces.messages list --params '{"parent": "spaces/<id>"}'
```

## Discovering Commands

Before calling any API method, inspect it:

```bash
# Browse all services
gws --help

# Browse resources and methods for a service
gws gmail --help

# Inspect a method's required params, types, and defaults
gws schema gmail.<resource>.<method>
```

Use `gws schema` output to build your `--params` and `--json` flags.

## Helper Commands

Helper commands (prefixed with `+`) are high-level shortcuts that compose multiple API calls:

```bash
gws gmail +send      # Send email
gws gmail +triage    # Unread inbox summary
gws gmail +reply     # Reply to message (handles threading)
gws gmail +read      # Read message body/headers
gws calendar +agenda # Upcoming events across calendars
gws calendar +insert # Create event
```

## Notes

- All commands output JSON by default — pipe through `jq` for formatting
- Auth tokens are stored locally after `gws auth login`
- If `gws` is not installed, inform the user and provide install instructions
- For full per-service skills with complete API documentation, run `gws generate-skills`
