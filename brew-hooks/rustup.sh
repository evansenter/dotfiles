#!/usr/bin/env bash
# Post-install hook for rustup
# Sets up default stable toolchain if not already configured

set -euo pipefail

if ! command -v rustup >/dev/null 2>&1; then
	exit 0
fi

# Check if a default toolchain is already set
if rustup default 2>/dev/null | grep -q "stable"; then
	exit 0
fi

echo "Setting up rustup default toolchain..."
rustup default stable
