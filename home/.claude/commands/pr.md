---
argument-hint: <create | local | remote>
description: PR workflow dispatcher (prefer /pr-create and /pr-review)
---

# PR (Dispatcher)

**Note**: This command dispatches to `/pr-create` and `/pr-review`. Consider using those directly:
- `/pr-create` - Commit and create/update PR
- `/pr-review local` - Self-review before pushing
- `/pr-review remote` - Process reviewer comments after CI

## Usage

```
/pr <create | local | remote>
```

## Instructions

Parse the subcommand from the first argument:

```bash
SUBCOMMAND="$1"
```

Dispatch to the appropriate command:

### `create`
Forward to `/pr-create`:
```
Skill(pr-create)
```

### `local`
Forward to `/pr-review local`:
```
/pr-review local
```

### `remote`
Forward to `/pr-review remote`:
```
/pr-review remote
```

### Invalid or missing subcommand

```
echo "Usage: /pr <create | local | remote>"
echo ""
echo "Preferred commands:"
echo "  /pr-create        - Commit and create/update PR"
echo "  /pr-review local  - Self-review before pushing"
echo "  /pr-review remote - Process reviewer comments after CI"
```
