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

## Testing Changes

No formal test suite exists. To validate changes:

1. **Shell configs** - Open a new terminal tab or `source ~/.zshrc`
2. **Tmux** - Run `tmux source ~/.tmux.conf` or restart tmux
3. **Git** - Test alias with `git <alias>`, e.g., `git st`
4. **Bootstrap** - Run `./bootstrap.sh -f` to verify idempotent symlink creation

## Architecture

### Zsh Loading Order

`.zshrc` sources files in this order:
1. `.exports` - Environment variables, PATH
2. `.zsh_prompt` - Prompt with command timer (uses `preexec`/`precmd` hooks)
3. `.aliases` - Command aliases
4. `~/.extra` - Personal customizations (not tracked)

### Bootstrap Process

The `sync_dotfiles` function in `bootstrap.sh`:
1. Symlinks all files in `home/` to `~` (idempotent - skips existing correct symlinks)
2. Symlinks `.claude/hooks/` and `.claude/commands/` directories
3. Installs Claude Code MCP servers (GitHub)
4. Installs tmux plugin manager (TPM) - requires manual `prefix + I` to install plugins
5. Symlinks btop themes from `vendor/btop-catppuccin/`
6. Installs LaunchAgents (macOS only)

### Key Components

**Prompt System** - `home/.zsh_prompt`
- `preexec` captures start time, `precmd` calculates elapsed time
- Timer only displayed if command takes >0 seconds

**Dark Mode Theme Switching** - `home/.bin/toggle-btop-theme`
- Switches btop theme based on macOS appearance (mocha/latte)
- Requires `dark-notify` (`brew install cormacrelf/tap/dark-notify`)
- LaunchAgent runs daemon, sends SIGUSR2 to btop instances

**Claude Code Configuration** - `home/.claude/`
- `CLAUDE.md` - Global workflow preferences (symlinked to `~/.claude/CLAUDE.md`)
- `commands/` - Custom slash commands (`/status-report`, `/pr-review`, etc.)
- `settings.json` - Allowed permissions, enabled plugins

### Command File Format

New commands in `home/.claude/commands/` should follow this structure:

```markdown
---
argument-hint: [arg1] [optional-arg]
description: Brief description for autocomplete hints
---

# Command Name

One-line description of what the command does.

## Usage

\`\`\`
/command-name <required-arg> [optional-arg]
\`\`\`

- Explain each argument
- Note defaults for optional args

## Instructions

### 1. First Step

\`\`\`bash
# Commands to run
\`\`\`

### 2. Next Step

Detailed instructions...

### N. Output

Describe expected output format.
```

**Guidelines:**
- Use `$1`, `$2` for positional args parsed in instructions
- Use `$ARGUMENTS` only for freeform context (not when parsing positional args)
- Include bash snippets for commands Claude should run
- End with output format specification

**iTerm2 Configuration** - `preferences/`, `vendor/iterm-catppuccin/`
- Manual import required: Preferences → Profiles → Colors → Color Presets → Import
- Enable "Use different colors for light mode and dark mode"
- Profile backup: `preferences/iTerm Profile.json`

## After Merging Changes

Run `./bootstrap.sh -f` to apply changes to the local system.
