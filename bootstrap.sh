#!/usr/bin/env bash
set -euo pipefail

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
	# Exclude .claude/hooks/, .claude/commands/, .claude/contrib/, and .claude/agents/ since we symlink those directories separately
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
	done < <(find "$dotfiles_dir/home" -type f -not -name ".DS_Store" -not -path "*/.claude/hooks/*" -not -path "*/.claude/commands/*" -not -path "*/.claude/contrib/*" -not -path "*/.claude/agents/*" -print0)
}

symlink_claude_dir() {
	local dir_name="$1"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local src_dir="$dotfiles_dir/home/.claude/$dir_name"
	local dest_dir="$HOME/.claude/$dir_name"

	if [[ ! -d "$src_dir" ]]; then
		return 0
	fi

	mkdir -p "$HOME/.claude"

	# Skip if already correctly symlinked
	if [[ -L "$dest_dir" && "$(readlink "$dest_dir")" == "$src_dir" ]]; then
		return 0
	fi

	# Remove existing directory/symlink if present
	if [[ -e "$dest_dir" || -L "$dest_dir" ]]; then
		rm -rf "$dest_dir"
	fi

	ln -s "$src_dir" "$dest_dir"
	echo "Linked: ~/.claude/$dir_name/"
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
	# LaunchAgents are macOS-only
	if [[ "$(uname)" != "Darwin" ]]; then
		echo "Skipping LaunchAgents (macOS-only)"
		return 0
	fi

	local launch_agents_dir="$HOME/Library/LaunchAgents"
	mkdir -p "$launch_agents_dir"

	# Install dark-notify LaunchAgent (only if dark-notify is installed)
	if command -v dark-notify >/dev/null 2>&1; then
		local plist="com.user.dark-notify.plist"
		local homebrew_prefix
		if command -v brew >/dev/null 2>&1 && homebrew_prefix="$(brew --prefix 2>/dev/null)"; then
			: # homebrew_prefix set by condition
		elif [[ "$(uname -m)" == "arm64" ]]; then
			homebrew_prefix="/opt/homebrew"
		else
			homebrew_prefix="/usr/local"
		fi
		local new_plist_content
		new_plist_content=$(sed -e "s|__HOME__|$HOME|g" -e "s|__HOMEBREW_PREFIX__|$homebrew_prefix|g" "LaunchAgents/$plist")
		local dest_plist="$launch_agents_dir/$plist"

		# Only update and reload if plist content changed
		local tmp_plist
		tmp_plist=$(mktemp)
		trap 'rm -f "$tmp_plist"' EXIT
		echo "$new_plist_content" > "$tmp_plist"

		if [[ ! -f "$dest_plist" ]] || ! cmp -s "$tmp_plist" "$dest_plist"; then
			echo "Installing LaunchAgent: $plist"
			mv "$tmp_plist" "$dest_plist"
			trap - EXIT

			# Reload the agent
			launchctl bootout "gui/$(id -u)/com.user.dark-notify" 2>/dev/null || true
			launchctl bootstrap "gui/$(id -u)" "$dest_plist"

			# Run the script once to set initial theme
			"$HOME/.bin/toggle-btop-theme"
		else
			rm -f "$tmp_plist"
			trap - EXIT
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
		if ! command -v git >/dev/null 2>&1; then
			echo "Skipping btop themes (git not installed)"
			return 0
		fi
		echo "Initializing submodules..."
		if ! git -C "$dotfiles_dir" submodule update --init; then
			echo "Skipping btop themes (failed to initialize submodules)"
			echo "  Run manually: git submodule update --init"
			return 0
		fi
		echo "Submodules initialized successfully"
	fi

	# Verify themes directory exists after initialization
	if [[ ! -d "$vendor_themes" ]]; then
		echo "Skipping btop themes (themes directory not found)"
		return 0
	fi

	mkdir -p "$btop_themes_dir"

	echo "Symlinking btop themes..."
	for theme in "$vendor_themes"/*.theme; do
		local name="$(basename "$theme")"
		ln -sf "$theme" "$btop_themes_dir/$name"
	done
}

install_bat_themes() {
	local bat_themes_dir="$HOME/.config/bat/themes"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local vendor_themes="$dotfiles_dir/vendor/bat-catppuccin/themes"

	if [[ ! -d "$vendor_themes" ]]; then
		echo "Skipping bat themes (submodule not initialized)"
		return 0
	fi

	mkdir -p "$bat_themes_dir"

	echo "Symlinking bat themes..."
	for theme in "$vendor_themes"/*.tmTheme; do
		local name="$(basename "$theme")"
		ln -sf "$theme" "$bat_themes_dir/$name"
	done

	# Rebuild bat cache if bat is installed (batcat on Debian/Ubuntu)
	local bat_cmd=""
	if command -v bat >/dev/null 2>&1; then
		bat_cmd="bat"
	elif command -v batcat >/dev/null 2>&1; then
		bat_cmd="batcat"
	fi

	if [[ -n "$bat_cmd" ]]; then
		echo "Rebuilding bat theme cache..."
		$bat_cmd cache --build
	fi
}

install_claude_mcp_servers() {
	if ! command -v claude >/dev/null 2>&1; then
		echo "Skipping MCP servers (claude not installed)"
		return 0
	fi

	local mcp_list
	mcp_list=$(claude mcp list 2>/dev/null || true)

	# Install GitHub MCP server if not configured
	if ! echo "$mcp_list" | grep -q "github"; then
		echo "Installing GitHub MCP server..."
		claude mcp add github -s user -e 'GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_TOKEN}' -- npx -y @modelcontextprotocol/server-github

		if [[ -z "$GITHUB_TOKEN" ]]; then
			echo "  Warning: GITHUB_TOKEN not set. Add to ~/.extra:"
			echo "    export GITHUB_TOKEN=\"ghp_your_token_here\""
		fi
	fi

	# Install/remove Notion MCP server based on NOTION_API_KEY availability
	if [[ -n "${NOTION_API_KEY:-}" ]]; then
		if ! echo "$mcp_list" | grep -q "notion"; then
			echo "Installing Notion MCP server..."
			claude mcp add notion -s user -e 'NOTION_TOKEN=${NOTION_API_KEY}' -- npx -y @notionhq/notion-mcp-server
		fi
	else
		if echo "$mcp_list" | grep -q "notion"; then
			echo "Removing Notion MCP server (NOTION_API_KEY not set)..."
			claude mcp remove notion -s user
		fi
	fi
}

sync_dotfiles() {
	# Symlink dotfiles from home/ directory to ~
	symlink_dotfiles

	# Symlink Claude Code directories
	symlink_claude_dir "hooks"
	symlink_claude_dir "commands"
	symlink_claude_dir "contrib"
	symlink_claude_dir "agents"
	symlink_claude_dir "skills"

	# Install Claude Code MCP servers
	install_claude_mcp_servers

	# Install tmux plugin manager if needed
	install_tmux_plugin_manager

	# Install btop themes from submodule
	install_btop_themes

	# Install bat themes from submodule
	install_bat_themes

	# Install LaunchAgents
	install_launch_agents

	# Reload zsh configuration
	if [[ -n "${ZSH_VERSION:-}" ]]; then
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
