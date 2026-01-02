# Evan's dotfiles

Minimal macOS dotfiles for zsh, git, vim, and tmux with automatic dark/light mode theme switching.

## What's included

- **Zsh** - History management, completion caching, directory navigation, custom prompt with command timer
- **Git** - Sensible defaults, common aliases (`st`, `co`, `br`, `lg`, etc.)
- **Vim** - 2-space indentation, Catppuccin theme, sensible search settings
- **Tmux** - Catppuccin theme, vim-style navigation, session persistence
- **btop** - Automatic dark/light theme switching via macOS appearance
- **iTerm2** - Catppuccin color schemes (manual import required)
- **Claude Code** - Global workflow preferences, custom commands, and hooks

### Claude Code Commands

| Command | Description |
|---------|-------------|
| `/im-lost` | Show current workflow position and context |
| `/status-report` | Repo status with recent work, open PRs/issues, and recommendations |
| `/pr-create` | Commit changes and create/update a PR |
| `/pr-review` | Review code via local analysis or remote reviewer comments |
| `/watch-ci` | Monitor CI in background with notification when complete |
| `/pr-followups` | Find unaddressed comments from merged PRs |
| `/audit-codebase` | Check for AI anti-patterns and Evergreen violations |
| `/audit-tests` | Find redundant or stale tests |
| `/audit-issues` | Categorize open issues as current or needing updates |
| `/cross-repo` | Gather context from a related repository |
| `/improve-workflow` | Suggest workflow improvements, categorized as local or global |
| `/rfc` | Create or respond to RFC-style issues |

**Usage examples:**
```bash
# Check repo status and get recommendations
/status-report

# Self-review before creating PR
/pr-review local

# Fetch and process reviewer comments
/pr-review remote

# Create a PR for current work
/pr-create

# Monitor CI with notification
/watch-ci 123
```

## Installation

Clone with submodules and run bootstrap:

```bash
git clone --recursive https://github.com/evansenter/dotfiles.git
cd dotfiles
./bootstrap.sh
```

Restart your terminal or run `source ~/.zshrc` to apply changes.

### Optional dependencies

**Dark mode theme switching** (btop):
```bash
brew install cormacrelf/tap/dark-notify
./bootstrap.sh  # Re-run to install LaunchAgent
```

**Claude Code** (commands, hooks, settings symlinked to ~/.claude/):
```bash
./bootstrap.sh  # Symlinks commands/, hooks/, settings.json, CLAUDE.md
```

Also installs GitHub MCP server and enables plugins (feature-dev, pr-review-toolkit, code-review, commit-commands, LSP integrations). Set `GITHUB_TOKEN` in `~/.extra`:
```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

## Updating

Pull latest and sync:

```bash
cd dotfiles
./bootstrap.sh -f --pull
git submodule update --init --remote
```

## Uninstalling

```bash
cd dotfiles
./uninstall.sh
```

## Structure

```
dotfiles/
├── home/           # Synced to ~/ on install
│   ├── .aliases
│   ├── .bin/
│   ├── .claude/
│   │   ├── CLAUDE.md      # Global workflow preferences
│   │   ├── commands/      # Custom slash commands
│   │   ├── hooks/         # Notification hook
│   │   └── settings.json  # Plugins and hook config
│   ├── .exports
│   ├── .gitconfig
│   ├── .tmux.conf
│   ├── .vim/
│   ├── .vimrc
│   ├── .zsh_prompt
│   └── .zshrc
├── vendor/         # Git submodules (themes)
├── preferences/    # App config backups
├── LaunchAgents/   # macOS LaunchAgent templates
└── bootstrap.sh
```

## Customization

Create `~/.extra` (not tracked) for personal settings:

```bash
# ~/.extra
export CUSTOM_VAR="value"
alias myalias="some command"
```

## Credits

Based on [Mathias Bynens' dotfiles](https://github.com/mathiasbynens/dotfiles), heavily simplified.
