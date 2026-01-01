#!/bin/bash
# Tests for Claude Code hooks
#
# Run with: ./tests/test-hooks.sh
# Or via make: make test-hooks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../home/.claude/hooks"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED=$'\e[31m'
GREEN=$'\e[32m'
RESET=$'\e[0m'

# Test helper functions
pass() {
    ((TESTS_PASSED++))
    echo "${GREEN}✓${RESET} $1"
}

fail() {
    ((TESTS_FAILED++))
    echo "${RED}✗${RESET} $1"
    if [[ -n "${2:-}" ]]; then
        echo "  Error: $2"
    fi
}

run_test() {
    local name="$1"
    local cmd="$2"
    ((TESTS_RUN++))

    if eval "$cmd" 2>/dev/null; then
        pass "$name"
    else
        fail "$name" "Command failed"
    fi
}

# Create a temporary directory for test isolation
setup_test_env() {
    TEST_TMP=$(mktemp -d)
    export PATH="$TEST_TMP/bin:$PATH"
    mkdir -p "$TEST_TMP/bin"

    # Create mock jq that works
    cat > "$TEST_TMP/bin/jq" << 'EOF'
#!/bin/bash
# Mock jq - minimal implementation for testing
if [[ "$*" == *".session_id"* ]]; then
    cat | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *".cwd"* ]]; then
    cat | grep -o '"cwd":"[^"]*"' | cut -d'"' -f4 || echo ""
else
    cat
fi
EOF
    chmod +x "$TEST_TMP/bin/jq"
}

teardown_test_env() {
    rm -rf "$TEST_TMP"
}

# ============================================================================
# session-start.sh tests
# ============================================================================

test_session_start_syntax() {
    bash -n "$HOOKS_DIR/session-start.sh"
}

test_session_start_graceful_no_jq() {
    # Create a minimal PATH without jq
    # We need: bash, cat, basename, git, command - but not jq
    local MINIMAL_PATH="/bin:/usr/bin"

    # Test with a PATH that definitely doesn't have jq
    # Use env to clear PATH and set minimal one
    local output
    output=$(echo '{"session_id":"test-123","cwd":"/tmp"}' | \
        env -i PATH="$MINIMAL_PATH" HOME="$HOME" \
        bash "$HOOKS_DIR/session-start.sh" 2>&1) || true

    # Check for graceful exit (either explicit skip message or no crash)
    [[ "$output" == *"skipped"* ]] || [[ "$output" == *"jq not installed"* ]] || [[ $? -eq 0 ]]
}

test_session_start_graceful_no_cli() {
    # Test behavior when event-bus-cli is not available
    # In CI: event-bus-cli not installed, expect skip message
    # Locally: event-bus-cli may be installed, expect success or skip
    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-123","cwd":"/tmp"}' | bash "$HOOKS_DIR/session-start.sh" 2>&1) || exit_code=$?

    # Accept any of: skip message, success message, or clean exit
    [[ "$output" == *"skipped"* ]] || \
    [[ "$output" == *"event-bus-cli not installed"* ]] || \
    [[ "$output" == *"Registered"* ]] || \
    [[ $exit_code -eq 0 ]]
}

# ============================================================================
# session-end.sh tests
# ============================================================================

test_session_end_syntax() {
    bash -n "$HOOKS_DIR/session-end.sh"
}

test_session_end_graceful_no_jq() {
    local MINIMAL_PATH="/bin:/usr/bin"
    local output
    output=$(echo '{"session_id":"test-123"}' | \
        env -i PATH="$MINIMAL_PATH" HOME="$HOME" \
        bash "$HOOKS_DIR/session-end.sh" 2>&1) || true

    [[ "$output" == *"skipped"* ]] || [[ "$output" == *"jq not installed"* ]] || [[ $? -eq 0 ]]
}

test_session_end_graceful_no_cli() {
    # Test behavior when event-bus-cli is not available
    # In CI: event-bus-cli not installed, expect skip message
    # Locally: event-bus-cli may be installed, expect success or skip
    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-123"}' | bash "$HOOKS_DIR/session-end.sh" 2>&1) || exit_code=$?

    # Accept any of: skip message, unregister message, or clean exit
    [[ "$output" == *"skipped"* ]] || \
    [[ "$output" == *"event-bus-cli not installed"* ]] || \
    [[ "$output" == *"Unregistered"* ]] || \
    [[ "$output" == *"not found"* ]] || \
    [[ $exit_code -eq 0 ]]
}

test_session_end_graceful_no_session_id() {
    local output
    output=$(echo '{}' | bash "$HOOKS_DIR/session-end.sh" 2>&1) || true

    [[ "$output" == *"skipped"* ]] || [[ "$output" == *"no session_id"* ]]
}

# ============================================================================
# prompt-events.sh tests
# ============================================================================

test_prompt_events_syntax() {
    bash -n "$HOOKS_DIR/prompt-events.sh"
}

test_prompt_events_graceful_no_cli() {
    local output
    local exit_code
    output=$(echo '{"session_id":"test-123"}' | bash "$HOOKS_DIR/prompt-events.sh" 2>&1) || exit_code=$?

    # Should exit cleanly (exit 0) when CLI not available
    # The script exits silently without output
    [[ -z "$output" ]] || [[ "${exit_code:-0}" -eq 0 ]]
}

test_prompt_events_graceful_no_session_id() {
    local output
    output=$(echo '{}' | bash "$HOOKS_DIR/prompt-events.sh" 2>&1) || true

    # Should exit silently when no session_id
    [[ -z "$output" ]] || [[ "$output" == "" ]]
}

# ============================================================================
# Run all tests
# ============================================================================

main() {
    echo "Running hook tests..."
    echo ""

    setup_test_env
    trap teardown_test_env EXIT

    echo "=== session-start.sh ==="
    run_test "syntax check" "test_session_start_syntax"
    run_test "graceful degradation (no jq)" "test_session_start_graceful_no_jq"
    run_test "graceful degradation (no event-bus-cli)" "test_session_start_graceful_no_cli"
    echo ""

    echo "=== session-end.sh ==="
    run_test "syntax check" "test_session_end_syntax"
    run_test "graceful degradation (no jq)" "test_session_end_graceful_no_jq"
    run_test "graceful degradation (no event-bus-cli)" "test_session_end_graceful_no_cli"
    run_test "graceful degradation (no session_id)" "test_session_end_graceful_no_session_id"
    echo ""

    echo "=== prompt-events.sh ==="
    run_test "syntax check" "test_prompt_events_syntax"
    run_test "graceful degradation (no event-bus-cli)" "test_prompt_events_graceful_no_cli"
    run_test "graceful degradation (no session_id)" "test_prompt_events_graceful_no_session_id"
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
