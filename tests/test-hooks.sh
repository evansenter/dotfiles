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

# ============================================================================
# Mock event-bus-cli for Integration Testing
# ============================================================================
#
# These mocks validate the API contract between hooks/statusline and the CLI.
# They simulate realistic JSON responses to ensure hooks parse correctly.
#
# WHEN TO UPDATE THESE MOCKS:
# 1. When claude-event-bus CLI response format changes
# 2. When new fields are added that hooks depend on
# 3. When breaking changes are made to command output
#
# HOW TO UPDATE:
# 1. Run the real `event-bus-cli <command>` to see current output format
# 2. Update the corresponding case in setup_mock_event_bus_cli()
# 3. Run tests to verify hooks still work: make test-hooks
#
# WHAT EACH MOCK VALIDATES:
# - register: Returns {session_id, name, client_id, cursor} JSON
# - events: Returns formatted event list with [id] type (channel) format
# - unregister: Returns {success, session_id, client_id} JSON
# - sessions: Returns session list with client_id field (for statusline lookup)
#
# Related issues:
# - https://github.com/evansenter/dotfiles/issues/121 (this RFC)
# - https://github.com/evansenter/claude-event-bus/issues/53 (client_id in output)
#
# ============================================================================
setup_mock_event_bus_cli() {
    cat > "$TEST_TMP/bin/event-bus-cli" << 'MOCK_CLI'
#!/bin/bash
# Mock event-bus-cli for integration testing
# Simulates the real CLI's JSON responses
#
# API version: claude-event-bus#51 (UUID-based session IDs)
# - session_id: UUID/client_id (for API calls)
# - display_id: Human-readable name (for display)

case "$1" in
    register)
        # Parse --name and --client-id from args
        name=""
        client_id=""
        while [[ $# -gt 1 ]]; do
            case "$2" in
                --name) name="$3"; shift 2 ;;
                --client-id) client_id="$3"; shift 2 ;;
                *) shift ;;
            esac
        done
        # Use client_id as session_id if provided, otherwise generate mock UUID
        session_id="${client_id:-test-uuid-1234}"
        # Return registration response with UUID session_id and human-readable display_id
        echo '{"session_id":"'"$session_id"'","display_id":"test-fox","name":"'"$name"'","client_id":"'"$client_id"'","cursor":"cursor-abc123"}'
        ;;

    events)
        # Parse args - real CLI also accepts --order, --exclude-types, --timeout, --limit
        # Currently only --session-id affects output; others are accepted but ignored
        session_id=""
        while [[ $# -gt 1 ]]; do
            case "$2" in
                --session-id) session_id="$3"; shift 2 ;;
                --order|--exclude-types|--timeout|--limit) shift 2 ;;  # Accept but ignore
                *) shift ;;
            esac
        done
        # Return sample events (or "No new events" for polling)
        if [[ -n "$session_id" ]]; then
            echo "[100] task_completed (repo:dotfiles)"
            echo "    Merged PR #42 - Fix authentication"
            echo "    from: test-session at 2026-01-01T12:00:00"
        else
            echo "No events"
        fi
        ;;

    unregister)
        # Parse --client-id from args
        client_id=""
        while [[ $# -gt 1 ]]; do
            case "$2" in
                --client-id) client_id="$3"; shift 2 ;;
                *) shift ;;
            esac
        done
        session_id="${client_id:-test-uuid-1234}"
        # Return success response
        echo '{"success":true,"session_id":"'"$session_id"'","client_id":"'"$client_id"'"}'
        ;;

    sessions)
        # Return session list with client_id (tests statusline lookup)
        # Note: client_id field is required for statusline lookups
        # Format matches claude-event-bus#51 (UUID-based session IDs)
        echo "Active sessions (1):"
        echo ""
        echo "  test-fox  dotfiles/main"
        echo "    repo: dotfiles, machine: test-machine"
        echo "    client_id: test-client-uuid-1234"
        echo "    age: 100s"
        echo "    channels: all, session:test-client-uuid-1234, repo:dotfiles, machine:test-machine"
        ;;

    *)
        echo "Unknown command: $1" >&2
        exit 1
        ;;
esac
MOCK_CLI
    chmod +x "$TEST_TMP/bin/event-bus-cli"
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

# Integration test: session-start.sh with mock CLI
test_session_start_happy_path() {
    setup_mock_event_bus_cli

    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-client-uuid","cwd":"/tmp/test-repo"}' | \
        bash "$HOOKS_DIR/session-start.sh" 2>&1) || exit_code=$?

    # Should successfully register and echo confirmation
    # Note: session_id may be UUID (new API) or human-readable (old API)
    [[ $exit_code -eq 0 ]] && \
    [[ "$output" == *"Registered on event bus as:"* ]]
}

test_session_start_parses_session_id() {
    setup_mock_event_bus_cli

    local output
    output=$(echo '{"session_id":"my-client-id","cwd":"/tmp"}' | \
        bash "$HOOKS_DIR/session-start.sh" 2>&1)

    # Verify session_id from registration response is captured and displayed
    # The hook outputs whatever session_id the server returns
    [[ "$output" == *"Registered on event bus as:"* ]] && \
    [[ "$output" == *"my-client-id"* ]]  # client_id echoed back as session_id
}

test_session_start_fetches_events() {
    setup_mock_event_bus_cli

    local output
    output=$(echo '{"session_id":"test-client","cwd":"/tmp"}' | \
        bash "$HOOKS_DIR/session-start.sh" 2>&1)

    # Should fetch and display events after registration
    # Output should contain BOTH registration confirmation AND event content
    [[ "$output" == *"Registered"* ]] && [[ "$output" == *"task_completed"* ]]
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

# Integration test: session-end.sh with mock CLI
test_session_end_happy_path() {
    setup_mock_event_bus_cli

    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-client-uuid"}' | \
        bash "$HOOKS_DIR/session-end.sh" 2>&1) || exit_code=$?

    # Should successfully unregister and echo confirmation
    [[ $exit_code -eq 0 ]] && \
    [[ "$output" == *"Unregistered from event bus"* ]]
}

test_session_end_parses_response() {
    setup_mock_event_bus_cli

    local output
    output=$(echo '{"session_id":"my-client-id"}' | \
        bash "$HOOKS_DIR/session-end.sh" 2>&1)

    # Should parse and display the session_id from unregister response
    # The hook outputs whatever session_id the server returns
    [[ "$output" == *"Unregistered from event bus:"* ]] && \
    [[ "$output" == *"my-client-id"* ]]  # client_id echoed back as session_id
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

# Integration test: prompt-events.sh with mock CLI
test_prompt_events_happy_path() {
    setup_mock_event_bus_cli

    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-fox"}' | \
        bash "$HOOKS_DIR/prompt-events.sh" 2>&1) || exit_code=$?

    # Should successfully fetch events
    [[ $exit_code -eq 0 ]]
}

test_prompt_events_returns_events() {
    setup_mock_event_bus_cli

    local output
    output=$(echo '{"session_id":"test-fox"}' | \
        bash "$HOOKS_DIR/prompt-events.sh" 2>&1)

    # Should return event content from mock
    [[ "$output" == *"task_completed"* ]] || [[ "$output" == *"PR #42"* ]]
}

test_prompt_events_passes_session_id() {
    setup_mock_event_bus_cli

    # The mock returns different output based on session_id presence
    # With session_id: returns events
    # Without: returns "No events"
    local output_with
    output_with=$(echo '{"session_id":"test-session"}' | \
        bash "$HOOKS_DIR/prompt-events.sh" 2>&1)

    # Should receive task_completed event when session_id is passed
    [[ "$output_with" == *"task_completed"* ]] || [[ "$output_with" == *"PR #42"* ]]
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

# Integration test: statusline client_id lookup
# This test verifies the statusline can find sessions by client_id
# IMPORTANT: This will fail if event-bus-cli doesn't output client_id
test_statusline_client_id_lookup() {
    setup_mock_event_bus_cli

    # Clear any cached session lookup
    rm -rf /tmp/claude-statusline-* 2>/dev/null || true

    # Input with session_id that should match mock's client_id
    local input='{"workspace":{"current_dir":"/tmp"},"context_window":{"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000},"model":{"id":"test"},"session_id":"test-client-uuid-1234"}'
    local output
    output=$(bash "$STATUSLINE_SCRIPT" <<< "$input" 2>/dev/null) || true

    # Should find session name via client_id lookup and NOT show [no-session]
    # The mock returns "test-fox" as the session name
    if [[ "$output" == *"[no-session]"* ]]; then
        # This indicates the lookup failed - client_id field might be missing from CLI output
        return 1
    fi
    # Either shows session name or exits gracefully
    [[ "$output" == *"test-fox"* ]] || [[ -z "$output" ]] || [[ "$output" != *"[no-session]"* ]]
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
    run_test "integration: happy path" "test_session_start_happy_path"
    run_test "integration: parses session_id" "test_session_start_parses_session_id"
    run_test "integration: fetches events" "test_session_start_fetches_events"
    echo ""

    echo "=== session-end.sh ==="
    run_test "syntax check" "test_session_end_syntax"
    run_test "graceful degradation (no jq)" "test_session_end_graceful_no_jq"
    run_test "graceful degradation (no event-bus-cli)" "test_session_end_graceful_no_cli"
    run_test "graceful degradation (no session_id)" "test_session_end_graceful_no_session_id"
    run_test "integration: happy path" "test_session_end_happy_path"
    run_test "integration: parses response" "test_session_end_parses_response"
    echo ""

    echo "=== prompt-events.sh ==="
    run_test "syntax check" "test_prompt_events_syntax"
    run_test "graceful degradation (no event-bus-cli)" "test_prompt_events_graceful_no_cli"
    run_test "graceful degradation (no session_id)" "test_prompt_events_graceful_no_session_id"
    run_test "integration: happy path" "test_prompt_events_happy_path"
    run_test "integration: returns events" "test_prompt_events_returns_events"
    run_test "integration: passes session_id" "test_prompt_events_passes_session_id"
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
    run_test "integration: client_id lookup" "test_statusline_client_id_lookup"
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
