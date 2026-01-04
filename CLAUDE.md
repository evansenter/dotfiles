# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Minimal dotfiles for zsh, git, vim, and tmux. Primarily macOS with Linux graceful degradation. Dotfiles in `home/` are symlinked to `~` on install. External themes are git submodules in `vendor/`.

## Commands

```bash
./bootstrap.sh           # Install/sync dotfiles (prompts for confirmation)
./bootstrap.sh -f        # Force install (skip confirmation)
./bootstrap.sh --pull    # Pull latest then install
./uninstall.sh           # Remove symlinks
git submodule update --init --remote  # Update theme submodules
```

## Quality Gates

```bash
make check       # Run all quality gates (lint, test, hooks)
make lint        # Run shellcheck on all .sh files
make test        # Syntax check bash/zsh scripts
make test-hooks  # Test hook graceful degradation
```

CI runs: Lint, Test, Hooks, Bootstrap, claude-review.

## Testing Changes

1. **Shell configs** - `source ~/.zshrc` or new terminal tab
2. **Tmux** - `tmux source ~/.tmux.conf` or restart
3. **Git** - Test alias: `git <alias>`
4. **Bootstrap** - `./bootstrap.sh -f` to verify idempotent symlinks

## Architecture

### Zsh Loading Order

`.zshrc` sources in order:
1. `.exports` - Environment variables, PATH
2. `.zsh_prompt` - Prompt with command timer (`preexec`/`precmd` hooks)
3. `.aliases` - Command aliases
4. `~/.extra` - Personal customizations (not tracked)

### Bootstrap Process

`sync_dotfiles` in `bootstrap.sh`:
1. Symlinks `home/` files to `~`
2. Symlinks `.claude/{hooks,commands,contrib,agents}/`
3. Installs Claude Code MCP servers
4. Installs TPM (manual `prefix + I` for plugins)
5. Symlinks btop themes from `vendor/btop-catppuccin/`
6. Installs LaunchAgents (macOS)

### Key Components

**Prompt** (`home/.zsh_prompt`) - Timer displayed if command takes >0s.

**Dark Mode Switching** (`home/.bin/toggle-btop-theme`) - Switches btop theme based on macOS appearance. Requires `dark-notify`.

**Claude Code** (`home/.claude/`) - Global config, agents, commands, contrib scripts, hooks, settings.

**iTerm2** (`preferences/`, `vendor/iterm-catppuccin/`) - Manual color preset import required.

### File Formats

New commands and agents: follow the format of existing files in `home/.claude/commands/` and `home/.claude/agents/`.

## After Merging

Run `./bootstrap.sh -f` to apply changes locally.

## Documentation Standards

When editing CLAUDE.md, README.md, commands, or agents:
- **Clarity** - Would a new reader understand?
- **Consistency** - Matches surrounding style?
- **Length** - Appropriately concise?
