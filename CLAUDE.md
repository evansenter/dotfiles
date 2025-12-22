# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a minimal macOS dotfiles repository for zsh, git, vim, and tmux. The structure is flat with all configuration files in the root directory.

## Installation and Updates

**Install/sync dotfiles:**
```bash
./bootstrap.sh
```

**Force update (skip confirmation):**
```bash
./bootstrap.sh -f
```

**Uninstall:**
```bash
./uninstall.sh
```

## Architecture

### Configuration Loading Order

The `.zshrc` file sources other configuration files in this order:

1. `.exports` - Environment variables and PATH configuration
2. `.zsh_prompt` - Prompt configuration with command timer hooks
3. `.aliases` - Command aliases
4. `~/.extra` - Personal customizations (not tracked in repo)

### Key Components

**Prompt System** (.zsh_prompt:23-40)
- Uses zsh hooks (`preexec` and `precmd`) to track command execution time
- `preexec` captures start time before command runs
- `precmd` calculates elapsed time after command completes
- Timer only displayed if command takes >0 seconds

**Bootstrap Process** (bootstrap.sh:34-59)
- Uses `rsync` to sync dotfiles to home directory
- Excludes git metadata, scripts, and documentation from sync
- Installs tmux plugin manager (TPM) if not present
- TPM must be manually activated in tmux with `prefix + I` after first install

**Tmux Configuration** (.tmux.conf)
- Uses Catppuccin theme (mocha flavor) for status bar styling
- Custom key bindings: `|` for horizontal split, `-` for vertical split
- Vim-style pane navigation with Ctrl-hjkl
- Session resurrection with `prefix + S` (save) and `prefix + Y` (restore)
- Auto-saves sessions every 15 minutes via tmux-continuum

**Git Configuration** (.gitconfig)
- Common aliases: `st`, `co`, `br`, `ci`, `lg`, `amend`, `unstage`, `discard`
- Auto setup remote on push, prune on fetch
- Default branch set to `main`
- Uses GitHub CLI (`gh`) for credential management

**Vim Configuration** (.vimrc)
- 4-space indentation with spaces (expandtab)
- Incremental, case-smart search with highlighting
- No swap/backup files
- Line numbers and always-visible status line

## Personal Customizations

Users can create `~/.extra` (not tracked) to add personal settings that override defaults. This file is sourced last in .zshrc:71-73.
