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

# ==============================================================================
# Key Bindings
# ==============================================================================

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
# Personal Customizations
# ==============================================================================

# Load personal customizations (not tracked by repo)
# This is sourced last so it can override any settings above
if [ -f ~/.extra ]; then
    source ~/.extra
fi
