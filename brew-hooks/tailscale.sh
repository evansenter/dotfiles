#!/usr/bin/env bash
# Post-install hook for Tailscale
# Opens Tailscale.app if installed but not connected

set -euo pipefail

# macOS only - Tailscale is a cask
if [[ "$(uname)" != "Darwin" ]]; then
	exit 0
fi

if [[ ! -d "/Applications/Tailscale.app" ]]; then
	exit 0
fi

# Check if already connected
if /Applications/Tailscale.app/Contents/MacOS/Tailscale status >/dev/null 2>&1; then
	exit 0
fi

echo "Starting Tailscale..."
echo "  Sign in when prompted to join your tailnet."
open -a Tailscale
