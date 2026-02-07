# Brewfile - Homebrew dependencies
# Install: brew bundle
# With existing apps: HOMEBREW_CASK_OPTS="--adopt" brew bundle

# Taps
tap "cormacrelf/tap"

# CLI Tools
brew "bat"                    # Cat with syntax highlighting
brew "btop"                   # System monitor
brew "eza"                    # Modern ls
brew "fd"                     # Fast find alternative
brew "fzf"                    # Fuzzy finder
brew "gh"                     # GitHub CLI
brew "git"                    # Version control
brew "git-delta"              # Better git diffs
brew "helix"                  # Modal text editor
brew "jq"                     # JSON processor
brew "lazygit"                # Git TUI
brew "ripgrep"                # Fast grep
brew "shellcheck"             # Shell script linting
brew "tmux"                   # Terminal multiplexer
brew "terminal-notifier" if OS.mac?  # macOS notifications
brew "vim"                    # Text editor
brew "yazi"                   # Terminal file manager
brew "zellij"                 # Terminal workspace
brew "zoxide"                 # Smart cd command
brew "atuin"                  # Shell history search/sync
brew "direnv"                 # Directory-specific env vars
brew "glow"                   # Terminal markdown viewer
brew "tldr"                   # Simplified man pages
brew "watch"                  # Run command periodically
brew "cormacrelf/tap/dark-notify" if OS.mac?  # Dark mode detection

# Languages & Runtimes
brew "go"
brew "node"
brew "rustup"                 # Requires: rustup default stable
brew "uv"                     # Python package manager

# Build Tools
brew "bazelisk"               # Bazel wrapper
brew "cmake"
brew "gradle"
brew "sccache"                # Compile cache

# Xcode-dependent (skipped if Xcode not installed)
if File.directory?("/Applications/Xcode.app")
  brew "swiftlint"
  brew "xcodegen"
end

# Utilities
brew "ffmpeg"
brew "scc"                    # Code line counter
brew "testdisk"               # Data recovery

# Casks - Dev Tools
cask "codex"
cask "iterm2"                 # Requires: post-install config
cask "lm-studio"

# Casks - Apps
cask "claude"
cask "google-chrome"
cask "iina"                   # Video player
cask "obsidian"               # Note-taking
cask "spotify"
cask "stats"                  # Menu bar system monitor
cask "steam"
cask "whatsapp"

# Casks - Fonts
cask "font-jetbrains-mono-nerd-font"

# Casks - Networking
cask "tailscale"              # Mesh VPN (event bus, moltbot)

# Casks - Cloud
cask "gcloud-cli"             # Requires: gcloud init
