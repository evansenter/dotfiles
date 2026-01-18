#!/usr/bin/env bash
# Post-install hook for iTerm2
# Sets up Dynamic Profiles from dotfiles

set -euo pipefail

if [[ ! -d "/Applications/iTerm.app" ]]; then
	exit 0
fi

dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
profile_src="$dotfiles_dir/preferences/iTerm Profile.json"
dynamic_profiles_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"

if [[ ! -f "$profile_src" ]]; then
	exit 0
fi

# Create DynamicProfiles directory if needed
mkdir -p "$dynamic_profiles_dir"

# Symlink profile for auto-loading
dest="$dynamic_profiles_dir/dotfiles-profile.json"
if [[ -L "$dest" && "$(readlink "$dest")" == "$profile_src" ]]; then
	exit 0
fi

if [[ -e "$dest" || -L "$dest" ]]; then
	rm -f "$dest"
fi

ln -s "$profile_src" "$dest"
echo "Linked iTerm2 profile to DynamicProfiles"
