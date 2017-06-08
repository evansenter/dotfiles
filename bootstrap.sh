#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin master;

function doIt() {
	g submodule update --init --recursive

	rsync \
		--exclude ".DS_Store" \
		--exclude ".git/" \
		--exclude ".gitignore" \
		--exclude ".gitmodules" \
		--exclude ".macos" \
		--exclude "LICENSE-MIT.txt" \
		--exclude "README.md" \
	  --exclude "bootstrap.sh" \
	  --exclude "brew.sh" \
	  --exclude "Gemfile" \
	  --exclude "z/" \
	  --exclude "LICENSE-MIT.txt" \
	  --exclude "README.md" \
	  -avh --no-perms . ~;

	# https://github.com/tmux-plugins/tpm
	tpm_dir="$HOME/.tmux/plugins/tpm"
	if [[ ! -e $tpm_dir ]]; then
		mkdir -p $tpm_dir
		git clone https://github.com/tmux-plugins/tpm $tpm_dir
		if command -v tmux >/dev/null 2>&1 && [[ -e $HOME/.tmux.conf ]]; then
			tmux source $HOME/.tmux.conf
		fi
	fi

	# https://github.com/dborzov/lsp
	if command -v go >/dev/null 2>&1; then
		go get github.com/dborzov/lsp
	fi

	# https://github.com/shyiko/commacd
	curl https://raw.githubusercontent.com/shyiko/commacd/master/commacd.bash -o $HOME/.commacd.bash

	# https://github.com/Jintin/aliasme
	aliasme_dir="$HOME/.aliasme"
	if [[ ! -e $aliasme_dir ]]; then
    mkdir $aliasme_dir
	fi
	curl https://raw.githubusercontent.com/Jintin/aliasme/master/aliasme.sh > $aliasme_dir/aliasme.sh

	source ~/.bash_profile;
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
	doIt;
else
	read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
	echo "";
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		doIt;
	fi;
fi;
unset doIt;
