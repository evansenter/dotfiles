#!/usr/bin/env bash
# Post-install hook for Stats app
# Imports Stats preferences from dotfiles

set -euo pipefail

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
plist_src="$dotfiles_dir/preferences/Stats.plist"

if [[ ! -f "$plist_src" ]]; then
	exit 0
fi

# Only run on macOS
if [[ "$(uname)" != "Darwin" ]]; then
	exit 0
fi

echo "Importing Stats preferences..."
# Close Stats app if running to ensure it picks up the new config on restart
killall Stats 2>/dev/null || true

defaults import eu.exelban.Stats "$plist_src"
