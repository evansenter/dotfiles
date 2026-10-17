#!/bin/bash
# Forward hook events to iTerm2's Claude Code status integration (cc-status)
#
# iTerm2 installs cc-status as ~/.config/iterm2/cc-status (a symlink into
# iTerm.app) and registers it on every hook event. settings.json is shared
# across machines, so this guard runs it only where it exists — elsewhere
# (Linux, Macs without iTerm2) it exits silently.
#
# Usage in settings.json hooks (any event):
#   iterm-cc-status.sh

set -euo pipefail

CC_STATUS="${ITERM_CC_STATUS:-$HOME/.config/iterm2/cc-status}"

if [[ ! -x "$CC_STATUS" ]]; then
    # Consume stdin (required for hooks — must be before any exit)
    cat > /dev/null
    exit 0
fi

# Hand stdin (the hook JSON) through untouched
exec "$CC_STATUS" "$@"
