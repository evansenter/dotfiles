#!/usr/bin/env bash

# Install command-line tools using Homebrew.

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

# Install GNU core utilities (those that come with macOS are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install keychain
brew install gpg
brew install gpg-agent
brew install coreutils
ln -s "${BREW_PREFIX}/bin/gsha256sum" "${BREW_PREFIX}/bin/sha256sum"

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names
# Install Bash 4.
brew install bash
brew install bash-completion2

# Switch to using brew-installed bash as default shell
if ! fgrep -q "${BREW_PREFIX}/bin/bash" /etc/shells; then
  echo "${BREW_PREFIX}/bin/bash" | sudo tee -a /etc/shells;
  chsh -s "${BREW_PREFIX}/bin/bash";
fi;

# Install `wget` with IRI support.
brew install wget --with-iri

# Install more recent versions of some macOS tools.
brew install vim --with-override-system-vi
brew install grep
brew install homebrew/dupes/screen

# Install other useful packages
brew install bazel
brew install ccat
brew install diff-so-fancy
brew install fzf
brew install gcc
brew install git
brew install mosh
brew install nmap
brew install nvm
brew install p7zip
brew install rename
brew install tig
brew install tmux
brew install rlwrap
brew install tree

# Science stuff
brew tap homebrew/science

brew install astyle
brew install cloc
brew install cmake
brew install fftw
brew install gnuplot --with-aquaterm
brew install gsl
brew install lapack
brew install leiningen
brew install libuv
brew install maven
brew install mysql
brew install postgres
brew install python
brew install r
brew install sqlite
brew install tpl
brew install unison
brew install watch
brew install z

# Remove outdated versions from the cellar.
brew cleanup
