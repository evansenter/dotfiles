# Install command-line tools using Homebrew
# Usage: `brew tap Homebrew/bundle && brew bundle`

# Make sure we’re using the latest Homebrew
update

# Upgrade any already-installed formulae
upgrade

# Install GNU core utilities (those that come with OS X are outdated)
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
install coreutils
# Install some other useful utilities like `sponge`
install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed
install findutils
# Install GNU `sed`, overwriting the built-in `sed`
install gnu-sed, args: ["default-names"]
# Install Bash 4
# Note: don’t forget to add `$(brew --prefix)/bin/bash` to `/etc/shells` before running `chsh`.
install bash
install bash-completion
install htop

# Install wget with IRI support
install wget, args: ["enable-iri"]

# Install RingoJS and Narwhal
# Note that the order in which these are installed is important; see http://git.io/brew-narwhal-ringo.
install ringojs
install narwhal

# Install more recent versions of some OS X tools
install vim, args: ["override-system-vi"]
install homebrew/dupes/grep
install homebrew/dupes/screen

# Install other useful binaries
install ack
install bfg
install foremost
install git
install hashpump
install imagemagick, args: ["with-webp"]
install lynx
install nmap
install nvm
install p7zip
install pigz
install pv
install rename
install rhino
install sqlmap
install tree
install webkit2png
install zopfli

# Science stuff
tap homebrew/science

install astyle
install cloc
install cmake
install fftw
install gcutil
install gsl
install lapack
install leiningen
install libuv
install mysql
install r
install sqlite
install tpl
install unison
install watch
install z

# Remove outdated versions from the cellar
cleanup
