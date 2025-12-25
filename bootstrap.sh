#!/usr/bin/env bash

# ==============================================================================
# Bootstrap Script - Install Dotfiles
# ==============================================================================

# Change to the dotfiles directory
cd "$(dirname "${BASH_SOURCE}")";

# ==============================================================================
# Functions
# ==============================================================================

symlink_dotfiles() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

	# Find all files in home/ directory and create symlinks
	while IFS= read -r -d '' src_file; do
		# Get relative path from home/
		local rel_path="${src_file#$dotfiles_dir/home/}"
		local dest_file="$HOME/$rel_path"

		# Create parent directory if needed
		mkdir -p "$(dirname "$dest_file")"

		# Skip if already correctly symlinked
		if [[ -L "$dest_file" && "$(readlink "$dest_file")" == "$src_file" ]]; then
			continue
		fi

		# Remove existing file/symlink if present
		if [[ -e "$dest_file" || -L "$dest_file" ]]; then
			rm -f "$dest_file"
		fi

		# Create symlink
		ln -s "$src_file" "$dest_file"
		echo "Linked: ~/$rel_path"
	done < <(find "$dotfiles_dir/home" -type f -not -name ".DS_Store" -print0)
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
		local tmp_plist
		tmp_plist=$(mktemp)
		echo "$new_plist_content" > "$tmp_plist"

		if [[ ! -f "$dest_plist" ]] || ! cmp -s "$tmp_plist" "$dest_plist"; then
			echo "Installing LaunchAgent: $plist"
			mv "$tmp_plist" "$dest_plist"

			# Reload the agent
			launchctl bootout "gui/$(id -u)/com.user.dark-notify" 2>/dev/null || true
			launchctl bootstrap "gui/$(id -u)" "$dest_plist"

			# Run the script once to set initial theme
			"$HOME/.bin/toggle-btop-theme"
		else
			rm -f "$tmp_plist"
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

sync_dotfiles() {
	# Symlink dotfiles from home/ directory to ~
	symlink_dotfiles

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

# Parse arguments
FORCE=false
PULL=false
for arg in "$@"; do
	case "$arg" in
		--force|-f) FORCE=true ;;
		--pull|-p) PULL=true ;;
		--help|-h)
			echo "Usage: ./bootstrap.sh [OPTIONS]"
			echo ""
			echo "Install dotfiles from home/ to ~"
			echo ""
			echo "Options:"
			echo "  -f, --force  Skip confirmation prompt"
			echo "  -p, --pull   Pull latest changes before installing"
			echo "  -h, --help   Show this help message"
			exit 0
			;;
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
	read -p "This will replace existing dotfiles with symlinks. Are you sure? (y/n) " -n 1
	echo ""
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		sync_dotfiles
	fi
fi
