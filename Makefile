.PHONY: check lint test clean install uninstall

# Run all quality gates (lint, syntax check)
check: lint test

# Run shellcheck on all shell scripts (matches CI)
lint:
	@echo "Running shellcheck..."
	@find . -type f -name "*.sh" \
		-not -path "./vendor/*" \
		-not -path "./.git/*" \
		-print0 | xargs -0 -r shellcheck --severity=error

# Run syntax checks on shell scripts
test:
	@echo "Checking bash syntax..."
	@bash -n bootstrap.sh
	@bash -n uninstall.sh
	@echo "Checking zsh syntax..."
	@zsh -n home/.zshrc
	@zsh -n home/.aliases
	@zsh -n home/.exports
	@echo "All syntax checks passed"

# Clean generated files
clean:
	@echo "Nothing to clean for dotfiles"

# Install dotfiles (symlink to home directory)
install:
	./bootstrap.sh -f

# Remove dotfiles symlinks
uninstall:
	./uninstall.sh
