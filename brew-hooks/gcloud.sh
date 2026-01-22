#!/usr/bin/env bash
# Post-install hook for gcloud-cli
# Prompts for initialization if not configured

set -euo pipefail

if ! command -v gcloud >/dev/null 2>&1; then
	exit 0
fi

# Check if already configured (has an active account)
if gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null | grep -q "@"; then
	exit 0
fi

echo "gcloud-cli is not configured. Run 'gcloud init' to set up."
