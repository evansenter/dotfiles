#!/usr/bin/env bash

# ==============================================================================
# Bootstrap Script - Install Dotfiles
# ==============================================================================

# Change to the dotfiles directory
cd "$(dirname "${BASH_SOURCE}")";

# ==============================================================================
# Functions
# ==============================================================================

check_newer_local_files() {
	local newer_files=()
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

	# Check if diff supports --color
	local diff_cmd="diff -u"
	if diff --color=auto -u /dev/null /dev/null &>/dev/null; then
		diff_cmd="diff --color=auto -u"
	fi

	# Find all files in home/ directory
	while IFS= read -r -d '' src_file; do
		# Get relative path from home/
		local rel_path="${src_file#$dotfiles_dir/home/}"
		local dest_file="$HOME/$rel_path"

		# Skip files that are merged separately, not overwritten
		[[ "$rel_path" == ".claude/hooks.json" ]] && continue

		# Skip if destination doesn't exist
		[[ ! -e "$dest_file" ]] && continue

		# Check if destination is newer than source
		if [[ "$dest_file" -nt "$src_file" ]]; then
			newer_files+=("$rel_path")
		fi
	done < <(find "$dotfiles_dir/home" -type f -print0)

	# Return success if no newer files found
	if [[ ${#newer_files[@]} -eq 0 ]]; then
		return 0
	fi

	# Warn about newer local files
	echo ""
	echo "Warning: The following files in ~ are newer than their repo versions:"
	echo ""

	for file in "${newer_files[@]}"; do
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo "~/$file"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		# Show diff: repo version vs local version (what would be lost)
		$diff_cmd "$dotfiles_dir/home/$file" "$HOME/$file" || true
		echo ""
	done

	return 1
}

install_tmux_plugin_manager() {
	local tpm_dir="$HOME/.tmux/plugins/tpm"

	if [[ -e "$tpm_dir" ]]; then
		return 0
	fi

	echo "Installing tmux plugin manager..."
	mkdir -p "$tpm_dir"
	git clone https://github.com/tmux-plugins/tpm "$tpm_dir"

	# Source tmux config if tmux is installed
	if command -v tmux >/dev/null 2>&1 && [[ -e "$HOME/.tmux.conf" ]]; then
		tmux source "$HOME/.tmux.conf"
	fi
}

install_launch_agents() {
	local launch_agents_dir="$HOME/Library/LaunchAgents"
	mkdir -p "$launch_agents_dir"

	# Install dark-notify LaunchAgent (only if dark-notify is installed)
	if command -v dark-notify >/dev/null 2>&1; then
		local plist="com.user.dark-notify.plist"
		local new_plist_content
		new_plist_content=$(sed "s|__HOME__|$HOME|g" "LaunchAgents/$plist")
		local dest_plist="$launch_agents_dir/$plist"

		# Only update and reload if plist content changed
		if [[ ! -f "$dest_plist" ]] || [[ "$(cat "$dest_plist")" != "$new_plist_content" ]]; then
			echo "Installing LaunchAgent: $plist"
			echo "$new_plist_content" > "$dest_plist"

			# Reload the agent
			launchctl bootout "gui/$(id -u)/com.user.dark-notify" 2>/dev/null || true
			launchctl bootstrap "gui/$(id -u)" "$dest_plist"

			# Run the script once to set initial theme
			"$HOME/.bin/toggle-btop-theme"
		fi
	else
		echo "Skipping dark-notify LaunchAgent (dark-notify not installed)"
		echo "  Install with: brew install cormacrelf/tap/dark-notify"
	fi
}

pull_latest() {
	echo "Pulling latest changes from origin/main..."
	git pull origin main
}

install_btop_themes() {
	local btop_themes_dir="$HOME/.config/btop/themes"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local vendor_themes="$dotfiles_dir/vendor/btop-catppuccin/themes"

	if [[ ! -d "$vendor_themes" ]]; then
		echo "Skipping btop themes (submodule not initialized)"
		echo "  Run: git submodule update --init"
		return 0
	fi

	mkdir -p "$btop_themes_dir"

	echo "Symlinking btop themes..."
	for theme in "$vendor_themes"/*.theme; do
		local name="$(basename "$theme")"
		ln -sf "$theme" "$btop_themes_dir/$name"
	done
}

merge_claude_hooks() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local hooks_src="$dotfiles_dir/home/.claude/hooks.json"
	local dest="$HOME/.claude/settings.json"

	if ! command -v jq >/dev/null 2>&1; then
		echo "Skipping Claude hooks merge (jq not installed)"
		echo "  Install with: brew install jq"
		return 0
	fi

	mkdir -p "$HOME/.claude"

	# Create settings.json if it doesn't exist
	if [[ ! -f "$dest" ]]; then
		cp "$hooks_src" "$dest"
		echo "Created ~/.claude/settings.json with hooks"
		return 0
	fi

	# Merge hooks from repo into existing settings
	echo "Merging Claude hooks into settings.json..."
	jq -s '.[1] * {hooks: .[0].hooks}' "$hooks_src" "$dest" > "$dest.tmp" \
		&& mv "$dest.tmp" "$dest"
}

sync_dotfiles() {
	# Sync dotfiles from home/ directory to ~
	# Note: hooks.json is excluded and merged separately to preserve local settings
	rsync \
		--exclude ".DS_Store" \
		--exclude ".claude/hooks.json" \
		--archive \
		--verbose \
		--human-readable \
		--force \
		--no-perms \
		home/ ~

	# Install tmux plugin manager if needed
	install_tmux_plugin_manager

	# Merge Claude hooks into settings.json
	merge_claude_hooks

	# Install btop themes from submodule
	install_btop_themes

	# Install LaunchAgents
	install_launch_agents

	# Reload zsh configuration
	if [[ -n "$ZSH_VERSION" ]]; then
		source ~/.zshrc 2>/dev/null || echo "Restart your terminal or run: source ~/.zshrc"
	fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

# Parse arguments
FORCE=false
PULL=false
for arg in "$@"; do
	case "$arg" in
		--force|-f) FORCE=true ;;
		--pull|-p) PULL=true ;;
	esac
done

# Pull if requested
if [[ "$PULL" == true ]]; then
	pull_latest
fi

# Run with or without confirmation
if [[ "$FORCE" == true ]]; then
	sync_dotfiles
else
	read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		# Check for newer local files
		if ! check_newer_local_files; then
			read -p "These local changes will be overwritten. Continue anyway? (y/n) " -n 1
			echo ""
			if [[ ! $REPLY =~ ^[Yy]$ ]]; then
				echo "Aborted."
				exit 1
			fi
		fi
		sync_dotfiles
	fi
fi
