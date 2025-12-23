# Evan's dotfiles

Minimal macOS dotfiles for zsh, git, vim, and tmux with automatic dark/light mode theme switching.

## What's included

- **Zsh** - History management, completion caching, directory navigation, custom prompt with command timer
- **Git** - Sensible defaults, common aliases (`st`, `co`, `br`, `lg`, etc.)
- **Vim** - 2-space indentation, Catppuccin theme, sensible search settings
- **Tmux** - Catppuccin theme, vim-style navigation, session persistence
- **btop** - Automatic dark/light theme switching via macOS appearance
- **iTerm2** - Catppuccin color schemes (manual import required)

## Installation

Clone with submodules and run bootstrap:

```bash
git clone --recursive https://github.com/evansenter/dotfiles.git
cd dotfiles
./bootstrap.sh
```

Restart your terminal or run `source ~/.zshrc` to apply changes.

### Optional: Dark mode theme switching

For automatic btop theme switching based on macOS appearance:

```bash
brew install cormacrelf/tap/dark-notify
./bootstrap.sh  # Re-run to install LaunchAgent
```

## Updating

Pull latest and sync:

```bash
cd dotfiles
git pull
git submodule update --init --remote
./bootstrap.sh -f
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
