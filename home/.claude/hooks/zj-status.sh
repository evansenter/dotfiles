#!/bin/bash
# Update zjstatus notification based on Claude state
#
# Usage in settings.json hooks:
#   UserPromptSubmit: zj-status.sh working
#   Stop: zj-status.sh waiting
#
# Only runs if inside zellij

set -euo pipefail

# Skip if not in zellij
[[ -z "${ZELLIJ:-}" ]] && exit 0

# Consume stdin (required for hooks)
cat > /dev/null

STATE="${1:-waiting}"

case "$STATE" in
    working)
        zellij pipe "zjstatus::notify::⏳ working..." 2>/dev/null || true
        ;;
    waiting)
        # Clear notification by sending empty (zjstatus hides when no notifications)
        zellij pipe "zjstatus::notify::" 2>/dev/null || true
        ;;
    *)
        echo "zj-status.sh: unknown state '$STATE', expected 'working' or 'waiting'" >&2
        ;;
esac
