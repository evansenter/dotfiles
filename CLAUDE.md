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
make check          # Run all quality gates (lint, test, hooks, bootstrap)
make lint           # Run shellcheck on all .sh files
make test           # Syntax check bash/zsh scripts
make test-hooks     # Test hook graceful degradation
make test-bootstrap # Test naming consistency, URL migration, cron
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

`sync_dotfiles` in `bootstrap.sh` (see script for full details):
1. Symlinks `home/` files to `~`
2. Symlinks `.claude/{hooks,commands,contrib,agents,skills}/`
3. Installs Claude Code MCP servers
4. Installs Homebrew packages (macOS) and hooks
5. Installs TPM (manual `prefix + I` for plugins)
6. Installs bat/yazi/zellij themes from `vendor/`
7. Installs LaunchAgents and cron jobs

### Symlink Pattern

Files in `home/` are symlinked to `~` by `bootstrap.sh`. This allows version control of dotfiles while keeping them in their expected locations.

**Adding new configs:**
1. Create the file under `home/` mirroring the `~` path (e.g., `home/.openclaw/openclaw.json` → `~/.openclaw/openclaw.json`)
2. Run `./bootstrap.sh -f` to create the symlink
3. The existing file will be replaced with a symlink to the dotfiles version

**Handling sensitive data:**
- Never commit secrets (tokens, API keys, passwords)
- Use environment variable substitution if the tool supports it (e.g., `${OPENCLAW_GATEWAY_TOKEN}`)
- Store actual secrets in `~/.extra` (sourced by zsh, not tracked)

**Examples:**
| Tool | Tracked Config | Secrets Location |
|------|---------------|------------------|
| Claude Code | `home/.claude/settings.json` | `~/.claude/.credentials.json` (not tracked) |
| OpenClaw | `home/.openclaw/openclaw.json` | `~/.extra` via `${OPENCLAW_GATEWAY_TOKEN}` |

### Key Components

**Prompt** (`home/.zsh_prompt`) - Timer displayed if command takes >0s.

**Dark Mode Switching** (`home/.bin/toggle-btop-theme`) - Switches btop theme based on macOS appearance. Requires `dark-notify`.

**Claude Code** (`home/.claude/`) - Global config, agents, commands, contrib scripts, hooks, skills, settings.

**Hooks** (`home/.claude/hooks/`) - Shell scripts for Claude Code lifecycle events. See `hooks/README.md` for architecture and details. When adding or modifying hooks, update the README.

**Skills** (`home/.claude/skills/`) - Model-invoked domain expertise. Skills auto-apply when Claude detects matching context (e.g., editing hooks triggers hook-authoring patterns).

**Commands** (`home/.claude/commands/`) - User-invoked workflows. Explicit `/command` invocation (e.g., `/work`, `/pr-review`).

| Aspect | Commands | Skills |
|--------|----------|--------|
| Invocation | User types `/command` | Claude auto-applies |
| Trigger | Explicit | Context-based |
| Examples | `/work`, `/pr-review` | `hook-authoring` |

**OpenClaw** (`home/.openclaw/`) - Personal AI assistant. The tracked config is for **remote clients** connecting to the gateway on mac-mini. Bootstrap symlinks config and installs the CLI automatically. Skipped if local gateway config exists.

- **Client machines**: Bootstrap handles everything. Just add `OPENCLAW_GATEWAY_TOKEN` to `~/.extra`. (Claude auth lives on gateway, not clients.)
- **Gateway host** (mac-mini): Maintains its own `~/.openclaw/openclaw.json` with `mode: local`. Runs WhatsApp channel. Exposed via tailscale serve at `https://mac-mini.tailac7b3c.ts.net/`.

Remote browsers require pairing: `openclaw devices approve <id>` (check `openclaw devices list`).

**WhatsApp Channel Configuration** (on gateway host):
```bash
# DM policies: pairing (default), allowlist, open, disabled
openclaw config set channels.whatsapp.dmPolicy allowlist

# Add numbers to allowlist (E.164 format)
openclaw config set channels.whatsapp.allowFrom '["+12025551234", "+441234567890"]'

# Restart to apply
openclaw daemon restart
```
Note: WhatsApp shows "online" whenever openclaw is connected (WhatsApp Web limitation).

**Statusline** (`home/.claude/statusline-command.sh`) - Two-line custom statusline for Claude Code.
- Line 1: `[repo/session]:branch ✓/✗/↻ →#issues ●` (CI status hidden when dirty)
- Line 2: `model_id N% (last user message...)`
- GitHub API calls (repo URL, PR number, PR body, CI status) are cached in `$TMPDIR/claude-statusline-gh/` with per-call TTLs
- Session name cached in `$TMPDIR/claude-statusline/` (pre-populated by session-start hook)

**Infrastructure Services** - LaunchAgents on mac-mini, exposed via tailscale:
| Service | Port | Tailscale Path | LaunchAgent |
|---------|------|---------------|-------------|
| OpenClaw gateway | 18789 | `/` | managed by openclaw |
| agent-event-bus | 8080 | `/agent-event-bus` | `com.evansenter.agent-event-bus` |
| agent-session-analytics | 8081 | `/agent-session-analytics` | `com.evansenter.agent-session-analytics` |
| agent-memory-store | 8083 | `/agent-memory-store` | `com.evansenter.agent-memory-store` |

LaunchAgent plists live in `~/Library/LaunchAgents/`. Each service repo has `make install-server` to set up. Reload with `launchctl unload` + `launchctl load`.

**Important:** Never place projects in `~/Documents/` — macOS TCC blocks LaunchAgents from accessing it, causing silent `PermissionError` failures.

**iTerm2** (`preferences/`, `vendor/iterm-catppuccin/`) - Manual color preset import required.

### File Formats

New commands, agents, and skills: follow the format of existing files in the respective `home/.claude/` subdirectories.

## After Merging

Run `./bootstrap.sh -f` to apply changes locally.

## Documentation Standards

When editing CLAUDE.md, README.md, commands, agents, or hooks:
- **Clarity** - Would a new reader understand?
- **Consistency** - Matches surrounding style?
- **Length** - Appropriately concise?
- **Hooks** - Update `home/.claude/hooks/README.md` when adding/modifying hooks
