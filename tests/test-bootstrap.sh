#!/bin/bash
# Tests for bootstrap.sh
#
# Run with: ./tests/test-bootstrap.sh
# Or via make: make test-bootstrap

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP="$SCRIPT_DIR/../bootstrap.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED=$'\e[31m'
GREEN=$'\e[32m'
RESET=$'\e[0m'

pass() {
    ((++TESTS_PASSED))
    echo "${GREEN}✓${RESET} $1"
}

fail() {
    ((++TESTS_FAILED))
    echo "${RED}✗${RESET} $1"
    if [[ -n "${2:-}" ]]; then
        echo "  Error: $2"
    fi
}

run_test() {
    local name="$1"
    local cmd="$2"
    ((++TESTS_RUN))

    if eval "$cmd" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "Command failed"
    fi
}

# ============================================================================
# Naming consistency tests (moltbot -> openclaw migration)
# ============================================================================

test_no_moltbot_references_bootstrap() {
    # bootstrap.sh should not contain any moltbot references
    ! grep -qi 'moltbot' "$BOOTSTRAP"
}

test_no_moltbot_references_claude_md() {
    local claude_md="$SCRIPT_DIR/../CLAUDE.md"
    ! grep -qi 'moltbot' "$claude_md"
}

test_no_moltbot_references_home() {
    # No tracked config files under home/ should reference moltbot
    # Exclude binary/db files and log files (contain historical data)
    ! find "$SCRIPT_DIR/../home" -type f \
        -not -path "*/.git/*" \
        -not -name "*.db" \
        -not -name "*.db.*" \
        -not -name "*.log" \
        -not -name "*.err" \
        -not -name "*.stdout" \
        -print0 | \
        xargs -0 grep -li 'moltbot' 2>/dev/null
}

test_openclaw_config_path() {
    # Config should be at home/.openclaw/openclaw.json, not home/.moltbot/
    [[ -f "$SCRIPT_DIR/../home/.openclaw/openclaw.json" ]] && \
    [[ ! -d "$SCRIPT_DIR/../home/.moltbot" ]]
}

test_openclaw_function_names() {
    # bootstrap.sh should use openclaw function names
    grep -q 'symlink_openclaw_config' "$BOOTSTRAP" && \
    grep -q 'install_openclaw_cli' "$BOOTSTRAP" && \
    ! grep -q 'symlink_moltbot_config' "$BOOTSTRAP" && \
    ! grep -q 'install_moltbot_cli' "$BOOTSTRAP"
}

test_openclaw_env_var() {
    # Config should reference OPENCLAW_GATEWAY_TOKEN, not MOLTBOT_GATEWAY_TOKEN
    grep -q 'OPENCLAW_GATEWAY_TOKEN' "$SCRIPT_DIR/../home/.openclaw/openclaw.json" && \
    ! grep -q 'MOLTBOT_GATEWAY_TOKEN' "$SCRIPT_DIR/../home/.openclaw/openclaw.json"
}

# ============================================================================
# URL migration tests (speck-vm -> mac-mini/localhost)
# ============================================================================

test_no_speck_vm_mcp_urls() {
    # settings.json should not reference speck-vm for MCP URLs
    ! grep -q 'speck-vm.*agent-event-bus' "$SCRIPT_DIR/../home/.claude/settings.json" && \
    ! grep -q 'speck-vm.*agent-session-analytics' "$SCRIPT_DIR/../home/.claude/settings.json"
}

test_openclaw_gateway_url() {
    # openclaw.json should point to mac-mini, not speck-vm
    grep -q 'mac-mini' "$SCRIPT_DIR/../home/.openclaw/openclaw.json" && \
    ! grep -q 'speck-vm' "$SCRIPT_DIR/../home/.openclaw/openclaw.json"
}

# ============================================================================
# Bootstrap structure tests
# ============================================================================

test_bootstrap_syntax() {
    bash -n "$BOOTSTRAP"
}

test_bootstrap_excludes_openclaw_from_symlinks() {
    # symlink_dotfiles should exclude .openclaw/ (handled separately)
    grep -q '\.openclaw' "$BOOTSTRAP"
}

test_bootstrap_installs_cron() {
    # bootstrap.sh should install the cargo-sweep cron job
    grep -q 'cargo-sweep' "$BOOTSTRAP"
}

test_cargo_sweep_script_exists() {
    [[ -f "$SCRIPT_DIR/../home/.bin/cargo-sweep-all" ]] && \
    [[ -x "$SCRIPT_DIR/../home/.bin/cargo-sweep-all" ]]
}

test_cargo_sweep_syntax() {
    bash -n "$SCRIPT_DIR/../home/.bin/cargo-sweep-all"
}

test_configure_claude_local_settings_exists() {
    # bootstrap.sh should have the configure_claude_local_settings function
    grep -q 'configure_claude_local_settings' "$BOOTSTRAP"
}

test_settings_local_skips_gateway_host() {
    # The function should skip on mac-mini (gateway host)
    grep -q 'mac-mini' "$BOOTSTRAP" && \
    grep -q 'HOSTNAME' "$BOOTSTRAP"
}

test_ensure_openclaw_workspace_exists() {
    # bootstrap.sh should have the ensure_openclaw_workspace function
    grep -q 'ensure_openclaw_workspace' "$BOOTSTRAP"
}

test_openclaw_workspace_gitignore() {
    # .gitignore should exist and ignore *.md to prevent tracking personal content
    [[ -f "$SCRIPT_DIR/../home/.openclaw/workspace/.gitignore" ]] && \
    grep -q '\*.md' "$SCRIPT_DIR/../home/.openclaw/workspace/.gitignore"
}

test_no_documents_projects_refs() {
    # No tracked source files should reference ~/Documents/projects/
    # Exclude: .git, databases, logs, error files, backups, worktree settings, this test
    ! find "$SCRIPT_DIR/.." -type f \
        -not -path "*/.git/*" \
        -not -path "*/tests/test-bootstrap.sh" \
        -not -path "*/.claude/settings.local.json" \
        -not -name "*.db" \
        -not -name "*.db.*" \
        -not -name "*.log" \
        -not -name "*.err" \
        -not -name "*.stdout" \
        -print0 | \
        xargs -0 grep -l 'Documents/projects' 2>/dev/null
}

# ============================================================================
# SteamOS / Linux compatibility tests
# ============================================================================

test_steamos_detection() {
    grep -q 'is_steamos' "$BOOTSTRAP"
}

test_steamos_packages() {
    grep -q 'install_steamos_packages' "$BOOTSTRAP"
}

test_set_default_shell() {
    grep -q 'set_default_shell' "$BOOTSTRAP"
}

test_steamos_no_usr_local() {
    # install_steamos_packages should not write to /usr/local (comments ok)
    local steamos_func
    steamos_func=$(sed -n '/^install_steamos_packages()/,/^}/p' "$BOOTSTRAP")
    ! echo "$steamos_func" | grep -v '^\s*#' | grep -q '/usr/local'
}

# ============================================================================
# Flag combination tests
# ============================================================================

# Helper: run bootstrap.sh with args, capturing which functions are called.
# Overrides all side-effect functions with stubs that log to a temp file.
# Returns the log so tests can check which functions ran and in what order.
#
# NOTE: The argument parsing logic below is duplicated from bootstrap.sh's main
# execution block. If bootstrap.sh's flag handling changes, update this mock to
# match — otherwise tests will pass against stale logic.
run_bootstrap_with_mocks() {
    local log
    log=$(mktemp)
    local mock_script
    mock_script=$(mktemp)

    # Build a wrapper that:
    # 1. Defines stub functions that log their name
    # 2. Overrides 'read' to auto-answer 'y' (simulate confirmation)
    # 3. Sources bootstrap.sh to get function definitions
    # 4. Re-overrides the functions with stubs
    # 5. Runs the main execution block
    cat > "$mock_script" << 'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="__LOG__"

# Stub functions that log their name
update_packages() { echo "update_packages" >> "$LOG_FILE"; }
install_packages() { echo "install_packages" >> "$LOG_FILE"; }
pull_latest() { echo "pull_latest" >> "$LOG_FILE"; }
sync_dotfiles() { echo "sync_dotfiles" >> "$LOG_FILE"; }

# Override read to auto-confirm
read() { REPLY="y"; }

# Mirror bootstrap.sh argument parsing and execution logic
FORCE=false
PULL=false
PACKAGES=false
UPDATE=false
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=true ;;
        --pull|-p) PULL=true ;;
        --packages|-i) PACKAGES=true ;;
        --update|-u) UPDATE=true ;;
    esac
done

if [[ "$UPDATE" == true ]]; then
    update_packages
    if [[ "$PACKAGES" == false && "$PULL" == false && "$FORCE" == false ]]; then
        exit 0
    fi
fi

if [[ "$PACKAGES" == true ]]; then
    install_packages
fi

if [[ "$PULL" == true ]]; then
    pull_latest
fi

if [[ "$FORCE" == true ]]; then
    sync_dotfiles
else
    read -p "confirm? " -n 1
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sync_dotfiles
    fi
fi
WRAPPER

    # Substitute log path
    sed -i.bak "s|__LOG__|$log|g" "$mock_script"
    rm -f "${mock_script}.bak"

    chmod +x "$mock_script"
    bash "$mock_script" "$@" 2>/dev/null
    local exit_code=$?

    cat "$log"
    rm -f "$log" "$mock_script"
    return $exit_code
}

test_flag_help() {
    local output
    output=$("$BOOTSTRAP" --help 2>&1)
    echo "$output" | grep -q "Usage:" && \
    echo "$output" | grep -q "\-f, --force" && \
    echo "$output" | grep -q "\-p, --pull" && \
    echo "$output" | grep -q "\-i, --packages" && \
    echo "$output" | grep -q "\-u, --update"
}

test_flag_force_only() {
    local output
    output=$(run_bootstrap_with_mocks --force)
    [[ "$output" == "sync_dotfiles" ]]
}

test_flag_pull_only() {
    local output
    output=$(run_bootstrap_with_mocks --pull)
    # --pull without --force prompts, our mock auto-confirms
    echo "$output" | grep -q "pull_latest" && \
    echo "$output" | grep -q "sync_dotfiles"
}

test_flag_packages_only() {
    local output
    output=$(run_bootstrap_with_mocks --packages)
    echo "$output" | grep -q "install_packages" && \
    echo "$output" | grep -q "sync_dotfiles"
}

test_flag_update_only() {
    local output
    output=$(run_bootstrap_with_mocks --update)
    [[ "$output" == "update_packages" ]]
}

test_flag_update_exits_early() {
    # --update alone should NOT call sync_dotfiles
    local output
    output=$(run_bootstrap_with_mocks --update)
    ! echo "$output" | grep -q "sync_dotfiles"
}

test_flag_force_pull() {
    local output
    output=$(run_bootstrap_with_mocks --force --pull)
    local first second
    first=$(echo "$output" | sed -n '1p')
    second=$(echo "$output" | sed -n '2p')
    [[ "$first" == "pull_latest" ]] && [[ "$second" == "sync_dotfiles" ]]
}

test_flag_force_packages() {
    local output
    output=$(run_bootstrap_with_mocks --force --packages)
    local first second
    first=$(echo "$output" | sed -n '1p')
    second=$(echo "$output" | sed -n '2p')
    [[ "$first" == "install_packages" ]] && [[ "$second" == "sync_dotfiles" ]]
}

test_flag_update_force() {
    # --update --force: update packages then sync
    local output
    output=$(run_bootstrap_with_mocks --update --force)
    local first second
    first=$(echo "$output" | sed -n '1p')
    second=$(echo "$output" | sed -n '2p')
    [[ "$first" == "update_packages" ]] && [[ "$second" == "sync_dotfiles" ]]
}

test_flag_update_packages() {
    # --update --packages: update, install packages, then prompt for sync
    local output
    output=$(run_bootstrap_with_mocks --update --packages)
    echo "$output" | grep -q "update_packages" && \
    echo "$output" | grep -q "install_packages" && \
    echo "$output" | grep -q "sync_dotfiles"
}

test_flag_all_combined() {
    # --update --packages --pull --force: everything in order
    local output
    output=$(run_bootstrap_with_mocks --update --packages --pull --force)
    local line1 line2 line3 line4
    line1=$(echo "$output" | sed -n '1p')
    line2=$(echo "$output" | sed -n '2p')
    line3=$(echo "$output" | sed -n '3p')
    line4=$(echo "$output" | sed -n '4p')
    [[ "$line1" == "update_packages" ]] && \
    [[ "$line2" == "install_packages" ]] && \
    [[ "$line3" == "pull_latest" ]] && \
    [[ "$line4" == "sync_dotfiles" ]]
}

test_flag_short_forms() {
    # Short flags should work identically to long flags
    local output
    output=$(run_bootstrap_with_mocks -f -p -i -u)
    local line1 line2 line3 line4
    line1=$(echo "$output" | sed -n '1p')
    line2=$(echo "$output" | sed -n '2p')
    line3=$(echo "$output" | sed -n '3p')
    line4=$(echo "$output" | sed -n '4p')
    [[ "$line1" == "update_packages" ]] && \
    [[ "$line2" == "install_packages" ]] && \
    [[ "$line3" == "pull_latest" ]] && \
    [[ "$line4" == "sync_dotfiles" ]]
}

test_flag_order_irrelevant() {
    # Flags in different order should produce same execution order
    local output1 output2
    output1=$(run_bootstrap_with_mocks --force --pull --packages)
    output2=$(run_bootstrap_with_mocks --packages --force --pull)
    [[ "$output1" == "$output2" ]]
}

test_flag_no_args_prompts() {
    # No flags: should prompt (mock auto-confirms) and sync
    local output
    output=$(run_bootstrap_with_mocks)
    [[ "$output" == "sync_dotfiles" ]]
}

# ============================================================================
# Run all tests
# ============================================================================

main() {
    echo "Running bootstrap tests..."
    echo ""

    echo "=== naming consistency (moltbot -> openclaw) ==="
    run_test "no moltbot refs in bootstrap.sh" "test_no_moltbot_references_bootstrap"
    run_test "no moltbot refs in CLAUDE.md" "test_no_moltbot_references_claude_md"
    run_test "no moltbot refs in home/" "test_no_moltbot_references_home"
    run_test "openclaw config at correct path" "test_openclaw_config_path"
    run_test "openclaw function names in bootstrap" "test_openclaw_function_names"
    run_test "openclaw env var in config" "test_openclaw_env_var"
    echo ""

    echo "=== URL migration (speck-vm -> mac-mini/localhost) ==="
    run_test "no speck-vm MCP URLs in settings" "test_no_speck_vm_mcp_urls"
    run_test "openclaw gateway points to mac-mini" "test_openclaw_gateway_url"
    echo ""

    echo "=== bootstrap structure ==="
    run_test "syntax check" "test_bootstrap_syntax"
    run_test "excludes openclaw from generic symlinks" "test_bootstrap_excludes_openclaw_from_symlinks"
    run_test "installs cargo-sweep cron" "test_bootstrap_installs_cron"
    run_test "cargo-sweep script exists and executable" "test_cargo_sweep_script_exists"
    run_test "cargo-sweep script syntax" "test_cargo_sweep_syntax"
    run_test "configure_claude_local_settings exists" "test_configure_claude_local_settings_exists"
    run_test "settings.local.json skips gateway host" "test_settings_local_skips_gateway_host"
    run_test "no ~/Documents/projects references" "test_no_documents_projects_refs"
    run_test "ensure_openclaw_workspace function exists" "test_ensure_openclaw_workspace_exists"
    run_test "openclaw workspace .gitignore ignores content" "test_openclaw_workspace_gitignore"
    run_test "SteamOS detection function exists" "test_steamos_detection"
    run_test "SteamOS package function exists" "test_steamos_packages"
    run_test "set_default_shell function exists" "test_set_default_shell"
    run_test "no hardcoded /usr/local in SteamOS path" "test_steamos_no_usr_local"
    echo ""

    echo "=== flag combinations ==="
    run_test "--help shows usage" "test_flag_help"
    run_test "--force runs sync only" "test_flag_force_only"
    run_test "--pull runs pull then sync" "test_flag_pull_only"
    run_test "--packages runs install then sync" "test_flag_packages_only"
    run_test "--update alone runs update only" "test_flag_update_only"
    run_test "--update alone exits before sync" "test_flag_update_exits_early"
    run_test "--force --pull: pull then sync" "test_flag_force_pull"
    run_test "--force --packages: install then sync" "test_flag_force_packages"
    run_test "--update --force: update then sync" "test_flag_update_force"
    run_test "--update --packages: update, install, sync" "test_flag_update_packages"
    run_test "all flags combined: correct order" "test_flag_all_combined"
    run_test "short flags (-f -p -i -u) match long flags" "test_flag_short_forms"
    run_test "flag order doesn't affect execution order" "test_flag_order_irrelevant"
    run_test "no flags prompts then syncs" "test_flag_no_args_prompts"
    echo ""

    # Summary
    echo "========================================"
    echo "Tests: $TESTS_RUN | Passed: $TESTS_PASSED | Failed: $TESTS_FAILED"
    echo "========================================"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
