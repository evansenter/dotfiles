#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Bootstrap Script - Install Dotfiles
# ==============================================================================

# Change to the dotfiles directory
cd "$(dirname "${BASH_SOURCE}")";

# ==============================================================================
# Constants
# ==============================================================================

GATEWAY_HOST="mac-mini.tailac7b3c.ts.net"
INSTALL_AI=""

# Set up Homebrew environment variables
if [[ "$(uname)" == "Darwin" ]]; then
	if [[ -f "/opt/homebrew/bin/brew" ]]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [[ -f "/usr/local/bin/brew" ]]; then
		eval "$(/usr/local/bin/brew shellenv)"
	fi
fi


# ==============================================================================
# Functions
# ==============================================================================

is_steamos() {
	[[ -f /etc/os-release ]] && grep -q '^ID=steamos' /etc/os-release
}

# Returns 0 on the gateway host (mac-mini). Tolerates the macOS Bonjour "-N"
# LocalHostName suffix appended on mDNS name collisions (e.g. "mac-mini-2"),
# which a bare `== "mac-mini"` match would silently fail. See event-bus gotcha-4099.
is_gateway_host() {
	[[ "${HOSTNAME%%.*}" =~ ^mac-mini(-[0-9]+)?$ ]]
}

set_default_shell() {
	local zsh_path
	zsh_path="$(command -v zsh 2>/dev/null)" || return 0

	# Skip if already using zsh (getent on Linux, dscl on macOS)
	local current_shell
	if command -v getent >/dev/null 2>&1; then
		current_shell="$(getent passwd "$(whoami)" | cut -d: -f7)"
	elif command -v dscl >/dev/null 2>&1; then
		current_shell="$(dscl . -read /Users/"$(whoami)" UserShell | awk '{print $2}')"
	else
		current_shell=""
	fi
	if [[ "$current_shell" == "$zsh_path" ]]; then
		return 0
	fi

	# chsh requires manual password entry on macOS unless run as root.
	# Skip in non-interactive sessions to avoid hanging.
	if [[ ! -t 0 ]]; then
		echo "Warning: Cannot change default shell to zsh automatically in non-interactive mode."
		echo "  Please run manually: chsh -s $zsh_path"
		return 0
	fi

	echo "Setting default shell to zsh..."
	if chsh -s "$zsh_path" 2>/dev/null; then
		echo "Default shell set to zsh"
	elif sudo -n chsh -s "$zsh_path" "$(whoami)" 2>/dev/null; then
		echo "Default shell set to zsh (via sudo)"
	elif sudo -n usermod -s "$zsh_path" "$(whoami)" 2>/dev/null; then
		echo "Default shell set to zsh (via usermod)"
	else
		echo "Warning: Could not set default shell to zsh"
		echo "  Run manually: chsh -s $zsh_path"
	fi
}

# Install a pre-built binary from a GitHub release tarball to ~/.local/bin
# Usage: install_github_binary "owner/repo" "binary_name" "tarball_pattern" ["strip_components"]
install_github_binary() {
	local repo="$1"
	local binary="$2"
	local pattern="$3"
	local strip="${4:-0}"

	if command -v "$binary" >/dev/null 2>&1; then
		return 0
	fi

	# Use GITHUB_TOKEN if available to avoid API rate limits (60/hr unauthenticated)
	local auth_header=()
	if [[ -n "${GITHUB_TOKEN:-}" ]]; then
		auth_header=(-H "Authorization: token $GITHUB_TOKEN")
	fi

	local version
	version=$(curl -fsSL "${auth_header[@]}" "https://api.github.com/repos/$repo/releases/latest" | grep -Po '"tag_name": "\K[^"]*') || {
		echo "  Warning: Failed to fetch latest version for $repo"
		return 1
	}

	local url="https://github.com/$repo/releases/download/$version/$pattern"
	# Substitute {version} and {version_no_v} in pattern
	local version_no_v="${version#v}"
	url="${url//\{version\}/$version}"
	url="${url//\{version_no_v\}/$version_no_v}"

	echo "Installing $binary $version..."
	local tmp
	tmp=$(mktemp -d)

	mkdir -p "$tmp/extracted"
	if [[ "$url" == *.zip ]]; then
		curl -fsSL "$url" -o "$tmp/archive.zip" || { echo "  Warning: Download failed for $binary"; rm -rf "$tmp"; return 1; }
		unzip -q "$tmp/archive.zip" -d "$tmp/extracted"
	elif [[ "$url" == *.tar.xz ]] || [[ "$url" == *.txz ]]; then
		curl -fsSL "$url" -o "$tmp/archive.tar.xz" || { echo "  Warning: Download failed for $binary"; rm -rf "$tmp"; return 1; }
		tar xf "$tmp/archive.tar.xz" -C "$tmp/extracted" --strip-components="$strip"
	elif [[ "$url" == *.tar.gz ]] || [[ "$url" == *.tgz ]]; then
		curl -fsSL "$url" -o "$tmp/archive.tar.gz" || { echo "  Warning: Download failed for $binary"; rm -rf "$tmp"; return 1; }
		tar xf "$tmp/archive.tar.gz" -C "$tmp/extracted" --strip-components="$strip"
	elif [[ "$url" == *.tbz ]] || [[ "$url" == *.tar.bz2 ]]; then
		curl -fsSL "$url" -o "$tmp/archive.tbz" || { echo "  Warning: Download failed for $binary"; rm -rf "$tmp"; return 1; }
		tar xf "$tmp/archive.tbz" -C "$tmp/extracted" --strip-components="$strip"
	else
		echo "  Warning: Unknown archive format for $url"
		rm -rf "$tmp"
		return 1
	fi

	# Find and install the binary
	local found
	found=$(find "$tmp/extracted" -name "$binary" -type f 2>/dev/null | head -1)
	if [[ -n "$found" ]]; then
		chmod +x "$found"
		mv "$found" "$HOME/.local/bin/$binary"
	else
		echo "  Warning: $binary not found in archive"
		rm -rf "$tmp"
		return 1
	fi

	rm -rf "$tmp"
}

symlink_dotfiles() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

	# Find all files in home/ directory and create symlinks
	# Exclude .claude/{hooks,commands,contrib,agents,skills}/ since we symlink those directories separately
	while IFS= read -r -d '' src_file; do
		# Get relative path from home/
		local rel_path="${src_file#$dotfiles_dir/home/}"
		local dest_file="$HOME/$rel_path"

		# Create parent directory if needed, then resolve through symlinks to detect
		# when a parent dir is symlinked back into the repo
		local dest_parent
		dest_parent="$(dirname "$dest_file")"
		mkdir -p "$dest_parent"
		local dest_dir
		dest_dir="$(cd "$dest_parent" && pwd -P)" || {
			echo "  Warning: cannot resolve $dest_parent, skipping ~/$rel_path"
			continue
		}
		local resolved_dest="$dest_dir/$(basename "$dest_file")"

		# Skip if destination resolves back to the source (parent dir is symlinked into repo)
		if [[ "$resolved_dest" == "$src_file" ]]; then
			echo "Skipped: ~/$rel_path (parent dir symlinked into repo)"
			continue
		fi

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
	done < <(find "$dotfiles_dir/home" -type f -not -name ".DS_Store" -not -path "*/.claude/hooks/*" -not -path "*/.claude/commands/*" -not -path "*/.claude/contrib/*" -not -path "*/.claude/agents/*" -not -path "*/.claude/skills/*" -not -path "*/.openclaw/*" -print0)
}

symlink_claude_dir() {
	local dir_name="$1"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
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

ensure_openclaw_workspace() {
	local dest_dir="$HOME/.openclaw/workspace"

	if [[ -d "$dest_dir" ]]; then
		return 0
	fi

	# Create the workspace directory so OpenClaw finds it on first run.
	# Content files (SOUL.md, AGENTS.md, etc.) are personal and created
	# locally via `openclaw configure`, not tracked in dotfiles.
	mkdir -p "$dest_dir"
	echo "Created: ~/.openclaw/workspace/"
}

symlink_openclaw_config() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
	local src_file="$dotfiles_dir/home/.openclaw/openclaw.json"
	local dest_file="$HOME/.openclaw/openclaw.json"

	if [[ ! -f "$src_file" ]]; then
		return 0
	fi

	mkdir -p "$HOME/.openclaw"

	# Skip if local config exists (gateway host keeps its own config)
	if [[ -f "$dest_file" && ! -L "$dest_file" ]]; then
		echo "Skipped: ~/.openclaw/openclaw.json (local gateway config exists)"
		return 0
	fi

	# Skip if already correctly symlinked
	if [[ -L "$dest_file" && "$(readlink "$dest_file")" == "$src_file" ]]; then
		install_openclaw_cli
		return 0
	fi

	# Ask if this is the gateway host or a remote client
	# Default to remote client when non-interactive (CI, scripts, -f flag)
	if [[ ! -e "$dest_file" ]]; then
		if [[ -t 0 ]]; then
			echo ""
			echo "OpenClaw setup:"
			echo "  1) Remote client - connect to existing gateway (default)"
			echo "  2) Gateway host - run the gateway on this machine"
			read -p "Choose [1/2]: " -n 1 -r openclaw_choice
			echo ""

			if [[ "$openclaw_choice" == "2" ]]; then
				echo "Skipped: ~/.openclaw/openclaw.json (run 'openclaw configure' to set up gateway)"
				return 0
			fi
		fi
	fi

	# Remove existing symlink if present
	if [[ -L "$dest_file" ]]; then
		rm -f "$dest_file"
	fi

	ln -s "$src_file" "$dest_file"
	echo "Linked: ~/.openclaw/openclaw.json (remote client config)"

	install_openclaw_cli
}

# Install an npm package globally with graceful error handling
# Usage: install_npm_package "package-name" "Display Name" ["package@version"]
install_npm_package() {
	local package="$1"
	local display_name="${2:-$package}"
	local install_spec="${3:-$package}"

	if ! command -v npm >/dev/null 2>&1; then
		echo "Skipping $display_name (npm not installed)"
		return 0
	fi

	# Check if already installed
	if command -v "$package" >/dev/null 2>&1; then
		return 0
	fi

	echo "Installing $display_name..."
	# Clean up stale npm temp directories that cause install failures
	local npm_prefix
	npm_prefix="$(npm config get prefix 2>/dev/null)"
	if [[ -n "$npm_prefix" && -d "$npm_prefix/lib/node_modules" ]]; then
		find "$npm_prefix/lib/node_modules" -maxdepth 1 -name ".${package}-*" -type d -mmin +60 -exec rm -rf {} + 2>/dev/null || true
	fi
	# Use explicit registry to avoid custom registry misconfigurations
	if ! npm install -g --registry https://registry.npmjs.org/ "$install_spec" 2>&1; then
		echo ""
		echo "Warning: Failed to install $display_name"
		echo "  This may be due to npm authentication issues."
		echo "  To fix, run:"
		echo "    npm login --registry https://registry.npmjs.org/"
		echo "    npm install -g $install_spec"
		echo ""
		return 0  # Continue bootstrap despite failure
	fi
}

install_openclaw_cli() {
	install_npm_package "openclaw" "OpenClaw CLI" "openclaw"
}

configure_claude_local_settings() {
	# On remote clients, Claude Code's tracked settings.json has localhost MCP URLs
	# (correct for mac-mini gateway host). Override with Tailscale URLs in the
	# untracked settings.local.json so remote machines reach services over the network.
	local settings_local="$HOME/.claude/settings.local.json"

	# Skip if this is the gateway host (services run locally)
	if is_gateway_host; then
		return 0
	fi

	# Skip if settings.local.json already has MCP URLs configured
	if [[ -f "$settings_local" ]] && grep -q "AGENT_EVENT_BUS_URL" "$settings_local" 2>/dev/null; then
		return 0
	fi

	mkdir -p "$HOME/.claude"

	if [[ -f "$settings_local" ]]; then
		# Merge env into existing settings.local.json
		if command -v jq &>/dev/null; then
			local tmp
			tmp=$(mktemp)
			if jq --arg bus "https://${GATEWAY_HOST}/agent-event-bus/mcp" \
			   --arg analytics "https://${GATEWAY_HOST}/agent-session-analytics/mcp" \
			   '.env = (.env // {}) + {"AGENT_EVENT_BUS_URL": $bus, "AGENT_SESSION_ANALYTICS_URL": $analytics}' \
			   "$settings_local" > "$tmp" 2>/dev/null; then
				mv "$tmp" "$settings_local"
				echo "Updated: ~/.claude/settings.local.json (remote MCP URLs)"
			else
				rm -f "$tmp"
				echo "Warning: Failed to merge into settings.local.json (invalid JSON?)"
				echo "  Manually add AGENT_EVENT_BUS_URL and AGENT_SESSION_ANALYTICS_URL"
			fi
		else
			echo "Warning: jq not found, cannot update settings.local.json"
			echo "  Manually add AGENT_EVENT_BUS_URL and AGENT_SESSION_ANALYTICS_URL"
		fi
	else
		# Create new settings.local.json
		cat > "$settings_local" << EOF
{
  "env": {
    "AGENT_EVENT_BUS_URL": "https://${GATEWAY_HOST}/agent-event-bus/mcp",
    "AGENT_SESSION_ANALYTICS_URL": "https://${GATEWAY_HOST}/agent-session-analytics/mcp"
  }
}
EOF
		echo "Created: ~/.claude/settings.local.json (remote MCP URLs)"
	fi
}

install_tmux_plugin_manager() {
	local tpm_dir="$HOME/.tmux/plugins/tpm"

	if [[ -e "$tpm_dir" ]]; then
		return 0
	fi

	echo "Installing tmux plugin manager..."
	mkdir -p "$tpm_dir"
	git clone https://github.com/tmux-plugins/tpm "$tpm_dir"

	# Source tmux config if tmux is installed and running
	if command -v tmux >/dev/null 2>&1 && tmux info &>/dev/null && [[ -e "$HOME/.tmux.conf" ]]; then
		tmux source "$HOME/.tmux.conf" || true
	fi
}

install_launch_agent() {
	local plist="$1"
	local label="${plist%.plist}"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
	local launch_agents_dir="$HOME/Library/LaunchAgents"

	mkdir -p "$launch_agents_dir"
	mkdir -p "$HOME/.local/log"

	local new_plist_content
	new_plist_content=$(sed "s|__HOME__|$HOME|g" "$dotfiles_dir/LaunchAgents/$plist")
	local dest_plist="$launch_agents_dir/$plist"

	# Only update and reload if plist content changed
	local tmp_plist
	tmp_plist=$(mktemp)
	echo "$new_plist_content" > "$tmp_plist"

	if [[ ! -f "$dest_plist" ]] || ! cmp -s "$tmp_plist" "$dest_plist"; then
		echo "Installing LaunchAgent: $plist"
		mv "$tmp_plist" "$dest_plist"

		# Reload the agent
		launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
		launchctl bootstrap "gui/$(id -u)" "$dest_plist" || true
	else
		rm -f "$tmp_plist"
	fi
}

install_launch_agents() {
	# LaunchAgents are macOS-only
	if [[ "$(uname)" != "Darwin" ]]; then
		return 0
	fi

	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

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
		new_plist_content=$(sed -e "s|__HOME__|$HOME|g" -e "s|__HOMEBREW_PREFIX__|$homebrew_prefix|g" "$dotfiles_dir/LaunchAgents/$plist")
		local dest_plist="$HOME/Library/LaunchAgents/$plist"

		mkdir -p "$HOME/Library/LaunchAgents"

		local tmp_plist
		tmp_plist=$(mktemp)
		echo "$new_plist_content" > "$tmp_plist"

		if [[ ! -f "$dest_plist" ]] || ! cmp -s "$tmp_plist" "$dest_plist"; then
			echo "Installing LaunchAgent: $plist"
			mv "$tmp_plist" "$dest_plist"

			launchctl bootout "gui/$(id -u)/com.user.dark-notify" 2>/dev/null || true
			launchctl bootstrap "gui/$(id -u)" "$dest_plist" || true

			"$HOME/.bin/toggle-btop-theme"
		else
			rm -f "$tmp_plist"
		fi
	else
		echo "Skipping dark-notify LaunchAgent (dark-notify not installed)"
		echo "  Install with: brew install cormacrelf/tap/dark-notify"
	fi

	# Install cargo-sweep LaunchAgent (only if cargo is installed)
	if command -v cargo >/dev/null 2>&1; then
		install_launch_agent "com.user.cargo-sweep.plist"
	fi

	# Install Obsidian MCP LaunchAgent (only on gateway host where the server runs)
	if is_gateway_host && command -v obsidian-mcp-server >/dev/null 2>&1; then
		install_launch_agent "com.evansenter.obsidian-mcp.plist"
	fi

	# Install sysload writer LaunchAgent (only if zellij is installed)
	# Caches `top` output to ~/.cache/sysload every 10s so the zjstatus
	# sysload widget can read it without spawning `top` per-tab-per-redraw.
	if command -v zellij >/dev/null 2>&1; then
		install_launch_agent "com.evansenter.sysload.plist"
	fi
}

cleanup_legacy_cron() {
	# cargo-sweep is handled by LaunchAgent (com.user.cargo-sweep.plist)
	# Remove legacy cron entry if present
	if crontab -l 2>/dev/null | grep -qF "cargo-sweep-all"; then
		echo "Removing legacy cargo-sweep cron job (now a LaunchAgent)..."
		crontab -l 2>/dev/null | grep -vF "cargo-sweep-all" | crontab -
	fi
}

pull_latest() {
	echo "Pulling latest changes from origin/main..."
	git pull origin main
}

prompt_ai_install() {
	# Ask once whether to install AI assistant packages (Claude, OpenClaw).
	# Result is cached in INSTALL_AI for the rest of the run.
	if [[ -n "$INSTALL_AI" ]]; then
		return 0
	fi

	# Non-interactive: default to skip
	if [[ ! -t 0 ]]; then
		INSTALL_AI=false
		return 0
	fi

	# Skip prompt if already fully configured
	# (command -v doesn't execute the binary, so Santa won't block it)
	if command -v claude >/dev/null 2>&1 && [[ -e "$HOME/.openclaw/openclaw.json" ]]; then
		INSTALL_AI=true
		return 0
	fi

	echo ""
	echo "AI assistant setup (Claude, MCP servers, OpenClaw):"
	echo "  1) Install (default)"
	echo "  2) Skip"
	read -p "Choose [1/2]: " -n 1 -r ai_choice
	echo ""

	if [[ "$ai_choice" == "2" ]]; then
		INSTALL_AI=false
	else
		INSTALL_AI=true
	fi
}

install_steamos_packages() {
	# SteamOS has an immutable filesystem — no sudo, no pacman (wiped on updates).
	# Install pre-built binaries to ~/.local/bin instead.
	echo "Installing packages for SteamOS..."
	mkdir -p "$HOME/.local/bin"

	# GitHub release binaries (tarballs/zips)
	install_github_binary "cli/cli" "gh" "gh_{version_no_v}_linux_amd64.tar.gz" 1
	install_github_binary "jesseduffield/lazygit" "lazygit" "lazygit_{version_no_v}_Linux_x86_64.tar.gz"
	install_github_binary "dandavison/delta" "delta" "delta-{version_no_v}-x86_64-unknown-linux-musl.tar.gz" 1
	install_github_binary "sharkdp/bat" "bat" "bat-{version}-x86_64-unknown-linux-musl.tar.gz" 1
	install_github_binary "eza-community/eza" "eza" "eza_x86_64-unknown-linux-musl.tar.gz"
	install_github_binary "BurntSushi/ripgrep" "rg" "ripgrep-{version}-x86_64-unknown-linux-musl.tar.gz" 1
	install_github_binary "sharkdp/fd" "fd" "fd-{version}-x86_64-unknown-linux-musl.tar.gz" 1
	install_github_binary "koalaman/shellcheck" "shellcheck" "shellcheck-{version}.linux.x86_64.tar.xz" 1
	install_github_binary "ajeetdsouza/zoxide" "zoxide" "zoxide-{version_no_v}-x86_64-unknown-linux-musl.tar.gz"
	install_github_binary "aristocratos/btop" "btop" "btop-x86_64-unknown-linux-musl.tbz" 2
	install_github_binary "charmbracelet/glow" "glow" "glow_{version_no_v}_Linux_x86_64.tar.gz"
	install_github_binary "boyter/scc" "scc" "scc_Linux_x86_64.tar.gz"
	install_github_binary "helix-editor/helix" "hx" "helix-{version}-x86_64-linux.tar.xz" 1
	install_github_binary "sxyazi/yazi" "yazi" "yazi-x86_64-unknown-linux-musl.zip"
	install_github_binary "zellij-org/zellij" "zellij" "zellij-x86_64-unknown-linux-musl.tar.gz"

	# Raw binaries (single file downloads, not archives)
	if ! command -v jq >/dev/null 2>&1; then
		echo "Installing jq..."
		curl -fsSL "https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64" -o "$HOME/.local/bin/jq"
		chmod +x "$HOME/.local/bin/jq"
	fi
	if ! command -v direnv >/dev/null 2>&1; then
		echo "Installing direnv..."
		curl -fsSL "https://github.com/direnv/direnv/releases/latest/download/direnv.linux-amd64" -o "$HOME/.local/bin/direnv"
		chmod +x "$HOME/.local/bin/direnv"
	fi

	# Install Tailscale (static binary + system service)
	if ! command -v tailscale >/dev/null 2>&1; then
		echo "Installing Tailscale..."
		local ts_version
		ts_version=$(curl -fsSL "https://pkgs.tailscale.com/stable/" | grep -oP 'tailscale_\K[0-9.]+(?=_amd64\.tgz)' | head -1)
		if [[ -n "$ts_version" ]]; then
			curl -fsSL "https://pkgs.tailscale.com/stable/tailscale_${ts_version}_amd64.tgz" -o /tmp/tailscale.tgz
			tar xf /tmp/tailscale.tgz -C /tmp
			cp "/tmp/tailscale_${ts_version}_amd64/tailscale" "$HOME/.local/bin/tailscale"
			cp "/tmp/tailscale_${ts_version}_amd64/tailscaled" "$HOME/.local/bin/tailscaled"
			chmod +x "$HOME/.local/bin/tailscale" "$HOME/.local/bin/tailscaled"
			rm -rf /tmp/tailscale.tgz "/tmp/tailscale_${ts_version}_amd64"
			echo "  Tailscale installed. Run: sudo tailscaled & && sudo tailscale up"
		fi
	fi

	# Install Go to ~/.local (not /usr/local)
	if ! command -v go >/dev/null 2>&1; then
		echo "Installing Go..."
		local go_version
		go_version=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
		if [[ -n "$go_version" ]]; then
			curl -fsSL "https://go.dev/dl/${go_version}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
			rm -rf "$HOME/.local/go"
			tar -C "$HOME/.local" -xzf /tmp/go.tar.gz
			rm /tmp/go.tar.gz
			# Symlink go binaries to ~/.local/bin
			ln -sf "$HOME/.local/go/bin/go" "$HOME/.local/bin/go"
			ln -sf "$HOME/.local/go/bin/gofmt" "$HOME/.local/bin/gofmt"
		else
			echo "Warning: Failed to fetch Go version, skipping Go install"
		fi
	fi

	# Node.js via nvm (no system access needed)
	if ! command -v node >/dev/null 2>&1; then
		echo "Installing Node.js via nvm..."
		export NVM_DIR="$HOME/.nvm"
		if [[ ! -d "$NVM_DIR" ]]; then
			curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
		fi
		# shellcheck disable=SC1091
		[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
		nvm install --lts
	fi

	# Install JetBrains Mono Nerd Font (user-local)
	if command -v fc-list >/dev/null 2>&1 && ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
		echo "Installing JetBrains Mono Nerd Font..."
		mkdir -p ~/.local/share/fonts
		curl -fLo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
		unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts/
		rm /tmp/JetBrainsMono.zip
		fc-cache -f
	fi
}

install_apt_packages() {
	echo "Installing packages via apt..."
	local packages=(
		bat btop cmake delta direnv eza fd ffmpeg fontconfig
		gh git jq python3-numpy ripgrep shellcheck testdisk
		tmux unzip vim watch xclip zoxide
	)
	local to_install=()
	for pkg in "${packages[@]}"; do
		local apt_pkg="$pkg"
		case "$pkg" in
			delta) apt_pkg="git-delta" ;;
			fd) apt_pkg="fd-find" ;;
		esac
		if ! dpkg -s "$apt_pkg" &>/dev/null; then
			to_install+=("$apt_pkg")
		fi
	done

	if [[ ${#to_install[@]} -gt 0 ]]; then
		echo "Installing: ${to_install[*]}"
		sudo apt-get update
		sudo apt-get install -y "${to_install[@]}"
	else
		echo "All apt packages already installed"
	fi

	# Install Tailscale via official apt repo
	if ! command -v tailscale >/dev/null 2>&1; then
		echo "Installing Tailscale..."
		curl -fsSL https://tailscale.com/install.sh | sh
	fi

	# Install Node.js 22 via NodeSource
	if ! command -v node >/dev/null 2>&1; then
		echo "Installing Node.js 22..."
		curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
		sudo apt-get install -y nodejs
	fi

	# snap packages
	if command -v snap >/dev/null 2>&1; then
		if ! command -v hx >/dev/null 2>&1; then
			echo "Installing Helix..."
			sudo snap install helix --classic
		fi
		if ! command -v yazi >/dev/null 2>&1; then
			echo "Installing Yazi..."
			sudo snap install yazi --classic
		fi
		if ! command -v zellij >/dev/null 2>&1; then
			echo "Installing Zellij..."
			sudo snap install zellij --classic
		fi
		if ! command -v scc >/dev/null 2>&1; then
			echo "Installing scc..."
			sudo snap install scc
		fi
		if ! command -v gradle >/dev/null 2>&1; then
			echo "Installing gradle..."
			sudo snap install gradle --classic
		fi
	fi

	# Install lazygit
	if ! command -v lazygit >/dev/null 2>&1; then
		echo "Installing lazygit..."
		LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
		curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
		sudo tar xf /tmp/lazygit.tar.gz -C /usr/local/bin lazygit
		rm /tmp/lazygit.tar.gz
	fi

	# Install Go
	if ! command -v go >/dev/null 2>&1; then
		echo "Installing Go..."
		local go_version
		go_version=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
		if [[ -n "$go_version" ]]; then
			curl -fsSL "https://go.dev/dl/${go_version}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
			sudo rm -rf /usr/local/go
			sudo tar -C /usr/local -xzf /tmp/go.tar.gz
			rm /tmp/go.tar.gz
		else
			echo "Warning: Failed to fetch Go version, skipping Go install"
		fi
	fi

	# Install glow (terminal markdown viewer)
	if ! command -v glow >/dev/null 2>&1; then
		echo "Installing glow..."
		sudo mkdir -p /etc/apt/keyrings
		curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/charm.gpg
		echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
		sudo apt-get update
		sudo apt-get install -y glow
	fi

	# Install bazelisk
	install_npm_package "bazelisk" "bazelisk" "@aspect/bazelisk"

	# Install whisper-cpp (speech-to-text)
	if ! command -v whisper-cli >/dev/null 2>&1; then
		echo "Installing whisper-cpp..."
		local whisper_tmp
		whisper_tmp="$(mktemp -d)"
		git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git "$whisper_tmp"
		cmake -B "$whisper_tmp/build" -S "$whisper_tmp" -DCMAKE_BUILD_TYPE=Release
		cmake --build "$whisper_tmp/build" --config Release -j"$(nproc)"
		if [[ -f "$whisper_tmp/build/bin/whisper-cli" ]]; then
			sudo cp "$whisper_tmp/build/bin/whisper-cli" /usr/local/bin/
		else
			echo "whisper-cpp build failed — skipping install"
		fi
		rm -rf "$whisper_tmp"
	fi

	# Install piper-tts (text-to-speech)
	if ! command -v piper >/dev/null 2>&1; then
		echo "Installing piper-tts..."
		pip3 install --user piper-tts 2>/dev/null || pip3 install --user --break-system-packages piper-tts
	fi

	# Create fd alias (Debian/Ubuntu installs as fdfind)
	if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
		sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
	fi

	# Install JetBrains Mono Nerd Font
	if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
		echo "Installing JetBrains Mono Nerd Font..."
		mkdir -p ~/.local/share/fonts
		curl -fLo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
		unzip -o /tmp/JetBrainsMono.zip -d ~/.local/share/fonts/
		rm /tmp/JetBrainsMono.zip
		fc-cache -fv
	fi

}

# Packages common to all Linux distros (user-local installs, no sudo)
install_linux_common_packages() {
	# Install Rust via rustup
	if ! command -v rustup >/dev/null 2>&1; then
		echo "Installing Rust via rustup..."
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
		# shellcheck disable=SC1091
		[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
	fi

	# Install uv (Python package manager)
	if ! command -v uv >/dev/null 2>&1; then
		echo "Installing uv..."
		curl -LsSf https://astral.sh/uv/install.sh | sh
	fi

	# Install atuin (shell history)
	if ! command -v atuin >/dev/null 2>&1; then
		echo "Installing atuin..."
		curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
	fi

	# Install tldr
	install_npm_package "tldr" "tldr"

	# Install sccache (requires a C compiler for cargo build)
	if ! command -v sccache >/dev/null 2>&1; then
		if command -v cargo >/dev/null 2>&1 && command -v cc >/dev/null 2>&1; then
			echo "Installing sccache..."
			cargo install sccache --locked
		else
			echo "Skipping sccache (requires cargo and cc)"
		fi
	fi

	# Install fzf from git (distro versions are often too old)
	if [[ ! -d "$HOME/.fzf" ]]; then
		echo "Installing fzf from git..."
		git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
		"$HOME/.fzf/install" --all --no-bash --no-fish
	elif [[ -d "$HOME/.fzf/.git" ]]; then
		echo "Updating fzf..."
		git -C "$HOME/.fzf" pull --ff-only
		"$HOME/.fzf/install" --all --no-bash --no-fish
	fi

	# Configure npm to use user-owned global directory (avoids permission issues)
	# Skip if using nvm (nvm manages its own prefix)
	if command -v npm >/dev/null 2>&1 && [[ -z "${NVM_DIR:-}" ]]; then
		mkdir -p "$HOME/.npm-global"
		npm config set prefix "$HOME/.npm-global"
	fi
}

install_packages() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

	if [[ "$(uname)" == "Darwin" ]]; then
		# macOS - use Homebrew
		if ! command -v brew >/dev/null 2>&1; then
			echo "Installing Homebrew..."
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
			if [[ -f "/opt/homebrew/bin/brew" ]]; then
				eval "$(/opt/homebrew/bin/brew shellenv)"
			elif [[ -f "/usr/local/bin/brew" ]]; then
				eval "$(/usr/local/bin/brew shellenv)"
			fi
		else
			echo "Updating Homebrew..."
			brew update
		fi

		install_brew_packages
		run_brew_hooks

	else
		# Linux
		if is_steamos; then
			install_steamos_packages
		elif command -v apt-get >/dev/null 2>&1; then
			install_apt_packages
		else
			echo "Skipping package installation (unsupported Linux distro)"
		fi

		install_linux_common_packages
	fi
}

update_packages() {
	if [[ "$(uname)" == "Darwin" ]]; then
		if command -v softwareupdate >/dev/null 2>&1; then
			echo "Checking for macOS software updates..."
			softwareupdate --list
		fi
	else
		if is_steamos; then
			echo "SteamOS packages are static binaries. Re-run with -i to reinstall."
		elif command -v apt-get >/dev/null 2>&1; then
			echo "Updating apt packages..."
			sudo apt-get update
			sudo apt-get upgrade -y
			sudo apt-get autoremove -y

			if command -v snap >/dev/null 2>&1; then
				echo "Refreshing snap packages..."
				sudo snap refresh
			fi
		fi

		# Update fzf if installed from git
		if [[ -d "$HOME/.fzf/.git" ]]; then
			echo "Updating fzf..."
			git -C "$HOME/.fzf" pull --ff-only
			"$HOME/.fzf/install" --all --no-bash --no-fish
		fi
	fi

	# Update global npm packages
	if command -v npm >/dev/null 2>&1; then
		echo "Updating global npm packages..."
		npm update -g || true
	fi

	# Update cargo packages
	if command -v cargo >/dev/null 2>&1; then
		if cargo install --list 2>/dev/null | grep -q '^[a-z]'; then
			echo "Updating cargo packages..."
			cargo install-update -a 2>/dev/null || echo "  Tip: install cargo-update for automatic updates (cargo install cargo-update)"
		fi
	fi

	# Update pip packages (no safe "update all" — list managed packages explicitly)
	if [[ "$INSTALL_AI" == true ]] && command -v pip3 >/dev/null 2>&1; then
		echo "Updating pip packages..."
		pip3 install --upgrade piper-tts 2>/dev/null || pip3 install --upgrade --break-system-packages piper-tts 2>/dev/null || true
	fi

	echo "Package updates complete."
}

init_submodules() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

	# Check if any submodule is missing
	if [[ -d "$dotfiles_dir/vendor/btop-catppuccin/themes" ]] && \
	   [[ -d "$dotfiles_dir/vendor/bat-catppuccin/themes" ]] && \
	   [[ -d "$dotfiles_dir/vendor/eza-catppuccin/themes" ]] && \
	   [[ -d "$dotfiles_dir/vendor/glamour-catppuccin/themes" ]] && \
	   [[ -d "$dotfiles_dir/vendor/iterm-catppuccin/colors" ]]; then
		return 0
	fi

	if ! command -v git >/dev/null 2>&1; then
		echo "Skipping submodules (git not installed)"
		return 0
	fi

	echo "Initializing submodules..."
	if ! git -C "$dotfiles_dir" submodule update --init; then
		echo "Warning: Failed to initialize submodules"
		echo "  Run manually: git submodule update --init"
	fi
}

install_btop_themes() {
	local btop_themes_dir="$HOME/.config/btop/themes"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
	local vendor_theme="$dotfiles_dir/vendor/btop-catppuccin/themes/catppuccin_mocha.theme"

	if [[ ! -f "$vendor_theme" ]]; then
		echo "Skipping btop themes (submodule not initialized)"
		return 0
	fi

	mkdir -p "$btop_themes_dir"

	local dest="$btop_themes_dir/catppuccin_mocha.theme"

	if [[ -L "$dest" && "$(readlink "$dest")" == "$vendor_theme" ]]; then
		return 0
	fi

	echo "Symlinking btop theme..."
	ln -sf "$vendor_theme" "$dest"
}


install_bat_themes() {
	local bat_themes_dir="$HOME/.config/bat/themes"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
	local vendor_theme="$dotfiles_dir/vendor/bat-catppuccin/themes/Catppuccin Mocha.tmTheme"

	if [[ ! -f "$vendor_theme" ]]; then
		echo "Skipping bat themes (submodule not initialized)"
		return 0
	fi

	mkdir -p "$bat_themes_dir"

	local dest="$bat_themes_dir/Catppuccin Mocha.tmTheme"

	if [[ -L "$dest" && "$(readlink "$dest")" == "$vendor_theme" ]]; then
		return 0
	fi

	echo "Symlinking bat theme..."
	ln -sf "$vendor_theme" "$dest"

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

install_brew_packages() {
	if ! command -v brew >/dev/null 2>&1; then
		echo "Skipping Homebrew packages (brew not installed)"
		echo "  Install from: https://brew.sh"
		return 0
	fi

	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
	local brewfile="$dotfiles_dir/Brewfile"

	if [[ ! -f "$brewfile" ]]; then
		return 0
	fi

	echo "Installing Homebrew packages..."
	# Use --adopt to take ownership of existing apps instead of erroring
	HOMEBREW_CASK_OPTS="--adopt" brew bundle --file="$brewfile"

	# Conditionally install AI assistant packages (Claude, OpenClaw tools)
	prompt_ai_install
	if [[ "$INSTALL_AI" == true ]]; then
		local ai_brewfile="$dotfiles_dir/Brewfile.ai"
		if [[ -f "$ai_brewfile" ]]; then
			echo "Installing AI assistant packages..."
			HOMEBREW_CASK_OPTS="--adopt" brew bundle --file="$ai_brewfile"
		fi
	fi
}

run_brew_hooks() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
	local hooks_dir="$dotfiles_dir/brew-hooks"

	if [[ ! -d "$hooks_dir" ]]; then
		return 0
	fi

	for hook in "$hooks_dir"/*.sh; do
		if [[ -f "$hook" && -x "$hook" ]]; then
			"$hook"
		fi
	done
}

install_eza_theme() {
	local eza_config_dir="$HOME/.config/eza"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
	local vendor_theme="$dotfiles_dir/vendor/eza-catppuccin/themes/mocha/catppuccin-mocha-mauve.yml"

	if [[ ! -f "$vendor_theme" ]]; then
		echo "Skipping eza theme (submodule not initialized)"
		return 0
	fi

	mkdir -p "$eza_config_dir"

	local dest="$eza_config_dir/theme.yml"

	if [[ -L "$dest" && "$(readlink "$dest")" == "$vendor_theme" ]]; then
		return 0
	fi

	echo "Symlinking eza theme..."
	ln -sf "$vendor_theme" "$dest"
}

install_glamour_theme() {
	local glamour_dir="$HOME/.config/glamour"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
	local vendor_theme="$dotfiles_dir/vendor/glamour-catppuccin/themes/catppuccin-mocha.json"

	if [[ ! -f "$vendor_theme" ]]; then
		echo "Skipping glamour theme (submodule not initialized)"
		return 0
	fi

	mkdir -p "$glamour_dir"

	local dest="$glamour_dir/catppuccin-mocha.json"

	if [[ -L "$dest" && "$(readlink "$dest")" == "$vendor_theme" ]]; then
		return 0
	fi

	echo "Symlinking glamour theme..."
	ln -sf "$vendor_theme" "$dest"
}

install_yazi_flavor() {
	local ya_cmd=""
	if command -v ya >/dev/null 2>&1; then
		ya_cmd="ya"
	elif command -v yazi.ya >/dev/null 2>&1; then
		ya_cmd="yazi.ya"
	else
		return 0
	fi

	# Install catppuccin-mocha flavor if not present
	if ! $ya_cmd pkg list 2>/dev/null | grep -q "catppuccin-mocha"; then
		echo "Installing yazi catppuccin-mocha flavor..."
		$ya_cmd pkg add yazi-rs/flavors:catppuccin-mocha || true
	fi
}

install_zellij_plugins() {
	local plugins_dir="$HOME/.config/zellij/plugins"

	mkdir -p "$plugins_dir"

	# Install zellij-autolock if not present
	if [[ ! -f "$plugins_dir/zellij-autolock.wasm" ]]; then
		echo "Installing zellij-autolock plugin..."
		curl -fsSL "https://github.com/fresh2dev/zellij-autolock/releases/latest/download/zellij-autolock.wasm" \
			-o "$plugins_dir/zellij-autolock.wasm"
	fi

	# Install zellij-forgot if not present
	if [[ ! -f "$plugins_dir/zellij-forgot.wasm" ]]; then
		echo "Installing zellij-forgot plugin..."
		curl -fsSL "https://github.com/karimould/zellij-forgot/releases/latest/download/zellij_forgot.wasm" \
			-o "$plugins_dir/zellij-forgot.wasm"
	fi

	# Install zjstatus if not present
	if [[ ! -f "$plugins_dir/zjstatus.wasm" ]]; then
		echo "Installing zjstatus plugin..."
		curl -fsSL "https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm" \
			-o "$plugins_dir/zjstatus.wasm"
	fi
}

install_claude_mcp_servers() {
	if ! command -v claude >/dev/null 2>&1; then
		echo "Skipping MCP servers (claude not installed)"
		return 0
	fi

	# Test that claude can actually execute (may be blocked by security software)
	local mcp_list
	if ! mcp_list=$(claude mcp list 2>/dev/null); then
		echo "Skipping MCP servers (claude blocked or not working)"
		return 0
	fi

	# Install GitHub MCP server if not configured
	if ! echo "$mcp_list" | grep -q "github"; then
		echo "Installing GitHub MCP server..."
		claude mcp add github -s user -e 'GITHUB_PERSONAL_ACCESS_TOKEN=${GITHUB_TOKEN}' -- npx -y @modelcontextprotocol/server-github

		if [[ -z "${GITHUB_TOKEN:-}" ]]; then
			echo "  Warning: GITHUB_TOKEN not set. Add to ~/.extra:"
			echo "    export GITHUB_TOKEN=\"ghp_your_token_here\""
		fi
	fi

	# Install Obsidian MCP server if not configured
	if ! echo "$mcp_list" | grep -q "obsidian"; then
		if is_gateway_host; then
			install_npm_package "obsidian-mcp-server" "Obsidian MCP Server"
			claude mcp add --transport http -s user obsidian http://localhost:3010/mcp

			if [[ -z "${OBSIDIAN_API_KEY:-}" ]]; then
				echo "  Warning: OBSIDIAN_API_KEY not set. Add to ~/.extra:"
				echo "    export OBSIDIAN_API_KEY=\"your-api-key-here\""
			fi
		else
			claude mcp add --transport http -s user obsidian "https://${GATEWAY_HOST}/obsidian-mcp/mcp"
		fi
	fi
}

configure_npm_registry() {
	# Skip if ~/.npmrc already contains the registry auth configurations
	if [[ -f "$HOME/.npmrc" ]] && grep -q "ah-3p-staging-npm" "$HOME/.npmrc" 2>/dev/null; then
		return 0
	fi

	# Require gcloud and npm to be installed
	if ! command -v gcloud >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
		return 0
	fi

	# Check if user has an active gcloud account
	local active_account
	active_account=$(gcloud config get-value account 2>/dev/null) || return 0
	if [[ -z "$active_account" ]]; then
		return 0
	fi

	echo "Configuring NPM registry credentials via gcloud..."
	if gcloud artifacts print-settings npm --project=artifact-foundry-prod --repository=ah-3p-staging-npm --location=us >> "$HOME/.npmrc" 2>/dev/null; then
		echo "NPM registry credentials configured in ~/.npmrc"
	else
		echo "  Warning: Failed to configure NPM credentials automatically"
	fi
}

sync_dotfiles() {
	# Set default shell to zsh
	set_default_shell

	# Symlink dotfiles from home/ directory to ~
	symlink_dotfiles

	# AI assistant setup (Claude dirs, MCP servers, OpenClaw)
	prompt_ai_install
	if [[ "$INSTALL_AI" == true ]]; then
		# Symlink Claude Code directories
		symlink_claude_dir "hooks"
		symlink_claude_dir "commands"
		symlink_claude_dir "contrib"
		symlink_claude_dir "agents"
		symlink_claude_dir "skills"

		# Ensure OpenClaw workspace directory exists
		ensure_openclaw_workspace

		# Symlink OpenClaw config (skipped if local gateway config exists)
		symlink_openclaw_config

		# Install Claude Code MCP servers
		install_claude_mcp_servers

		# Configure settings.local.json with remote MCP URLs (skipped on gateway host)
		configure_claude_local_settings
	fi

	# Install tmux plugin manager if needed
	install_tmux_plugin_manager

	# Initialize submodules if needed
	init_submodules

	# Install btop themes from submodule
	install_btop_themes

	# Install bat themes from submodule
	install_bat_themes

	# Install eza theme from submodule
	install_eza_theme

	# Install glamour theme from submodule
	install_glamour_theme

	# Install yazi flavor
	install_yazi_flavor

	# Install zellij plugins
	install_zellij_plugins

	# Install LaunchAgents (macOS) or cron jobs (Linux)
	install_launch_agents
	cleanup_legacy_cron

	# Configure NPM registry auth if authenticated with gcloud
	configure_npm_registry

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
			echo "Sync dotfiles (symlink home/ to ~)"
			echo ""
			echo "Options:"
			echo "  -f, --force    Skip confirmation prompt"
			echo "  -p, --pull     Also pull latest and install/update packages"
			echo "  -h, --help     Show this help message"
			exit 0
			;;
	esac
done

# Pull, install, and update packages if requested
if [[ "$PULL" == true ]]; then
	pull_latest
	install_packages
	update_packages
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
