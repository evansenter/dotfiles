#!/usr/bin/env bash

# ==============================================================================
# Bootstrap Script - Install Dotfiles
# ==============================================================================

# Change to the dotfiles directory
cd "$(dirname "${BASH_SOURCE}")";

# Pull latest changes from remote
git pull origin master;

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

sync_dotfiles() {
	# Sync dotfiles to home directory
	rsync \
		--exclude ".DS_Store" \
		--exclude ".git/" \
		--exclude ".gitignore" \
		--exclude ".claude/" \
		--exclude "CLAUDE.md" \
		--exclude "bootstrap.sh" \
		--exclude "uninstall.sh" \
		--exclude "LICENSE-MIT.txt" \
		--exclude "README.md" \
		--archive \
		--verbose \
		--human-readable \
		--force \
		--no-perms \
		. ~

	# Install tmux plugin manager if needed
	install_tmux_plugin_manager

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
