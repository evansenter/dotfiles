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
	# Exclude .claude/{hooks,commands,contrib,agents,skills}/ since we symlink those directories separately
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
	done < <(find "$dotfiles_dir/home" -type f -not -name ".DS_Store" -not -path "*/.claude/hooks/*" -not -path "*/.claude/commands/*" -not -path "*/.claude/contrib/*" -not -path "*/.claude/agents/*" -not -path "*/.claude/skills/*" -not -path "*/.moltbot/*" -not -path "*/.config/btop/btop.conf" -print0)
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

symlink_moltbot_config() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local src_file="$dotfiles_dir/home/.moltbot/moltbot.json"
	local dest_file="$HOME/.moltbot/moltbot.json"

	if [[ ! -f "$src_file" ]]; then
		return 0
	fi

	mkdir -p "$HOME/.moltbot"

	# Skip if local config exists (gateway host keeps its own config)
	if [[ -f "$dest_file" && ! -L "$dest_file" ]]; then
		echo "Skipped: ~/.moltbot/moltbot.json (local gateway config exists)"
		return 0
	fi

	# Skip if already correctly symlinked
	if [[ -L "$dest_file" && "$(readlink "$dest_file")" == "$src_file" ]]; then
		install_moltbot_cli
		return 0
	fi

	# Ask if this is the gateway host or a remote client
	# Default to remote client when non-interactive (CI, scripts, -f flag)
	if [[ ! -e "$dest_file" ]]; then
		if [[ -t 0 ]]; then
			echo ""
			echo "Moltbot setup:"
			echo "  1) Remote client - connect to existing gateway (default)"
			echo "  2) Gateway host - run the gateway on this machine"
			read -p "Choose [1/2]: " -n 1 -r moltbot_choice
			echo ""

			if [[ "$moltbot_choice" == "2" ]]; then
				echo "Skipped: ~/.moltbot/moltbot.json (run 'moltbot onboard' to set up gateway)"
				return 0
			fi
		fi
	fi

	# Remove existing symlink if present
	if [[ -L "$dest_file" ]]; then
		rm -f "$dest_file"
	fi

	ln -s "$src_file" "$dest_file"
	echo "Linked: ~/.moltbot/moltbot.json (remote client config)"

	install_moltbot_cli
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

install_moltbot_cli() {
	install_npm_package "moltbot" "moltbot CLI" "moltbot@beta"
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

install_launch_agent() {
	local plist="$1"
	local label="${plist%.plist}"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
		launchctl bootstrap "gui/$(id -u)" "$dest_plist"
	else
		rm -f "$tmp_plist"
	fi
}

install_launch_agents() {
	# LaunchAgents are macOS-only
	if [[ "$(uname)" != "Darwin" ]]; then
		return 0
	fi

	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
			launchctl bootstrap "gui/$(id -u)" "$dest_plist"

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
}

install_cron_jobs() {
	# Cron jobs are Linux-only (macOS uses LaunchAgents)
	if [[ "$(uname)" == "Darwin" ]]; then
		return 0
	fi

	# Install cargo-sweep cron job (only if cargo is installed)
	if command -v cargo >/dev/null 2>&1; then
		local cron_entry="0 3 * * 0 $HOME/.bin/cargo-sweep-all"

		# Check if already installed
		if ! crontab -l 2>/dev/null | grep -qF "cargo-sweep-all"; then
			echo "Installing cargo-sweep cron job (weekly Sunday 3am)..."
			(crontab -l 2>/dev/null || true; echo "$cron_entry") | crontab -
		fi
	fi
}

pull_latest() {
	echo "Pulling latest changes from origin/main..."
	git pull origin main
}

install_packages() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

	if [[ "$(uname)" == "Darwin" ]]; then
		# macOS - use Homebrew
		if ! command -v brew >/dev/null 2>&1; then
			echo "Installing Homebrew..."
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		fi

		if [[ -f "$dotfiles_dir/Brewfile" ]]; then
			echo "Installing packages from Brewfile..."
			brew bundle --file="$dotfiles_dir/Brewfile"
		fi

	else
		# Linux - use apt (Debian/Ubuntu)
		if command -v apt-get >/dev/null 2>&1; then
			echo "Installing packages via apt..."
			local packages=(
				bat
				btop
				cmake
				delta
				direnv
				eza
				fd
				ffmpeg
				fontconfig
				gh
				git
				jq
				python3-numpy
				ripgrep
				shellcheck
				testdisk
				tmux
				unzip
				vim
				watch
				xclip
				zoxide
			)
			# Filter to only packages not already installed
			local to_install=()
			for pkg in "${packages[@]}"; do
				# Handle package name differences
				local apt_pkg="$pkg"
				case "$pkg" in
					delta) apt_pkg="git-delta" ;;
					fd) apt_pkg="fd-find" ;;
				esac
				# dpkg -s returns 0 only if package is actually installed
				if ! dpkg -s "$apt_pkg" &>/dev/null; then
					to_install+=("$apt_pkg")
				fi
			done

			if [[ ${#to_install[@]} -gt 0 ]]; then
				echo "Installing: ${to_install[*]}"
				sudo apt-get update
				sudo apt-get install -y "${to_install[@]}"
			else
				echo "All packages already installed"
			fi
		else
			echo "Skipping package installation (apt not found)"
		fi

		# Install Node.js 22 via NodeSource
		if ! command -v node >/dev/null 2>&1; then
			echo "Installing Node.js 22..."
			curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
			sudo apt-get install -y nodejs
		fi

		# Install Helix editor via snap
		if command -v snap >/dev/null 2>&1 && ! command -v hx >/dev/null 2>&1; then
			echo "Installing Helix..."
			sudo snap install helix --classic
		fi

		# Install Yazi file manager via snap
		if command -v snap >/dev/null 2>&1 && ! command -v yazi >/dev/null 2>&1; then
			echo "Installing Yazi..."
			sudo snap install yazi --classic
		fi

		# Install Zellij via snap
		if command -v snap >/dev/null 2>&1 && ! command -v zellij >/dev/null 2>&1; then
			echo "Installing Zellij..."
			sudo snap install zellij --classic
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

		# Install Rust via rustup
		if ! command -v rustup >/dev/null 2>&1; then
			echo "Installing Rust via rustup..."
			curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
			# Source cargo env so cargo is available for sccache install below
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

		# Install glow (terminal markdown viewer)
		if ! command -v glow >/dev/null 2>&1; then
			echo "Installing glow..."
			sudo mkdir -p /etc/apt/keyrings
			curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/charm.gpg
			echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
			sudo apt-get update
			sudo apt-get install -y glow
		fi

		# Install tldr
		install_npm_package "tldr" "tldr"

		# Install scc (code line counter)
		if ! command -v scc >/dev/null 2>&1 && command -v snap >/dev/null 2>&1; then
			echo "Installing scc..."
			sudo snap install scc
		fi

		# Install bazelisk
		install_npm_package "bazelisk" "bazelisk" "@aspect/bazelisk"

		# Install gradle
		if ! command -v gradle >/dev/null 2>&1 && command -v snap >/dev/null 2>&1; then
			echo "Installing gradle..."
			sudo snap install gradle --classic
		fi

		# Install sccache
		if ! command -v sccache >/dev/null 2>&1; then
			if command -v cargo >/dev/null 2>&1; then
				echo "Installing sccache..."
				cargo install sccache --locked
			else
				echo "Skipping sccache (cargo not available)"
			fi
		fi

		# Install fzf from git (apt version is too old for modern color options)
		if [[ ! -d "$HOME/.fzf" ]]; then
			echo "Installing fzf from git..."
			git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
			"$HOME/.fzf/install" --all --no-bash --no-fish
		elif [[ -d "$HOME/.fzf/.git" ]]; then
			# Update existing fzf installation
			echo "Updating fzf..."
			git -C "$HOME/.fzf" pull --ff-only
			"$HOME/.fzf/install" --all --no-bash --no-fish
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

		# Configure npm to use user-owned global directory (avoids permission issues)
		if command -v npm >/dev/null 2>&1; then
			mkdir -p "$HOME/.npm-global"
			npm config set prefix "$HOME/.npm-global"
		fi
	fi
}

init_submodules() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

copy_btop_config() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local src_config="$dotfiles_dir/home/.config/btop/btop.conf"
	local dest_config="$HOME/.config/btop/btop.conf"

	if [[ ! -f "$src_config" ]]; then
		return 0
	fi

	mkdir -p "$(dirname "$dest_config")"

	# Copy only if missing or if it's a symlink (migrate from old setup)
	if [[ ! -e "$dest_config" || -L "$dest_config" ]]; then
		rm -f "$dest_config"
		cp "$src_config" "$dest_config"
		echo "Copied: ~/.config/btop/btop.conf (btop may modify this freely)"
	fi
}

install_bat_themes() {
	local bat_themes_dir="$HOME/.config/bat/themes"
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local brewfile="$dotfiles_dir/Brewfile"

	if [[ ! -f "$brewfile" ]]; then
		return 0
	fi

	echo "Installing Homebrew packages..."
	# Use --adopt to take ownership of existing apps instead of erroring
	HOMEBREW_CASK_OPTS="--adopt" brew bundle --file="$brewfile"
}

run_brew_hooks() {
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
	local dotfiles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
		$ya_cmd pkg add yazi-rs/flavors:catppuccin-mocha
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
	# Install Homebrew packages and run post-install hooks
	install_brew_packages
	run_brew_hooks

	# Symlink dotfiles from home/ directory to ~
	symlink_dotfiles

	# Symlink Claude Code directories
	symlink_claude_dir "hooks"
	symlink_claude_dir "commands"
	symlink_claude_dir "contrib"
	symlink_claude_dir "agents"
	symlink_claude_dir "skills"

	# Ask about AI assistant setup (Claude MCP servers + Moltbot)
	# Skip prompt if already configured or in non-interactive mode
	local install_assistants=true
	if [[ -t 0 ]]; then
		# Check if either is already set up
		local claude_configured=false
		local moltbot_configured=false
		if command -v claude >/dev/null 2>&1 && claude mcp list 2>/dev/null | grep -q "github"; then
			claude_configured=true
		fi
		if [[ -e "$HOME/.moltbot/moltbot.json" ]]; then
			moltbot_configured=true
		fi

		# Ask if not fully configured
		if [[ "$claude_configured" != true || "$moltbot_configured" != true ]]; then
			echo ""
			echo "AI assistant setup (Claude MCP servers + Moltbot):"
			echo "  1) Install (default)"
			echo "  2) Skip"
			read -p "Choose [1/2]: " -n 1 -r assistant_choice
			echo ""

			if [[ "$assistant_choice" == "2" ]]; then
				install_assistants=false
			fi
		fi
	fi

	if [[ "$install_assistants" == true ]]; then
		# Symlink Moltbot config (skipped if local gateway config exists)
		symlink_moltbot_config

		# Install Claude Code MCP servers
		install_claude_mcp_servers
	fi

	# Install tmux plugin manager if needed
	install_tmux_plugin_manager

	# Initialize submodules if needed
	init_submodules

	# Install btop themes from submodule
	install_btop_themes

	# Copy btop config (not symlinked - btop auto-saves settings)
	copy_btop_config

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
	install_cron_jobs

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
PACKAGES=false
for arg in "$@"; do
	case "$arg" in
		--force|-f) FORCE=true ;;
		--pull|-p) PULL=true ;;
		--packages|-i) PACKAGES=true ;;
		--help|-h)
			echo "Usage: ./bootstrap.sh [OPTIONS]"
			echo ""
			echo "Install dotfiles from home/ to ~"
			echo ""
			echo "Options:"
			echo "  -f, --force     Skip confirmation prompt"
			echo "  -p, --pull      Pull latest changes before installing"
			echo "  -i, --packages  Install packages (brew on macOS, apt on Linux)"
			echo "  -h, --help      Show this help message"
			exit 0
			;;
	esac
done

# Install packages if requested
if [[ "$PACKAGES" == true ]]; then
	install_packages
fi

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
