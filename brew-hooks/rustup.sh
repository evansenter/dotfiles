#!/usr/bin/env bash
# Post-install hook for rustup
# Sets up default stable toolchain if not already configured

set -euo pipefail

if ! command -v rustup >/dev/null 2>&1; then
	exit 0
fi

# Check if any toolchain is already configured
if rustup show active-toolchain >/dev/null 2>&1; then
	exit 0
fi

echo "Setting up rustup default toolchain..."
rustup default stable
