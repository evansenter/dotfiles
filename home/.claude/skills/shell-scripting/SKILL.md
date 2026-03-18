---
name: shell-scripting
description: |
  Shell script conventions for bash/zsh. Auto-applies when writing or editing
  .sh files, shell functions, aliases, scripts in bin/, or any bash/zsh code
  including heredocs, pipes, and one-liners in other contexts. Use whenever
  writing shell code, even inline in Makefiles, hooks, or CI configs.
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
---

# Shell Scripting Patterns

This skill auto-applies when writing shell scripts. Follow these conventions.

## Script Header

All bash scripts must start with:

```bash
#!/bin/bash
set -euo pipefail
```

Zsh scripts (`.zshrc`, `.zsh_prompt`, etc.) don't use `set -euo pipefail` — it breaks interactive shell behavior.

## Platform Detection

```bash
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
else
    # Linux
fi
```

For commands that differ between platforms (e.g., `sed -i` on macOS needs `''`):

```bash
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/old/new/" "$file"
else
    sed -i "s/old/new/" "$file"
fi
```

## Command Availability

Always check before using optional commands:

```bash
command -v foo >/dev/null 2>&1 && foo_available=true || foo_available=false

# Or for guard clauses:
if ! command -v foo &>/dev/null; then
    echo "Skipping (foo not installed)"
    return 0  # or exit 0 in scripts
fi
```

## Idempotency

Scripts should be safe to run repeatedly:

```bash
# Symlinks: -sf overwrites existing
ln -sf "$source" "$dest"

# Directories: -p is no-op if exists
mkdir -p "$dir"

# Only install if missing
if ! command -v foo &>/dev/null; then
    install_foo
fi
```

## Variables

- Quote all variable expansions: `"$var"`, `"${var}"`, `"$@"`
- Use `${var:-default}` for optional variables with defaults
- Use `${var:?error message}` for required variables
- Use `local` in functions: `local result="$(command)"`

## Output

- Use `echo` for user-facing messages
- Use `>&2` for errors: `echo "Error: failed" >&2`
- Silent success is fine for automation scripts
- Use `|| true` to suppress expected failures

## ShellCheck

All `.sh` files must pass `shellcheck`. Common directives:

```bash
# shellcheck disable=SC2034  # Variable appears unused (but is exported/sourced)
# shellcheck source=/dev/null  # Can't follow dynamic source
```
