# Load environment variables
if [ -f ~/.exports ]; then
    source ~/.exports
fi

# Load aliases
if [ -f ~/.aliases ]; then
    source ~/.aliases
fi

# Load custom prompt
if [ -f ~/.zsh_prompt ]; then
    source ~/.zsh_prompt
fi

# Enable zsh completion system
autoload -Uz compinit
compinit

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# History configuration
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
