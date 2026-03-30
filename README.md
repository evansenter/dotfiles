# Evan's dotfiles

Minimal macOS/Linux dotfiles for a modern terminal setup with Catppuccin Mocha theming throughout.

## What's included

**Shell & Config:**
- **Zsh** - History, completion, custom prompt with command timer
- **Git** - Sensible defaults, delta diffs, common aliases
- **Vim/Helix** - Catppuccin theme, sensible defaults
- **Tmux** - Catppuccin theme, session persistence

**Modern CLI tools:**
- **bat** - `cat` with syntax highlighting
- **eza** - `ls` with icons and git status
- **fd** - Fast `find` alternative
- **ripgrep** - Fast `grep` alternative
- **fzf** - Fuzzy finder
- **zoxide** - Smart `cd` that learns your paths
- **lazygit** - Git TUI
- **yazi** - Terminal file manager
- **btop** - Resource monitor

## Tool cheatsheet

| Instead of | Use | Why |
|------------|-----|-----|
| `ls` | `ls` (eza) | Icons, colors, git status |
| `ls -la` | `la` | Long format with hidden files |
| `tree` | `lt` | Tree view with icons |
| `cat file` | `bat file` | Syntax highlighting |
| `cd path` | `z partial` | Jump to frequently used dirs |
| `find -name` | `fd pattern` | Simpler, faster |
| `grep -r` | `rg pattern` | Faster, respects .gitignore |
| `git status/add/commit` | `lazygit` | Visual TUI for git |
| File browsing | `yazi` | Navigate, preview, bulk ops |
| `htop` | `btop` | Prettier, more info |
| `vim` | `hx` | Modern editor, LSP built-in |

### Claude Code Commands

**Commands** (user-invokable via `/name`):
| Command | Description |
|---------|-------------|
| `/work` | Full development flow: issue → code → PR → merge → reflect |
| `/parallel-work` | Manage git worktrees for parallel PR development |
| `/im-lost` | Show current workflow position and context |
| `/pr-create` | Commit changes and create/update a PR |
| `/pr-review` | Review code via local analysis or remote reviewer comments |
| `/watch-ci` | Monitor CI in background with notification when complete |
| `/event-bus-status` | Overview of active sessions and recent events |
| `/broadcast` | Send message to other Claude Code sessions |
| `/session-dump` | Dump recent conversation to file |

**Agents** (invoked via Task tool for background/complex work):
| Agent | Description |
|-------|-------------|
| `status-report` | Repo status with recent work, open PRs/issues, and recommendations |
| `summarize-work` | Summarize current branch work for PR creation |
| `audit-codebase` | Code quality, anti-patterns, Evergreen violations |
| `audit-tests` | Test redundancy, staleness, coverage gaps |
| `audit-issues` | Issue triage, priority alignment, staleness |
| `audit-docs` | CLAUDE.md, README, and documentation quality |
| `audit-workflows` | Command contradictions and inconsistencies |
| `improve-workflow` | Data-driven workflow improvements from session analytics |
| `rfc-create` | Create RFC-style issues with structured analysis |
| `rfc-respond` | Respond to RFC-style issues |

**Usage examples:**
```bash
# Start tracked work on an issue (full workflow)
/work 42

# Check where you are in the workflow
/im-lost

# Self-review before creating PR
/pr-review local

# Create a PR for current work
/pr-create

# Monitor CI with notification
/watch-ci 123

# Data-driven workflow improvements (agent)
/improve-workflow
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

Also installs GitHub MCP server and enables plugins (feature-dev, pr-review-toolkit, commit-commands, code-simplifier, LSP integrations). Set `GITHUB_TOKEN` in `~/.extra`:
```bash
export GITHUB_TOKEN="ghp_your_token_here"
```

## Updating

Pull latest and sync:

```bash
cd dotfiles
./bootstrap.sh -f -p
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
│   │   ├── CLAUDE.md            # Global workflow preferences
│   │   ├── commands/            # Custom slash commands
│   │   ├── agents/              # Background task agents
│   │   ├── skills/              # Auto-applied domain expertise
│   │   ├── contrib/             # Shared scripts for hooks/commands
│   │   ├── hooks/               # Lifecycle event hooks
│   │   ├── statusline-command.sh  # Statusline provider script
│   │   └── settings.json        # Plugins and hook config
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
