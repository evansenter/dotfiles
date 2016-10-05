# Load the shell dotfiles, and then some:
# * ~/.path can be used to extend `$PATH`.
# * ~/.extra can be used for other settings you don’t want to commit.
for file in ~/.{path,bash_prompt,exports,aliases,functions,extra}; do
	[ -r "$file" ] && [ -f "$file" ] && source "$file";
done;
unset file;

# Load OSX-specific Bash settings.
if [ -r "$HOME/.bash_mac" ] && [ -f "$HOME/.bash_mac" ] && [ $(uname -s) == "Darwin" ]; then
  source "$HOME/.bash_mac";
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

# Add tab completion for SSH hostnames based on ~/.ssh/config, ignoring wildcards
[ -e "$HOME/.ssh/config" ] && complete -o "default" -o "nospace" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | cut -d " " -f2- | tr ' ' '\n')" scp sftp ssh;

# https://github.com/shyiko/commacd
source $HOME/.commacd.bash

# https://github.com/Jintin/aliasme
source $HOME/.aliasme/aliasme.sh

# https://github.com/junegunn/fzf
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
