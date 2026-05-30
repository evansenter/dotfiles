#!/bin/bash
# Print cached system load for the zjstatus sysload widget.
# Cache is populated by the com.evansenter.sysload LaunchAgent every 10s
# (~/.bin/sysload-writer). Synchronous `top` here would stack up under load
# because zjstatus spawns command widgets per tab — see CLAUDE.md.
CACHE="$HOME/.cache/sysload"
[ -s "$CACHE" ] && cat "$CACHE"
