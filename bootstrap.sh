#!/usr/bin/env bash

# ==============================================================================
# Bootstrap Script - Install Dotfiles
# ==============================================================================

# Change to the dotfiles directory
cd "$(dirname "${BASH_SOURCE}")";

# Pull latest changes from remote
git pull origin main;

# ==============================================================================
# Functions
# ==============================================================================

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
		echo "Installing LaunchAgent: $plist"
		sed "s|__HOME__|$HOME|g" "LaunchAgents/$plist" > "$launch_agents_dir/$plist"

		# Load the agent if not already loaded
		launchctl bootout "gui/$(id -u)/com.user.dark-notify" 2>/dev/null || true
		launchctl bootstrap "gui/$(id -u)" "$launch_agents_dir/$plist"

		# Run the script once to set initial theme
		"$HOME/.bin/toggle-btop-theme"
	else
		echo "Skipping dark-notify LaunchAgent (dark-notify not installed)"
		echo "  Install with: brew install cormacrelf/tap/dark-notify"
	fi
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

sync_dotfiles() {
	# Sync dotfiles from home/ directory to ~
	rsync \
		--exclude ".DS_Store" \
		--archive \
		--verbose \
		--human-readable \
		--force \
		--no-perms \
		home/ ~

	# Install tmux plugin manager if needed
	install_tmux_plugin_manager

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

# Run with or without confirmation
if [[ "$1" == "--force" || "$1" == "-f" ]]; then
	sync_dotfiles
else
	read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		sync_dotfiles
	fi
fi
