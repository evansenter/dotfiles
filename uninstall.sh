#!/usr/bin/env bash

# ==============================================================================
# Uninstall Script - Remove Dotfiles
# ==============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find all symlinks pointing to this repo
SYMLINKS=()
while IFS= read -r link; do
    SYMLINKS+=("$link")
done < <(find ~ -maxdepth 4 -type l -lname "$DOTFILES_DIR/home/*" 2>/dev/null)

if [[ ${#SYMLINKS[@]} -eq 0 ]]; then
    echo "No dotfile symlinks found pointing to this repo."
    exit 0
fi

echo "This will remove the following symlinks:"
for link in "${SYMLINKS[@]}"; do
    echo "  $link -> $(readlink "$link")"
done
echo ""
echo "The original files in the repo will not be affected."
echo ""

read -p "Are you sure you want to uninstall? (y/n) " -n 1
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing symlinks..."

    for link in "${SYMLINKS[@]}"; do
        rm "$link" && echo "Removed: $link"
    done

    # Unload and remove dark-notify LaunchAgent
    launchctl bootout "gui/$(id -u)/com.user.dark-notify" 2>/dev/null || true
    rm -f ~/Library/LaunchAgents/com.user.dark-notify.plist

    # Remove btop theme symlinks
    rm -f ~/.config/btop/themes/catppuccin_*.theme 2>/dev/null

    echo ""
    echo "Dotfile symlinks removed successfully."
    echo ""
    echo "Note: This did not remove:"
    echo "  - ~/.zsh_history (your command history)"
    echo "  - ~/.tmux/ directory (tmux plugins)"
    echo "  - Empty directories that contained symlinks"
else
    echo "Uninstall cancelled."
fi
