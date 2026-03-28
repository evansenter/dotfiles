---
name: catppuccin-theming
description: |
  Catppuccin Mocha theming conventions. Auto-applies when configuring new tools,
  adding themes, editing color/theme settings in any config file, or setting up
  any tool that supports color customization. Use whenever colors, themes, or
  visual styling come up — even if the user doesn't mention Catppuccin by name.
allowed-tools:
  - Read
  - Edit
  - Write
  - Bash
  - Grep
  - Glob
---

# Catppuccin Mocha Theming

This skill auto-applies when configuring themes or colors for tools. The standard theme across all tools is **Catppuccin Mocha**.

## Flavor

Always use **Mocha** (the dark flavor). Never Latte, Frappe, or Macchiato unless explicitly for light mode switching.

## Color Palette Reference

```
Rosewater  #f5e0dc    Flamingo   #f2cdcd
Pink       #f5c2e7    Mauve      #cba6f7
Red        #f38ba8    Maroon     #eba0ac
Peach      #fab387    Yellow     #f9e2af
Green      #a6e3a1    Teal       #94e2d5
Sky        #89dceb    Sapphire   #74c7ec
Blue       #89b4fa    Lavender   #b4befe
Text       #cdd6f4    Subtext1   #bac2de
Subtext0   #a6adc8    Overlay2   #9399b2
Overlay1   #7f849c    Overlay0   #6c7086
Surface2   #585b70    Surface1   #45475a
Surface0   #313244    Base       #1e1e2e
Mantle     #181825    Crust      #11111b
```

## How Tools Are Themed

| Tool | Method | Location |
|------|--------|----------|
| bat | Config file | `home/.config/bat/config` → `--theme="Catppuccin Mocha"` |
| btop | Theme files | `vendor/btop-catppuccin/` → symlinked to `~/.config/btop/themes/` |
| eza | Theme dir | `vendor/eza-catppuccin/` → `EZA_CONFIG_DIR` env var |
| fzf | Env var | `home/.exports` → `FZF_DEFAULT_OPTS` with inline colors |
| glamour | Env var | `home/.exports` → `GLAMOUR_STYLE` pointing to theme JSON |
| helix | Config | `home/.config/helix/config.toml` → `theme = "catppuccin_mocha"` |
| iTerm2 | Manual import | `vendor/iterm-catppuccin/` color preset |
| lazygit | Inline colors | `home/.config/lazygit/config.yml` → custom theme block |
| tmux | Plugin | `catppuccin/tmux` plugin in `.tmux.conf` (legacy, kept for compatibility) |
| yazi | Built-in | Uses flavor system (built-in catppuccin support) |
| zellij | Built-in | `home/.config/zellij/config.kdl` → `theme "catppuccin-mocha"` |

## Adding a New Tool

When configuring a new CLI tool:

1. Check if Catppuccin has an official port: https://github.com/catppuccin
2. If a theme file is needed, add as a git submodule under `vendor/`:
   ```bash
   git submodule add https://github.com/catppuccin/<tool>.git vendor/<tool>-catppuccin
   ```
3. If it's an env var or inline config, add to `home/.exports` or the tool's config
4. Add the tool to the table above in this skill
5. If bootstrap needs to symlink/copy theme files, add to `bootstrap.sh`

## Dark/Light Mode Switching

`dark-notify` monitors macOS appearance changes. Currently only btop switches themes automatically (`home/.bin/toggle-btop-theme`). Other tools use Mocha (dark) permanently.

To add another tool to auto-switching:
1. Add a case to `toggle-btop-theme` (or create a new script)
2. The script receives "light" or "dark" as `$1`
3. Use Latte for light mode, Mocha for dark mode
