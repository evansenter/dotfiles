#!/bin/bash
# Print cached system load for the zjstatus sysload widget.
# Cache is populated by the com.evansenter.sysload LaunchAgent every 10s
# (~/.bin/sysload-writer). Synchronous `top` here would stack up under load
# because zjstatus spawns command widgets per tab — see CLAUDE.md.
CACHE="$HOME/.cache/sysload"
# Blank the widget if the writer LaunchAgent has gone silent (cache older than
# ~2min) so an outage is visible instead of showing forever-stale numbers.
if [ -s "$CACHE" ] && find "$CACHE" -mmin -2 2>/dev/null | grep -q .; then
    cat "$CACHE"
fi
