.PHONY: check lint test test-hooks test-bootstrap clean install uninstall

# Run all quality gates (lint, syntax check, hook tests, bootstrap tests)
check: lint test test-hooks test-bootstrap

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
	@bash -n home/.macos
	@for f in home/.bin/*; do echo "  $$f"; bash -n "$$f" || exit 1; done
	@echo "Checking zsh syntax..."
	@zsh -n home/.zshrc
	@zsh -n home/.aliases
	@zsh -n home/.exports
	@echo "All syntax checks passed"

# Run hook tests (graceful degradation, error handling)
test-hooks:
	@echo "Running hook tests..."
	@./tests/test-hooks.sh

# Run bootstrap tests (naming consistency, URL migration)
test-bootstrap:
	@echo "Running bootstrap tests..."
	@./tests/test-bootstrap.sh

# Clean generated files
clean:
	@echo "Nothing to clean for dotfiles"

# Install dotfiles (symlink to home directory)
install:
	./bootstrap.sh -f

# Remove dotfiles symlinks
uninstall:
	./uninstall.sh
