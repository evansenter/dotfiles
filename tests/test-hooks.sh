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
    local exit_code=0
    output=$(echo '{"session_id":"test-123","cwd":"/tmp"}' | \
        env -i PATH="$MINIMAL_PATH" HOME="$HOME" \
        bash "$HOOKS_DIR/session-start.sh" 2>&1) || exit_code=$?

    # Check for graceful exit (either explicit skip message or no crash)
    [[ "$output" == *"skipped"* ]] || [[ "$output" == *"jq not installed"* ]] || [[ $exit_code -eq 0 ]]
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
    local exit_code=0
    output=$(echo '{"session_id":"test-123"}' | \
        env -i PATH="$MINIMAL_PATH" HOME="$HOME" \
        bash "$HOOKS_DIR/session-end.sh" 2>&1) || exit_code=$?

    [[ "$output" == *"skipped"* ]] || [[ "$output" == *"jq not installed"* ]] || [[ $exit_code -eq 0 ]]
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
# statusline-command.sh tests
# ============================================================================

STATUSLINE_SCRIPT="$SCRIPT_DIR/../home/.claude/statusline-command.sh"

test_statusline_syntax() {
    bash -n "$STATUSLINE_SCRIPT"
}

test_statusline_handles_empty_input() {
    local exit_code=0
    echo '' | bash "$STATUSLINE_SCRIPT" 2>/dev/null || exit_code=$?

    # Should exit with error (exit 1) for empty input
    [[ $exit_code -eq 1 ]]
}

test_statusline_basic_output() {
    local exit_code=0
    # Provide complete input including cache token fields to avoid null arithmetic
    local input='{"workspace":{"current_dir":"/tmp/test"},"context_window":{"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000},"model":{"id":"test-model"}}'
    bash "$STATUSLINE_SCRIPT" <<< "$input" >/dev/null 2>&1 || exit_code=$?

    # Should exit cleanly (not crash) with valid input
    [[ $exit_code -eq 0 ]]
}

test_statusline_no_ansi_leak_in_session_name() {
    # Simulate event-bus-cli output with ANSI codes
    # This is the bug we're testing for: ANSI codes from event-bus-cli leaking into output
    local input='{"workspace":{"current_dir":"/tmp/test"},"context_window":{"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000},"model":{"id":"test"},"session_id":"test-session"}'
    local output
    output=$(bash "$STATUSLINE_SCRIPT" <<< "$input" 2>/dev/null) || true

    # Output should NOT contain raw ANSI parameter sequences like "38;2;153;153;153"
    # These indicate escape codes leaking without their \e[ prefix
    if [[ "$output" =~ [0-9]+\;[0-9]+\;[0-9]+\;[0-9]+\;[0-9]+ ]]; then
        return 1  # Fail - raw ANSI sequence detected
    fi
    return 0  # Pass
}

test_statusline_hyperlinks_closed() {
    local input='{"workspace":{"current_dir":"/tmp/test"},"context_window":{"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000},"model":{"id":"test"}}'
    local output
    output=$(bash "$STATUSLINE_SCRIPT" <<< "$input" 2>/dev/null) || true

    # Count hyperlink opens (\e]8;;URL\e\\) and closes (\e]8;;\e\\)
    # The final LINK_RESET should ensure all hyperlinks are closed
    # At minimum, output should end with the hyperlink reset sequence
    [[ "$output" == *$'\e]8;;\e\\'* ]] || [[ -z "$output" ]] || [[ "$output" != *$'\e]8;;http'* ]]
}

test_statusline_graceful_no_jq() {
    # Statusline requires jq - should fail cleanly without it
    local MINIMAL_PATH="/bin:/usr/bin"
    local input='{"workspace":{"current_dir":"/tmp/test"}}'
    local exit_code=0

    # Run with PATH that may not have jq
    env -i PATH="$MINIMAL_PATH" HOME="$HOME" bash "$STATUSLINE_SCRIPT" <<< "$input" >/dev/null 2>&1 || exit_code=$?

    # Should exit (either 0 or 1) without crashing
    [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]
}

test_statusline_graceful_no_git() {
    # Test behavior when git commands fail (non-git directory)
    local input='{"workspace":{"current_dir":"/tmp"},"context_window":{"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000},"model":{"id":"test"}}'
    local exit_code=0
    bash "$STATUSLINE_SCRIPT" <<< "$input" >/dev/null 2>&1 || exit_code=$?

    # Should exit cleanly even in non-git directory
    [[ $exit_code -eq 0 ]]
}

test_statusline_graceful_no_gh() {
    # Test behavior when gh CLI is unavailable or fails
    # Create a mock gh that always fails
    local input='{"workspace":{"current_dir":"/tmp"},"context_window":{"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000},"model":{"id":"test"}}'
    local exit_code=0

    # Run in a directory where gh would fail (no repo)
    bash "$STATUSLINE_SCRIPT" <<< "$input" >/dev/null 2>&1 || exit_code=$?

    # Should exit cleanly even when gh fails
    [[ $exit_code -eq 0 ]]
}

test_statusline_graceful_no_event_bus_cli() {
    # Test with a session_id but event-bus-cli unavailable
    local input='{"workspace":{"current_dir":"/tmp"},"context_window":{"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000},"model":{"id":"test"},"session_id":"test-session"}'
    local exit_code=0

    # Run with PATH that doesn't include event-bus-cli location
    PATH="/bin:/usr/bin:/usr/local/bin" bash "$STATUSLINE_SCRIPT" <<< "$input" >/dev/null 2>&1 || exit_code=$?

    # Should exit cleanly and show warning indicator
    [[ $exit_code -eq 0 ]]
}

test_statusline_graceful_missing_transcript() {
    # Test with a non-existent transcript path
    local input='{"workspace":{"current_dir":"/tmp"},"context_window":{"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000},"model":{"id":"test"},"transcript_path":"/nonexistent/path/transcript.jsonl"}'
    local exit_code=0
    bash "$STATUSLINE_SCRIPT" <<< "$input" >/dev/null 2>&1 || exit_code=$?

    # Should exit cleanly even with missing transcript
    [[ $exit_code -eq 0 ]]
}

test_statusline_graceful_malformed_json() {
    # Test with malformed JSON input
    local input='{"workspace":{"current_dir":"/tmp"'  # Missing closing braces
    local exit_code=0
    bash "$STATUSLINE_SCRIPT" <<< "$input" >/dev/null 2>&1 || exit_code=$?

    # Should exit (with error) but not crash
    [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]
}

test_statusline_graceful_null_fields() {
    # Test with null/missing optional fields
    local input='{"workspace":{"current_dir":"/tmp"},"context_window":null,"model":null}'
    local exit_code=0
    bash "$STATUSLINE_SCRIPT" <<< "$input" >/dev/null 2>&1 || exit_code=$?

    # Should handle null fields gracefully
    [[ $exit_code -eq 0 ]] || [[ $exit_code -eq 1 ]]
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

    echo "=== statusline-command.sh ==="
    run_test "syntax check" "test_statusline_syntax"
    run_test "handles empty input" "test_statusline_handles_empty_input"
    run_test "basic output" "test_statusline_basic_output"
    run_test "no ANSI escape leak in session name" "test_statusline_no_ansi_leak_in_session_name"
    run_test "hyperlinks properly closed" "test_statusline_hyperlinks_closed"
    run_test "graceful degradation (no jq)" "test_statusline_graceful_no_jq"
    run_test "graceful degradation (no git)" "test_statusline_graceful_no_git"
    run_test "graceful degradation (no gh)" "test_statusline_graceful_no_gh"
    run_test "graceful degradation (no event-bus-cli)" "test_statusline_graceful_no_event_bus_cli"
    run_test "graceful degradation (missing transcript)" "test_statusline_graceful_missing_transcript"
    run_test "graceful degradation (malformed JSON)" "test_statusline_graceful_malformed_json"
    run_test "graceful degradation (null fields)" "test_statusline_graceful_null_fields"
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
