#!/usr/bin/env bash

# ==============================================================================
# Uninstall Script - Remove Dotfiles
# ==============================================================================

echo "This will remove the following files from your home directory:"
echo "  ~/.zshrc"
echo "  ~/.zsh_prompt"
echo "  ~/.aliases"
echo "  ~/.exports"
echo "  ~/.tmux.conf"
echo ""
echo "Your original files (if any) will be permanently deleted."
echo ""

read -p "Are you sure you want to uninstall? (y/n) " -n 1;
echo "";

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing dotfiles..."

    rm -f ~/.zshrc
    rm -f ~/.zsh_prompt
    rm -f ~/.aliases
    rm -f ~/.exports
    rm -f ~/.tmux.conf

    echo "✓ Dotfiles removed successfully"
    echo ""
    echo "Note: This did not remove:"
    echo "  - ~/.zsh_history (your command history)"
    echo "  - ~/.tmux/ directory (tmux plugins)"
    echo "  - Any backups you may have created"
    echo ""
    echo "Restart your terminal or run 'exec zsh' to see changes."
else
    echo "Uninstall cancelled."
fi
