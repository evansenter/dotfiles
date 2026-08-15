# ==============================================================================
# Environment Variables
# ==============================================================================

if [ -f ~/.exports ]; then
    source ~/.exports
fi

# ==============================================================================
# Zsh Configuration
# ==============================================================================

# Completion system
autoload -Uz compinit
compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'  # case-insensitive
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# History
HISTFILE=~/.zsh_history
HISTSIZE=32768
SAVEHIST=32768
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS

# Directory navigation
setopt AUTO_CD           # cd by typing directory name
setopt AUTO_PUSHD        # push directories to stack
setopt PUSHD_IGNORE_DUPS # don't push duplicates
setopt PUSHD_SILENT      # don't print directory stack

# Miscellaneous
setopt INTERACTIVE_COMMENTS  # allow comments in interactive shells
setopt NO_BEEP              # disable beep

# Disable flow control (Ctrl-S/Ctrl-Q) to free up Ctrl-Q
stty -ixon 2>/dev/null

# Make / - . act as word delimiters (for Ctrl+W, Alt+B, Alt+F, etc.)
WORDCHARS=${WORDCHARS/\//}
WORDCHARS=${WORDCHARS/\-/}
WORDCHARS=${WORDCHARS/\./}

# ==============================================================================
# Key Bindings
# ==============================================================================

# Use emacs keybindings (Ctrl+A, Ctrl+E, Ctrl+W, etc.)
bindkey -e

# History search with arrow keys (type prefix, then up/down to search)
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

# ==============================================================================
# Prompt
# ==============================================================================

if [ -f ~/.zsh_prompt ]; then
    source ~/.zsh_prompt
fi

# ==============================================================================
# Aliases
# ==============================================================================

if [ -f ~/.aliases ]; then
    source ~/.aliases
fi

# ==============================================================================
# fzf
# ==============================================================================

# Source fzf keybindings and completion (Ctrl+R, Ctrl+T, Alt+C)
# Priority: git install > Homebrew > apt (git install includes both keybindings and completion)
if [ -f ~/.fzf.zsh ]; then
    source ~/.fzf.zsh
elif command -v fzf &>/dev/null; then
    # Homebrew
    if [ -f "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/key-bindings.zsh" ]; then
        source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/key-bindings.zsh"
    fi
    if [ -f "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/completion.zsh" ]; then
        source "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/completion.zsh"
    fi
    # Debian/Ubuntu apt
    if [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
        source /usr/share/doc/fzf/examples/key-bindings.zsh
    fi
    if [ -f /usr/share/doc/fzf/examples/completion.zsh ]; then
        source /usr/share/doc/fzf/examples/completion.zsh
    fi
fi

# ==============================================================================
# zoxide (smart cd)
# ==============================================================================

if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# ==============================================================================
# atuin (shell history)
# ==============================================================================

if command -v atuin &>/dev/null; then
    eval "$(atuin init zsh)"
fi

# ==============================================================================
# direnv (directory-specific env vars)
# ==============================================================================

if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# ==============================================================================
# Personal Customizations
# ==============================================================================

# Load personal customizations (not tracked by repo)
# This is sourced last so it can override any settings above
if [ -f ~/.extra ]; then
    source ~/.extra
fi

# Atuin (shell history)
[[ -f "$HOME/.atuin/bin/env" ]] && source "$HOME/.atuin/bin/env"

# Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# Antigravity IDE (installer's ~/.local/bin export omitted — .exports already adds it)
export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"

# Added by Antigravity IDE
export PATH="/Users/evansenter/.antigravity-ide/antigravity-ide/bin:$PATH"
