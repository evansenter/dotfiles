#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE}")";

git pull origin master;

function doIt() {
	git submodule update --init --recursive

	rsync \
		--exclude ".DS_Store" \
		--exclude ".git/" \
		--exclude ".gitignore" \
		--exclude ".gitmodules" \
		--exclude "LICENSE-MIT.txt" \
		--exclude "README.md" \
	  --exclude "bootstrap.sh" \
	  -avh --force --no-perms . ~;

	# https://github.com/tmux-plugins/tpm
	tpm_dir="$HOME/.tmux/plugins/tpm"
	if [[ ! -e $tpm_dir ]]; then
		mkdir -p $tpm_dir
		git clone https://github.com/tmux-plugins/tpm $tpm_dir
		if command -v tmux >/dev/null 2>&1 && [[ -e $HOME/.tmux.conf ]]; then
			tmux source $HOME/.tmux.conf
		fi
	fi

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
