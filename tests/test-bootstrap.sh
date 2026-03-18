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
