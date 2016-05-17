# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{path,bash_prompt,exports,aliases,functions,extra}; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file";
done;
unset file;

# Start tmux on shell start, if PS1
if command -v tmux >/dev/null; then
  if [ ! -z "$PS1" ]; then # unless shell not loaded interactively, run tmux
    [[ ! $TERM =~ screen ]] && [ -z $TMUX ] && tmux
  fi
fi

# Case-insensitive globbing (used in pathname expansion)
shopt -s nocaseglob;

# Append to the Bash history file, rather than overwriting it
shopt -s histappend;

# Autocorrect typos in path names when using `cd`
shopt -s cdspell;

# Enable some Bash 4 features when possible:
# * `autocd`, e.g. `**/qux` will enter `./foo/bar/baz/qux`
# * Recursive globbing, e.g. `echo **/*.txt`
for option in autocd globstar; do
	shopt -s "$option" 2> /dev/null;
done;

# Load rupa's z if installed
if command -v brew >/dev/null 2>&1 && [ -f "$(brew --prefix)/etc/profile.d/z.sh" ]; then
	source $(brew --prefix)/etc/profile.d/z.sh
elif [ -r "$HOME/bin/z.sh" ]; then
  source "$HOME/bin/z.sh"
fi

# Enable tab completion for `g` by marking it as an alias for `git`
if command -v brew >/dev/null 2>&1 && type _git &> /dev/null && [ -f "$(brew --prefix)/etc/bash_completion.d/git-completion.bash" ]; then
	complete -o default -o nospace -F _git g;
fi;

# Add tab completion for SSH hostnames based on ~/.ssh/config, ignoring wildcards
[ -e "$HOME/.ssh/config" ] && complete -o "default" -o "nospace" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')" scp sftp ssh;

# Use keychain on OSX for SSH key management
if [ $(uname -s) == "Darwin" ]; then
  # Load up the RSA key
  eval `keychain --eval id_rsa`
fi

# https://github.com/shyiko/commacd
source $HOME/.commacd.bash

# https://github.com/Jintin/aliasme
source $HOME/.aliasme/aliasme.sh

# Source nvm
if command -v brew >/dev/null 2>&1; then
  export NVM_DIR=$HOME/.nvm
  source $(brew --prefix nvm)/nvm.sh
fi

# Source rvm
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
