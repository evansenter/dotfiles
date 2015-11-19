#!/usr/bin/env bash

# Install command-line tools using Homebrew.

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade --all

# Install GNU core utilities (those that come with OS X are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install keychain
brew install coreutils
sudo ln -s /usr/local/bin/gsha256sum /usr/local/bin/sha256sum

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names
# Install Bash 4.
# Note: don’t forget to add `/usr/local/bin/bash` to `/etc/shells` before
# running `chsh`.
brew install bash
brew tap homebrew/versions
brew install bash-completion2

brew install golang

# Install `wget` with IRI support.
brew install wget --with-iri

# Install more recent versions of some OS X tools.
brew install vim --override-system-vi
brew install homebrew/dupes/grep
brew install homebrew/dupes/screen

# Install other useful binaries
brew install ack
brew install bfg
brew install ccat
brew install foremost
brew install git
brew install hashpump
brew install imagemagick --with-webp
brew install lynx
brew install nmap
brew install nvm
brew install p7zip
brew install pigz
brew install pv
brew install rename
brew install rhino
brew install sqlmap
brew install tree
brew install webkit2png
brew install zopfli

# Science stuff
brew tap homebrew/science

brew install astyle
brew install cloc
brew install cmake
brew install fftw
brew install gcutil
brew install gsl
brew install lapack
brew install leiningen
brew install libuv
brew install mysql
brew install r
brew install sqlite
brew install tpl
brew install unison
brew install watch
brew install z

# Remove outdated versions from the cellar.
brew cleanup
