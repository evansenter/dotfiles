# Evan's dotfiles

Minimal zsh configuration for macOS.

## What's included

- **Zsh configuration** - History management, completion caching, directory navigation
- **Custom prompt** - Shows directory, current time, and elapsed time for commands
- **Basic aliases** - Navigation shortcuts and colored ls/grep
- **PATH setup** - Adds `~/.local/bin` to PATH
- **Tmux config** - Basic tmux setup with plugin manager

## Installation

Clone the repository and run the bootstrap script:

```bash
git clone https://github.com/evansenter/dotfiles.git
cd dotfiles
./bootstrap.sh
```

The script will sync dotfiles to your home directory. Restart your terminal or run `source ~/.zshrc` to apply changes.

## Updating

To pull the latest changes and sync:

```bash
cd dotfiles
./bootstrap.sh -f
```

## Uninstalling

To remove all dotfiles from your home directory:

```bash
cd dotfiles
./uninstall.sh
```

## Customization

Create a `~/.extra` file (not tracked by this repo) to add personal customizations without forking:

```bash
# ~/.extra example
export CUSTOM_VAR="value"
alias myalias="some command"
```

## Features

**Smart history search**: Type a command prefix (like `git`) and press ↑/↓ arrows to search matching commands in history.

**Command timer**: The prompt shows how long the previous command took to run.

**Clean prompt format**:
```
~/path/to/directory 14:32:45 3s →
```

## Credits

Based on [Mathias Bynens' dotfiles](https://github.com/mathiasbynens/dotfiles), heavily simplified.
