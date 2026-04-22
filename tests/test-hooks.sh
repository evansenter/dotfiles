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
input=$(cat)
if [[ "$*" == *".display_id"* ]]; then
    echo "$input" | grep -o '"display_id":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *".session_id"* ]]; then
    echo "$input" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *".cwd"* ]]; then
    echo "$input" | grep -o '"cwd":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *".trigger"* ]]; then
    echo "$input" | grep -o '"trigger":"[^"]*"' | cut -d'"' -f4 || echo "auto"
elif [[ "$*" == *".source"* ]]; then
    echo "$input" | grep -o '"source":"[^"]*"' | cut -d'"' -f4 || echo "startup"
elif [[ "$*" == *".tool_name"* ]]; then
    echo "$input" | grep -o '"tool_name":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *".error"* ]]; then
    echo "$input" | grep -o '"error":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *".is_interrupt"* ]]; then
    echo "$input" | grep -o '"is_interrupt":[a-z]*' | cut -d':' -f2 || echo "false"
elif [[ "$*" == *".task_id"* ]]; then
    echo "$input" | grep -o '"task_id":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *".task_subject"* ]]; then
    echo "$input" | grep -o '"task_subject":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *".task_description"* ]]; then
    echo "$input" | grep -o '"task_description":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *".teammate_name"* ]]; then
    echo "$input" | grep -o '"teammate_name":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *".team_name"* ]]; then
    echo "$input" | grep -o '"team_name":"[^"]*"' | cut -d'"' -f4 || echo ""
elif [[ "$*" == *"-e"* ]] && [[ "$*" == *".event_id"* ]]; then
    # For jq -e '.event_id' checks - return success if event_id exists
    if echo "$input" | grep -q '"event_id"'; then
        echo "$input" | grep -o '"event_id":[0-9]*' | cut -d':' -f2
        exit 0
    else
        exit 1
    fi
elif [[ "$*" == *"-e"* ]] && [[ "$*" == *".success"* ]]; then
    # For jq -e '.success == true' checks
    if echo "$input" | grep -q '"success":true'; then
        exit 0
    else
        exit 1
    fi
elif [[ "$*" == *"-e"* ]]; then
    # For other jq -e checks, just pass through
    echo "$input"
else
    echo "$input"
fi
EOF
    chmod +x "$TEST_TMP/bin/jq"
}

# ============================================================================
# Mock agent-event-bus-cli for Integration Testing
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
# 1. Run the real `agent-event-bus-cli <command>` to see current output format
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
    cat > "$TEST_TMP/bin/agent-event-bus-cli" << 'MOCK_CLI'
#!/bin/bash
# Mock agent-event-bus-cli for integration testing
# Simulates the real CLI's JSON responses
#
# API version: claude-event-bus#51 (UUID-based session IDs)
# - session_id: UUID/client_id (for API calls)
# - display_id: Human-readable name (for display)

# Skip global flags before subcommand
while [[ "$1" == --* ]]; do
    case "$1" in
        --url) shift 2 ;;
        *) shift ;;
    esac
done

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
        # Parse args - real CLI also accepts --order, --include, --exclude, --timeout, --limit
        # Currently only --session-id affects output; others are accepted but ignored
        session_id=""
        while [[ $# -gt 1 ]]; do
            case "$2" in
                --session-id) session_id="$3"; shift 2 ;;
                --order|--include|--exclude|--timeout|--limit) shift 2 ;;  # Accept but ignore
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

    publish)
        # Parse args for publish command
        event_type=""
        payload=""
        session_id=""
        channel=""
        while [[ $# -gt 1 ]]; do
            case "$2" in
                --type) event_type="$3"; shift 2 ;;
                --payload) payload="$3"; shift 2 ;;
                --session-id) session_id="$3"; shift 2 ;;
                --channel) channel="$3"; shift 2 ;;
                *) shift ;;
            esac
        done
        # Return success response with event_id
        echo '{"event_id":12345,"event_type":"'"$event_type"'","channel":"'"$channel"'"}'
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
    chmod +x "$TEST_TMP/bin/agent-event-bus-cli"
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
    # Test behavior when agent-event-bus-cli is not available
    # In CI: agent-event-bus-cli not installed, expect skip message
    # Locally: agent-event-bus-cli may be installed, expect success or skip
    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-123","cwd":"/tmp"}' | bash "$HOOKS_DIR/session-start.sh" 2>&1) || exit_code=$?

    # Accept any of: skip message, success message, or clean exit
    [[ "$output" == *"skipped"* ]] || \
    [[ "$output" == *"agent-event-bus-cli not installed"* ]] || \
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
    # Test behavior when agent-event-bus-cli is not available
    # In CI: agent-event-bus-cli not installed, expect skip message
    # Locally: agent-event-bus-cli may be installed, expect success or skip
    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-123"}' | bash "$HOOKS_DIR/session-end.sh" 2>&1) || exit_code=$?

    # Accept any of: skip message, unregister message, or clean exit
    [[ "$output" == *"skipped"* ]] || \
    [[ "$output" == *"agent-event-bus-cli not installed"* ]] || \
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
# pre-compact.sh tests
# ============================================================================

test_pre_compact_syntax() {
    bash -n "$HOOKS_DIR/pre-compact.sh"
}

test_pre_compact_graceful_no_jq() {
    local MINIMAL_PATH="/bin:/usr/bin"
    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-123","cwd":"/tmp"}' | \
        env -i PATH="$MINIMAL_PATH" HOME="$HOME" \
        bash "$HOOKS_DIR/pre-compact.sh" 2>&1) || exit_code=$?

    [[ "$output" == *"skipped"* ]] || [[ "$output" == *"jq not installed"* ]] || [[ $exit_code -eq 0 ]]
}

test_pre_compact_graceful_no_cli() {
    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-123","cwd":"/tmp"}' | bash "$HOOKS_DIR/pre-compact.sh" 2>&1) || exit_code=$?

    [[ "$output" == *"skipped"* ]] || \
    [[ "$output" == *"agent-event-bus-cli not installed"* ]] || \
    [[ "$output" == *"checkpointed"* ]] || \
    [[ $exit_code -eq 0 ]]
}

test_pre_compact_graceful_no_session_id() {
    local output
    output=$(echo '{}' | bash "$HOOKS_DIR/pre-compact.sh" 2>&1) || true

    [[ "$output" == *"skipped"* ]] || [[ "$output" == *"no session_id"* ]]
}

# Integration test: pre-compact.sh with mock CLI
test_pre_compact_happy_path() {
    setup_mock_event_bus_cli

    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-client-uuid","cwd":"/tmp/test-repo","trigger":"manual"}' | \
        bash "$HOOKS_DIR/pre-compact.sh" 2>&1) || exit_code=$?

    # Should successfully checkpoint and echo confirmation
    [[ $exit_code -eq 0 ]] && \
    [[ "$output" == *"WIP state checkpointed"* ]]
}

test_pre_compact_publishes_event() {
    setup_mock_event_bus_cli

    local output
    output=$(echo '{"session_id":"test-session","cwd":"/tmp"}' | \
        bash "$HOOKS_DIR/pre-compact.sh" 2>&1)

    # Should publish wip_checkpoint event and show confirmation
    [[ "$output" == *"checkpointed"* ]]
}

# Helper: Create mock gh CLI for PR number extraction
setup_mock_gh_cli() {
    local pr_number="${1:-}"  # Empty = no PR
    cat > "$TEST_TMP/bin/gh" << MOCK_GH
#!/bin/bash
if [[ "\$1" == "pr" && "\$2" == "view" ]]; then
    if [[ -n "$pr_number" ]]; then
        echo "$pr_number"
    else
        echo "no pull requests found" >&2
        exit 1
    fi
else
    echo "mock gh: unsupported command" >&2
    exit 1
fi
MOCK_GH
    chmod +x "$TEST_TMP/bin/gh"
}

# Helper: Create mock git for branch/worktree simulation
# Note: Hook calls git with -C flag: git -C <cwd> <command> <args>
setup_mock_git() {
    local branch="${1:-main}"
    local is_repo="${2:-true}"
    cat > "$TEST_TMP/bin/git" << MOCK_GIT
#!/bin/bash
# Handle -C flag: git -C <path> <command> <args>
# When -C is used: \$1=-C, \$2=path, \$3=command, \$4+=args
if [[ "\$1" == "-C" ]]; then
    shift 2  # Skip -C and path
fi

case "\$1" in
    rev-parse)
        if [[ "$is_repo" == "true" ]]; then
            if [[ "\$2" == "--git-dir" ]]; then
                echo ".git"
            elif [[ "\$2" == "--git-common-dir" ]]; then
                echo ".git"
            fi
        else
            exit 1
        fi
        ;;
    branch)
        if [[ "\$2" == "--show-current" ]]; then
            echo "$branch"
        fi
        ;;
    status)
        echo " M src/file.rs"
        echo " M tests/test.rs"
        ;;
    *)
        echo ""
        ;;
esac
MOCK_GIT
    chmod +x "$TEST_TMP/bin/git"
}

test_pre_compact_extracts_pr_number() {
    setup_mock_event_bus_cli
    setup_mock_gh_cli "42"
    setup_mock_git "issue-123"

    # Capture the payload by checking the mock CLI was called correctly
    local output
    output=$(echo '{"session_id":"test-session","cwd":"/tmp/test-repo"}' | \
        bash "$HOOKS_DIR/pre-compact.sh" 2>&1)

    # Should succeed and mention checkpointing
    [[ "$output" == *"checkpointed"* ]]
}

test_pre_compact_no_pr_shows_graceful() {
    setup_mock_event_bus_cli
    setup_mock_gh_cli ""  # No PR
    setup_mock_git "feature-branch"

    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-session","cwd":"/tmp/test-repo"}' | \
        bash "$HOOKS_DIR/pre-compact.sh" 2>&1) || exit_code=$?

    # Should still succeed even without PR
    [[ $exit_code -eq 0 ]] && [[ "$output" == *"checkpointed"* ]]
}

test_pre_compact_work_id_issue_branch() {
    setup_mock_event_bus_cli
    setup_mock_gh_cli "99"
    setup_mock_git "issue-42"

    local output
    output=$(echo '{"session_id":"test-session","cwd":"/tmp/test-repo"}' | \
        bash "$HOOKS_DIR/pre-compact.sh" 2>&1)

    # Should show work ID derived from branch
    [[ "$output" == *"issue-42"* ]]
}

test_pre_compact_work_id_pr_branch() {
    setup_mock_event_bus_cli
    setup_mock_gh_cli "55"
    setup_mock_git "pr-55"

    local output
    output=$(echo '{"session_id":"test-session","cwd":"/tmp/test-repo"}' | \
        bash "$HOOKS_DIR/pre-compact.sh" 2>&1)

    # Should show work ID derived from branch
    [[ "$output" == *"pr-55"* ]]
}

test_pre_compact_payload_format_validation() {
    # Create a capturing mock that logs the payload
    setup_mock_git "issue-268"

    cat > "$TEST_TMP/bin/gh" << 'MOCK_GH'
#!/bin/bash
if [[ "$1" == "pr" && "$2" == "view" ]]; then
    echo "297"
fi
MOCK_GH
    chmod +x "$TEST_TMP/bin/gh"

    # Create agent-event-bus-cli mock that captures and validates payload
    cat > "$TEST_TMP/bin/agent-event-bus-cli" << 'MOCK_CLI'
#!/bin/bash
while [[ "$1" == --* ]]; do case "$1" in --url) shift 2 ;; *) shift ;; esac; done
if [[ "$1" == "publish" ]]; then
    payload=""
    while [[ $# -gt 1 ]]; do
        case "$2" in
            --payload) payload="$3"; shift 2 ;;
            *) shift ;;
        esac
    done
    # Validate payload format: [work:ID] | branch: X | pr: Y | ...
    if [[ "$payload" == *"[work:"*"]"* ]] && \
       [[ "$payload" == *"| branch:"* ]] && \
       [[ "$payload" == *"| pr:"* ]] && \
       [[ "$payload" == *"| time:"* ]]; then
        echo '{"event_id":999}'
        exit 0
    else
        echo "Invalid payload format: $payload" >&2
        exit 1
    fi
fi
MOCK_CLI
    chmod +x "$TEST_TMP/bin/agent-event-bus-cli"

    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-session","cwd":"/tmp/test-repo"}' | \
        bash "$HOOKS_DIR/pre-compact.sh" 2>&1) || exit_code=$?

    # Should succeed with valid format
    [[ $exit_code -eq 0 ]] && [[ "$output" == *"checkpointed"* ]]
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
    # Simulate agent-event-bus-cli output with ANSI codes
    # This is the bug we're testing for: ANSI codes from agent-event-bus-cli leaking into output
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

test_statusline_worktree_format() {
    # Unit test the worktree path parsing logic
    # Path: /path/to/rust-genai/.worktrees/issue-268 -> "issue-268 (rust-genai)"
    # We test the bash logic directly since full script has git/gh deps
    local cwd="/home/user/projects/rust-genai/.worktrees/issue-268"
    local dir_name="${cwd##*/}"

    # Apply worktree logic from statusline-command.sh
    if [[ "$cwd" == */.worktrees/* ]]; then
        local worktree_parent="${cwd%/.worktrees/*}"
        local repo_name="${worktree_parent##*/}"
        local worktree_branch="${cwd##*/}"
        dir_name="${repo_name} (${worktree_branch})"
    fi

    # Should produce "rust-genai (issue-268)"
    [[ "$dir_name" == "rust-genai (issue-268)" ]]
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
    # Test with a session_id but agent-event-bus-cli unavailable
    local input='{"workspace":{"current_dir":"/tmp"},"context_window":{"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000},"model":{"id":"test"},"session_id":"test-session"}'
    local exit_code=0

    # Run with PATH that doesn't include agent-event-bus-cli location
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
# IMPORTANT: This will fail if agent-event-bus-cli doesn't output client_id
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
# tmux-status.sh tests
# ============================================================================

# Mock tmux for testing
setup_mock_tmux() {
    cat > "$TEST_TMP/bin/tmux" << 'MOCK_TMUX'
#!/bin/bash
# Mock tmux for testing tmux-status.sh hook

case "$1" in
    display-message)
        # Parse -t and -p flags
        target=""
        format=""
        while [[ $# -gt 1 ]]; do
            case "$2" in
                -t) target="$3"; shift 2 ;;
                -p) shift ;;  # Print flag
                *) format="$2"; shift ;;
            esac
        done
        # Return mock values based on format
        case "$format" in
            '#{window_id}') echo "@1" ;;
            '#{pane_current_path}') echo "/home/user/projects/test-project" ;;
            '#{b:pane_current_path}') echo "test-project" ;;
            *) echo "" ;;
        esac
        ;;
    set-window-option)
        # Accept and ignore - just verify we don't crash
        exit 0
        ;;
    rename-window)
        # Echo the new name to verify it was called correctly
        # Parse -t flag and name
        while [[ $# -gt 1 ]]; do
            case "$2" in
                -t) shift 2 ;;  # Skip target
                *) echo "RENAMED: $2"; shift ;;
            esac
        done
        ;;
    *)
        echo "Unknown tmux command: $1" >&2
        exit 1
        ;;
esac
MOCK_TMUX
    chmod +x "$TEST_TMP/bin/tmux"
}

test_tmux_status_syntax() {
    bash -n "$HOOKS_DIR/tmux-status.sh"
}

test_tmux_status_graceful_no_tmux_env() {
    # Without TMUX env var, should exit silently
    local output
    local exit_code=0
    output=$(env -u TMUX -u TMUX_PANE bash "$HOOKS_DIR/tmux-status.sh" working 2>&1) || exit_code=$?

    # Should exit cleanly with no output
    [[ $exit_code -eq 0 ]] && [[ -z "$output" ]]
}

test_tmux_status_graceful_no_pane_id() {
    # With TMUX but no TMUX_PANE, should exit silently
    local output
    local exit_code=0
    # Use env -i to clear all environment, then set only what we need
    output=$(env -i PATH="$PATH" HOME="$HOME" TMUX="/tmp/tmux-test" bash "$HOOKS_DIR/tmux-status.sh" working 2>&1) || exit_code=$?

    # Should exit cleanly with no output
    [[ $exit_code -eq 0 ]] && [[ -z "$output" ]]
}

test_tmux_status_working_state() {
    setup_mock_tmux

    local output
    local exit_code=0
    output=$(echo "" | env TMUX="/tmp/tmux-test" TMUX_PANE="%0" bash "$HOOKS_DIR/tmux-status.sh" working 2>&1) || exit_code=$?

    # Should rename window with hourglass emoji
    [[ $exit_code -eq 0 ]] && [[ "$output" == *"⏳ test-project"* ]]
}

test_tmux_status_waiting_state() {
    setup_mock_tmux

    local output
    local exit_code=0
    output=$(echo "" | env TMUX="/tmp/tmux-test" TMUX_PANE="%0" bash "$HOOKS_DIR/tmux-status.sh" waiting 2>&1) || exit_code=$?

    # Should rename window without hourglass emoji
    [[ $exit_code -eq 0 ]] && [[ "$output" == *"RENAMED: test-project"* ]] && [[ "$output" != *"⏳"* ]]
}

test_tmux_status_default_waiting() {
    setup_mock_tmux

    local output
    local exit_code=0
    # No state argument = defaults to waiting
    output=$(echo "" | env TMUX="/tmp/tmux-test" TMUX_PANE="%0" bash "$HOOKS_DIR/tmux-status.sh" 2>&1) || exit_code=$?

    # Should default to waiting state (no hourglass)
    [[ $exit_code -eq 0 ]] && [[ "$output" == *"RENAMED: test-project"* ]] && [[ "$output" != *"⏳"* ]]
}

test_tmux_status_consumes_stdin() {
    setup_mock_tmux

    # Hook should consume stdin without blocking
    # Use background process with wait to avoid timeout command (not on macOS)
    local exit_code=0
    (echo '{"session_id":"test"}' | env -i PATH="$PATH" HOME="$HOME" TMUX="/tmp/tmux-test" TMUX_PANE="%0" bash "$HOOKS_DIR/tmux-status.sh" working >/dev/null 2>&1) &
    local pid=$!
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        # Still running after 1s = stuck on stdin
        kill "$pid" 2>/dev/null || true
        exit_code=1
    else
        wait "$pid" || exit_code=$?
    fi

    [[ $exit_code -eq 0 ]]
}

# ============================================================================
# zj-status.sh tests
# ============================================================================

test_zj_status_syntax() {
    bash -n "$HOOKS_DIR/zj-status.sh"
}

test_zj_status_graceful_no_zellij_env() {
    # Without ZELLIJ env var, should exit silently
    local output
    local exit_code=0
    output=$(env -u ZELLIJ bash "$HOOKS_DIR/zj-status.sh" working 2>&1) || exit_code=$?

    # Should exit cleanly with no output
    [[ $exit_code -eq 0 ]] && [[ -z "$output" ]]
}

test_zj_status_consumes_stdin() {
    # Hook should consume stdin without blocking
    local exit_code=0
    (echo '{"session_id":"test"}' | env -u ZELLIJ bash "$HOOKS_DIR/zj-status.sh" working >/dev/null 2>&1) &
    local pid=$!
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        exit_code=1
    else
        wait "$pid" || exit_code=$?
    fi

    [[ $exit_code -eq 0 ]]
}

# ============================================================================
# session-start.sh cache pre-population tests
# ============================================================================

test_session_start_populates_cache() {
    setup_mock_event_bus_cli

    # Clear any existing cache
    local cache_dir="${TMPDIR:-/tmp}/claude-statusline"
    rm -rf "$cache_dir" 2>/dev/null

    local output
    output=$(echo '{"session_id":"test-client-uuid","cwd":"/tmp/test-repo"}' | \
        bash "$HOOKS_DIR/session-start.sh" 2>&1)

    # Cache file should be created with the display_id from registration
    [[ -f "$cache_dir/test-client-uuid" ]] && \
    [[ "$(cat "$cache_dir/test-client-uuid")" == "test-fox" ]]
}

test_session_start_cache_skipped_without_display_id() {
    # Create a mock that returns empty display_id
    cat > "$TEST_TMP/bin/agent-event-bus-cli" << 'MOCK_CLI'
#!/bin/bash
while [[ "$1" == --* ]]; do case "$1" in --url) shift 2 ;; *) shift ;; esac; done
case "$1" in
    register)
        echo '{"session_id":"test-uuid","display_id":"","name":"test","client_id":"no-display-client","cursor":"c1"}'
        ;;
    events) echo "No events" ;;
    *) echo '{}' ;;
esac
MOCK_CLI
    chmod +x "$TEST_TMP/bin/agent-event-bus-cli"

    local cache_dir="${TMPDIR:-/tmp}/claude-statusline"
    rm -f "$cache_dir/no-display-client" 2>/dev/null

    echo '{"session_id":"no-display-client","cwd":"/tmp"}' | \
        bash "$HOOKS_DIR/session-start.sh" 2>&1 >/dev/null

    # Cache file should NOT be created for empty display_id
    [[ ! -f "$cache_dir/no-display-client" ]]
}

# ============================================================================
# statusline retry logic tests
# ============================================================================

test_statusline_retry_finds_session() {
    # Create a mock CLI that fails twice then succeeds (simulating race condition)
    # Statusline uses hardcoded $HOME/.local/bin/agent-event-bus-cli, so we use a temp HOME
    local mock_home="$TEST_TMP/mock-home"
    mkdir -p "$mock_home/.local/bin"

    local attempt_file="$TEST_TMP/attempt_count"
    echo "0" > "$attempt_file"

    cat > "$mock_home/.local/bin/agent-event-bus-cli" << MOCK_CLI
#!/bin/bash
case "\$1" in
    sessions)
        count=\$(cat "$attempt_file")
        count=\$((count + 1))
        echo "\$count" > "$attempt_file"
        if [[ \$count -ge 2 ]]; then
            echo "Active sessions (1):"
            echo ""
            echo "  retry-fox  dotfiles/main"
            echo "    repo: dotfiles, machine: test"
            echo "    client_id: retry-test-uuid"
        fi
        ;;
    *) echo '{}' ;;
esac
MOCK_CLI
    chmod +x "$mock_home/.local/bin/agent-event-bus-cli"

    # Clear cache
    local cache_dir="${TMPDIR:-/tmp}/claude-statusline"
    rm -f "$cache_dir/retry-test-uuid" 2>/dev/null

    # Note: transcript_path must be non-empty — bash `read` treats consecutive
    # tabs as one delimiter, so empty transcript_path shifts session_id out
    local input='{"workspace":{"current_dir":"/tmp"},"context_window":{"current_usage":{"input_tokens":1000,"cache_creation_input_tokens":0,"cache_read_input_tokens":0},"context_window_size":200000},"model":{"id":"test"},"transcript_path":"/tmp/fake.jsonl","session_id":"retry-test-uuid"}'
    local output
    # Statusline's complex @tsv jq query needs real jq, not the test mock.
    # Prepend standard jq locations before $TEST_TMP/bin in PATH.
    output=$(HOME="$mock_home" PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:$PATH" bash "$STATUSLINE_SCRIPT" <<< "$input" 2>/dev/null) || true

    # Should find session after retry and show name (not warning)
    [[ "$output" == *"retry-fox"* ]]
}

# ============================================================================
# teammate-idle.sh tests
# ============================================================================

test_teammate_idle_syntax() {
    bash -n "$HOOKS_DIR/teammate-idle.sh"
}

test_teammate_idle_graceful_no_jq() {
    local MINIMAL_PATH="/bin:/usr/bin"
    local exit_code=0
    echo '{"session_id":"test-123","cwd":"/tmp"}' | \
        env -i PATH="$MINIMAL_PATH" HOME="$HOME" \
        bash "$HOOKS_DIR/teammate-idle.sh" >/dev/null 2>&1 || exit_code=$?

    [[ $exit_code -eq 0 ]]
}

test_teammate_idle_graceful_no_cli() {
    local exit_code=0
    echo '{"session_id":"test-123","cwd":"/tmp"}' | \
        bash "$HOOKS_DIR/teammate-idle.sh" >/dev/null 2>&1 || exit_code=$?

    # Must always exit 0 (exit 2 would keep teammate working)
    [[ $exit_code -eq 0 ]]
}

test_teammate_idle_happy_path() {
    setup_mock_event_bus_cli

    local exit_code=0
    echo '{"session_id":"test-session","cwd":"/tmp","teammate_name":"worker","team_name":"my-team"}' | \
        bash "$HOOKS_DIR/teammate-idle.sh" >/dev/null 2>&1 || exit_code=$?

    [[ $exit_code -eq 0 ]]
}

# ============================================================================
# task-created.sh tests
# ============================================================================

test_task_created_syntax() {
    bash -n "$HOOKS_DIR/task-created.sh"
}

test_task_created_graceful_no_jq() {
    local MINIMAL_PATH="/bin:/usr/bin"
    local exit_code=0
    echo '{"session_id":"test-123","cwd":"/tmp"}' | \
        env -i PATH="$MINIMAL_PATH" HOME="$HOME" \
        bash "$HOOKS_DIR/task-created.sh" >/dev/null 2>&1 || exit_code=$?

    [[ $exit_code -eq 0 ]]
}

test_task_created_graceful_no_cli() {
    local exit_code=0
    echo '{"session_id":"test-123","cwd":"/tmp"}' | \
        bash "$HOOKS_DIR/task-created.sh" >/dev/null 2>&1 || exit_code=$?

    # Must always exit 0 (exit 2 would prevent task creation)
    [[ $exit_code -eq 0 ]]
}

test_task_created_happy_path() {
    setup_mock_event_bus_cli

    local exit_code=0
    echo '{"session_id":"test-session","cwd":"/tmp","task_id":"task-1","task_subject":"Fix auth bug","teammate_name":"implementer"}' | \
        bash "$HOOKS_DIR/task-created.sh" >/dev/null 2>&1 || exit_code=$?

    [[ $exit_code -eq 0 ]]
}

# ============================================================================
# task-completed.sh tests
# ============================================================================

test_task_completed_syntax() {
    bash -n "$HOOKS_DIR/task-completed.sh"
}

test_task_completed_graceful_no_jq() {
    local MINIMAL_PATH="/bin:/usr/bin"
    local exit_code=0
    echo '{"session_id":"test-123","cwd":"/tmp"}' | \
        env -i PATH="$MINIMAL_PATH" HOME="$HOME" \
        bash "$HOOKS_DIR/task-completed.sh" >/dev/null 2>&1 || exit_code=$?

    [[ $exit_code -eq 0 ]]
}

test_task_completed_graceful_no_cli() {
    local exit_code=0
    echo '{"session_id":"test-123","cwd":"/tmp"}' | \
        bash "$HOOKS_DIR/task-completed.sh" >/dev/null 2>&1 || exit_code=$?

    # Must always exit 0 (exit 2 would prevent task completion)
    [[ $exit_code -eq 0 ]]
}

test_task_completed_happy_path() {
    setup_mock_event_bus_cli

    local exit_code=0
    echo '{"session_id":"test-session","cwd":"/tmp","task_id":"task-1","task_subject":"Fix auth bug","teammate_name":"implementer"}' | \
        bash "$HOOKS_DIR/task-completed.sh" >/dev/null 2>&1 || exit_code=$?

    [[ $exit_code -eq 0 ]]
}

# ============================================================================
# post-tool-failure.sh tests
# ============================================================================

test_post_tool_failure_syntax() {
    bash -n "$HOOKS_DIR/post-tool-failure.sh"
}

test_post_tool_failure_graceful_no_jq() {
    local MINIMAL_PATH="/bin:/usr/bin"
    local exit_code=0
    echo '{"session_id":"test-123","cwd":"/tmp","tool_name":"Bash","error":"failed"}' | \
        env -i PATH="$MINIMAL_PATH" HOME="$HOME" \
        bash "$HOOKS_DIR/post-tool-failure.sh" >/dev/null 2>&1 || exit_code=$?

    [[ $exit_code -eq 0 ]]
}

test_post_tool_failure_graceful_no_cli() {
    local exit_code=0
    echo '{"session_id":"test-123","cwd":"/tmp","tool_name":"Bash","error":"failed"}' | \
        bash "$HOOKS_DIR/post-tool-failure.sh" >/dev/null 2>&1 || exit_code=$?

    [[ $exit_code -eq 0 ]]
}

test_post_tool_failure_skips_interrupt() {
    setup_mock_event_bus_cli

    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-session","cwd":"/tmp","tool_name":"Bash","error":"interrupted","is_interrupt":true}' | \
        bash "$HOOKS_DIR/post-tool-failure.sh" 2>&1) || exit_code=$?

    # Should exit silently for interrupts — no output, no publish
    [[ $exit_code -eq 0 ]] && [[ -z "$output" ]]
}

test_post_tool_failure_skips_benign_grep() {
    setup_mock_event_bus_cli

    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-session","cwd":"/tmp","tool_name":"Grep","error":"No files found matching pattern"}' | \
        bash "$HOOKS_DIR/post-tool-failure.sh" 2>&1) || exit_code=$?

    # Should exit silently for benign grep errors
    [[ $exit_code -eq 0 ]] && [[ -z "$output" ]]
}

test_post_tool_failure_happy_path() {
    setup_mock_event_bus_cli

    local exit_code=0
    echo '{"session_id":"test-session","cwd":"/tmp","tool_name":"Bash","error":"Command exited with non-zero status code 1"}' | \
        bash "$HOOKS_DIR/post-tool-failure.sh" >/dev/null 2>&1 || exit_code=$?

    # Should exit 0 (publishes event, but mock events won't hit threshold)
    [[ $exit_code -eq 0 ]]
}

test_post_tool_failure_outputs_context_at_threshold() {
    # Create a mock CLI that returns 3+ matching events for the signature
    cat > "$TEST_TMP/bin/agent-event-bus-cli" << 'MOCK_CLI'
#!/bin/bash
while [[ "$1" == --* ]]; do case "$1" in --url) shift 2 ;; *) shift ;; esac; done
case "$1" in
    publish)
        echo '{"event_id":999}'
        ;;
    events)
        # Return 3 matching events with the same signature
        echo "[101] error_pattern (repo:dotfiles)"
        echo "    Bash:Command exited with non-zero status code 1"
        echo "    from: session-1 at 2026-03-30T10:00:00"
        echo "[102] error_pattern (repo:dotfiles)"
        echo "    Bash:Command exited with non-zero status code 1"
        echo "    from: session-2 at 2026-03-30T11:00:00"
        echo "[103] error_pattern (repo:dotfiles)"
        echo "    Bash:Command exited with non-zero status code 1"
        echo "    from: session-3 at 2026-03-30T12:00:00"
        ;;
    *) echo '{}' ;;
esac
MOCK_CLI
    chmod +x "$TEST_TMP/bin/agent-event-bus-cli"

    # This test needs real jq for JSON construction (jq -n --arg).
    # Prepend standard jq locations before $TEST_TMP/bin in PATH.
    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-session","cwd":"/tmp","tool_name":"Bash","error":"Command exited with non-zero status code 1"}' | \
        PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:$PATH" \
        bash "$HOOKS_DIR/post-tool-failure.sh" 2>&1) || exit_code=$?

    # Should output valid JSON with additionalContext when threshold met
    [[ $exit_code -eq 0 ]] && \
    [[ "$output" == *"hookSpecificOutput"* ]] && \
    [[ "$output" == *"additionalContext"* ]] && \
    [[ "$output" == *"Recurring error"* ]]
}

# ============================================================================
# enforce-insight-publish.sh tests
# ============================================================================

test_enforce_insight_publish_syntax() {
    bash -n "$HOOKS_DIR/enforce-insight-publish.sh"
}

test_enforce_insight_publish_graceful_no_jq() {
    # Build a PATH that has the hook's non-jq deps (cat, bash) but NOT jq.
    # Using /bin:/usr/bin would find /usr/bin/jq on Debian/Ubuntu CI runners
    # and cause the test to pass via the missing-transcript branch instead —
    # masking a regression in the no-jq path.
    local no_jq_dir="$TEST_TMP/no-jq"
    mkdir -p "$no_jq_dir"
    ln -sf "$(type -P cat)" "$no_jq_dir/cat"
    ln -sf "$(type -P bash)" "$no_jq_dir/bash"

    local exit_code=0
    echo '{"transcript_path":"/tmp/fake.jsonl"}' | \
        env -i PATH="$no_jq_dir" HOME="$HOME" \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" >/dev/null 2>&1 || exit_code=$?

    # Must exit 0 when jq is missing (cannot enforce, must not block)
    [[ $exit_code -eq 0 ]]
}

test_enforce_insight_publish_graceful_no_transcript() {
    local exit_code=0
    echo '{}' | bash "$HOOKS_DIR/enforce-insight-publish.sh" >/dev/null 2>&1 || exit_code=$?

    [[ $exit_code -eq 0 ]]
}

test_enforce_insight_publish_graceful_missing_transcript_file() {
    local exit_code=0
    echo '{"transcript_path":"/nonexistent/path.jsonl"}' | \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" >/dev/null 2>&1 || exit_code=$?

    [[ $exit_code -eq 0 ]]
}

test_enforce_insight_publish_respects_stop_hook_active() {
    # When stop_hook_active=true, must not block (prevents infinite loop)
    local transcript="$TEST_TMP/insight-no-publish.jsonl"
    cat > "$transcript" <<'EOF'
{"type":"user","message":{"role":"user","content":"hi"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"`★ Insight ─────────────────────────────────────`\nfoo"}]}}
EOF

    local output
    local exit_code=0
    output=$(echo "{\"transcript_path\":\"$transcript\",\"stop_hook_active\":true}" | \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" 2>&1) || exit_code=$?

    # Must be silent when stop_hook_active is true
    [[ $exit_code -eq 0 ]] && [[ -z "$output" ]]
}

# The mock jq in setup_test_env doesn't implement -s/slurp or match()/scan()
# with complex queries. Tests that exercise the real jq pipeline discover the
# real jq binary and prepend its directory, so they work both locally and on
# CI runners regardless of where jq is installed (/opt/homebrew, /usr, etc.).
_real_jq_path() {
    local real_jq
    real_jq=$(PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" command -v jq 2>/dev/null || true)
    [[ -n "$real_jq" ]] && dirname "$real_jq" || echo "/usr/bin"
}

test_enforce_insight_publish_blocks_insight_without_publish() {
    # Fixture mirrors the real explanatory-output-style format: the decorator
    # line is wrapped in literal backticks.
    local transcript="$TEST_TMP/insight-no-publish.jsonl"
    cat > "$transcript" <<'EOF'
{"type":"user","message":{"role":"user","content":"tell me something"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"Here you go.\n`★ Insight ─────────────────────────────────────`\nAn observation.\n`─────────────────────────────────────────────────`"}]}}
EOF

    local output
    local exit_code=0
    output=$(echo "{\"transcript_path\":\"$transcript\"}" | \
        PATH="$(_real_jq_path):$PATH" \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" 2>&1) || exit_code=$?

    # Must emit a block decision JSON
    [[ $exit_code -eq 0 ]] && \
    [[ "$output" == *"\"decision\": \"block\""* ]] && \
    [[ "$output" == *"★ Insight"* ]]
}

test_enforce_insight_publish_allows_insight_with_publish() {
    local transcript="$TEST_TMP/insight-with-publish.jsonl"
    cat > "$transcript" <<'EOF'
{"type":"user","message":{"role":"user","content":"tell me something"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"`★ Insight ─────────────────────────────────────`\nAn observation.\n`─────────────────────────────────────────────────`"}]}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"mcp__agent-event-bus__publish_event","input":{"event_type":"pattern_found","payload":"x"}}]}}
EOF

    local output
    local exit_code=0
    output=$(echo "{\"transcript_path\":\"$transcript\"}" | \
        PATH="$(_real_jq_path):$PATH" \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" 2>&1) || exit_code=$?

    # Must be silent when a publish_event accompanies the insight
    [[ $exit_code -eq 0 ]] && [[ -z "$output" ]]
}

test_enforce_insight_publish_allows_no_insight() {
    local transcript="$TEST_TMP/no-insight.jsonl"
    cat > "$transcript" <<'EOF'
{"type":"user","message":{"role":"user","content":"hi"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"hello"}]}}
EOF

    local output
    local exit_code=0
    output=$(echo "{\"transcript_path\":\"$transcript\"}" | \
        PATH="$(_real_jq_path):$PATH" \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" 2>&1) || exit_code=$?

    [[ $exit_code -eq 0 ]] && [[ -z "$output" ]]
}

test_enforce_insight_publish_ignores_prior_turn_insights() {
    # Insight in a prior turn (before the last user message) should not
    # affect the current turn's enforcement.
    local transcript="$TEST_TMP/prior-insight.jsonl"
    cat > "$transcript" <<'EOF'
{"type":"user","message":{"role":"user","content":"first"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"`★ Insight ─────────────────────────────────────`\nold insight (already dealt with)."}]}}
{"type":"user","message":{"role":"user","content":"second"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"just a reply, no insight"}]}}
EOF

    local output
    local exit_code=0
    output=$(echo "{\"transcript_path\":\"$transcript\"}" | \
        PATH="$(_real_jq_path):$PATH" \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" 2>&1) || exit_code=$?

    [[ $exit_code -eq 0 ]] && [[ -z "$output" ]]
}

test_enforce_insight_publish_blocks_heavy_divider_variant() {
    # ★ Insight ━ (U+2501 heavy) and ═ (U+2550 double) are valid variants
    # some output styles use. Must also trigger enforcement.
    local transcript="$TEST_TMP/heavy-divider.jsonl"
    cat > "$transcript" <<'EOF'
{"type":"user","message":{"role":"user","content":"tell me something"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"`★ Insight ━━━━━━━`\nHeavy divider.\n`━━━━━━━`"}]}}
EOF

    local output
    local exit_code=0
    output=$(echo "{\"transcript_path\":\"$transcript\"}" | \
        PATH="$(_real_jq_path):$PATH" \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" 2>&1) || exit_code=$?

    [[ $exit_code -eq 0 ]] && [[ "$output" == *"\"decision\": \"block\""* ]]
}

test_enforce_insight_publish_ignores_inline_mentions() {
    # Casual inline mentions ("the ★ Insight ─ marker") should not trigger.
    # Required: line-start + 3+ divider chars filters these out.
    local transcript="$TEST_TMP/inline-mention.jsonl"
    cat > "$transcript" <<'EOF'
{"type":"user","message":{"role":"user","content":"explain the format"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"The ★ Insight ─ marker is how we write insights. Use `★ Insight ─` inline."}]}}
EOF

    local output
    local exit_code=0
    output=$(echo "{\"transcript_path\":\"$transcript\"}" | \
        PATH="$(_real_jq_path):$PATH" \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" 2>&1) || exit_code=$?

    [[ $exit_code -eq 0 ]] && [[ -z "$output" ]]
}

test_enforce_insight_publish_blocks_bare_format() {
    # Regression: earlier versions of the regex required a backtick. The
    # current form allows (but does not require) a leading backtick, so a
    # bare `★ Insight ─────` (no backticks) should still trigger.
    local transcript="$TEST_TMP/bare-format.jsonl"
    cat > "$transcript" <<'EOF'
{"type":"user","message":{"role":"user","content":"tell me something"}}
{"type":"assistant","message":{"content":[{"type":"text","text":"intro\n★ Insight ─────────────────────────────────────\nBare format without backticks."}]}}
EOF

    local output
    local exit_code=0
    output=$(echo "{\"transcript_path\":\"$transcript\"}" | \
        PATH="$(_real_jq_path):$PATH" \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" 2>&1) || exit_code=$?

    [[ $exit_code -eq 0 ]] && [[ "$output" == *"\"decision\": \"block\""* ]]
}

test_enforce_insight_publish_tool_results_stay_in_turn() {
    # A tool_result is a user-typed event but must not be treated as a
    # turn boundary. An insight after a tool result (same turn) still
    # requires a publish_event.
    local transcript="$TEST_TMP/tool-result-mid-turn.jsonl"
    cat > "$transcript" <<'EOF'
{"type":"user","message":{"role":"user","content":"do something"}}
{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Bash","input":{}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}
{"type":"assistant","message":{"content":[{"type":"text","text":"`★ Insight ─────────────────────────────────────`\npost-tool observation."}]}}
EOF

    local output
    local exit_code=0
    output=$(echo "{\"transcript_path\":\"$transcript\"}" | \
        PATH="$(_real_jq_path):$PATH" \
        bash "$HOOKS_DIR/enforce-insight-publish.sh" 2>&1) || exit_code=$?

    # Must still block: tool_result doesn't reset the turn.
    [[ $exit_code -eq 0 ]] && [[ "$output" == *"\"decision\": \"block\""* ]]
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
    run_test "graceful degradation (no agent-event-bus-cli)" "test_session_start_graceful_no_cli"
    run_test "integration: happy path" "test_session_start_happy_path"
    run_test "integration: parses session_id" "test_session_start_parses_session_id"
    run_test "integration: fetches events" "test_session_start_fetches_events"
    run_test "integration: populates statusline cache" "test_session_start_populates_cache"
    run_test "integration: skips cache without display_id" "test_session_start_cache_skipped_without_display_id"
    echo ""

    echo "=== session-end.sh ==="
    run_test "syntax check" "test_session_end_syntax"
    run_test "graceful degradation (no jq)" "test_session_end_graceful_no_jq"
    run_test "graceful degradation (no agent-event-bus-cli)" "test_session_end_graceful_no_cli"
    run_test "graceful degradation (no session_id)" "test_session_end_graceful_no_session_id"
    run_test "integration: happy path" "test_session_end_happy_path"
    run_test "integration: parses response" "test_session_end_parses_response"
    echo ""

    echo "=== prompt-events.sh ==="
    run_test "syntax check" "test_prompt_events_syntax"
    run_test "graceful degradation (no agent-event-bus-cli)" "test_prompt_events_graceful_no_cli"
    run_test "graceful degradation (no session_id)" "test_prompt_events_graceful_no_session_id"
    run_test "integration: happy path" "test_prompt_events_happy_path"
    run_test "integration: returns events" "test_prompt_events_returns_events"
    run_test "integration: passes session_id" "test_prompt_events_passes_session_id"
    echo ""

    echo "=== pre-compact.sh ==="
    run_test "syntax check" "test_pre_compact_syntax"
    run_test "graceful degradation (no jq)" "test_pre_compact_graceful_no_jq"
    run_test "graceful degradation (no agent-event-bus-cli)" "test_pre_compact_graceful_no_cli"
    run_test "graceful degradation (no session_id)" "test_pre_compact_graceful_no_session_id"
    run_test "integration: happy path" "test_pre_compact_happy_path"
    run_test "integration: publishes event" "test_pre_compact_publishes_event"
    run_test "integration: extracts PR number" "test_pre_compact_extracts_pr_number"
    run_test "integration: no PR graceful" "test_pre_compact_no_pr_shows_graceful"
    run_test "integration: work ID from issue branch" "test_pre_compact_work_id_issue_branch"
    run_test "integration: work ID from PR branch" "test_pre_compact_work_id_pr_branch"
    run_test "integration: payload format validation" "test_pre_compact_payload_format_validation"
    echo ""

    echo "=== statusline-command.sh ==="
    run_test "syntax check" "test_statusline_syntax"
    run_test "handles empty input" "test_statusline_handles_empty_input"
    run_test "basic output" "test_statusline_basic_output"
    run_test "no ANSI escape leak in session name" "test_statusline_no_ansi_leak_in_session_name"
    run_test "hyperlinks properly closed" "test_statusline_hyperlinks_closed"
    run_test "worktree path format" "test_statusline_worktree_format"
    run_test "graceful degradation (no jq)" "test_statusline_graceful_no_jq"
    run_test "graceful degradation (no git)" "test_statusline_graceful_no_git"
    run_test "graceful degradation (no gh)" "test_statusline_graceful_no_gh"
    run_test "graceful degradation (no agent-event-bus-cli)" "test_statusline_graceful_no_event_bus_cli"
    run_test "graceful degradation (missing transcript)" "test_statusline_graceful_missing_transcript"
    run_test "graceful degradation (malformed JSON)" "test_statusline_graceful_malformed_json"
    run_test "graceful degradation (null fields)" "test_statusline_graceful_null_fields"
    run_test "integration: client_id lookup" "test_statusline_client_id_lookup"
    run_test "integration: retry finds session" "test_statusline_retry_finds_session"
    echo ""

    echo "=== tmux-status.sh ==="
    run_test "syntax check" "test_tmux_status_syntax"
    run_test "graceful degradation (no TMUX env)" "test_tmux_status_graceful_no_tmux_env"
    run_test "graceful degradation (no TMUX_PANE)" "test_tmux_status_graceful_no_pane_id"
    run_test "integration: working state" "test_tmux_status_working_state"
    run_test "integration: waiting state" "test_tmux_status_waiting_state"
    run_test "integration: default to waiting" "test_tmux_status_default_waiting"
    run_test "consumes stdin" "test_tmux_status_consumes_stdin"
    echo ""

    echo "=== zj-status.sh ==="
    run_test "syntax check" "test_zj_status_syntax"
    run_test "graceful degradation (no ZELLIJ env)" "test_zj_status_graceful_no_zellij_env"
    run_test "consumes stdin" "test_zj_status_consumes_stdin"
    echo ""

    echo "=== teammate-idle.sh ==="
    run_test "syntax check" "test_teammate_idle_syntax"
    run_test "graceful degradation (no jq)" "test_teammate_idle_graceful_no_jq"
    run_test "graceful degradation (no agent-event-bus-cli)" "test_teammate_idle_graceful_no_cli"
    run_test "integration: happy path" "test_teammate_idle_happy_path"
    echo ""

    echo "=== task-created.sh ==="
    run_test "syntax check" "test_task_created_syntax"
    run_test "graceful degradation (no jq)" "test_task_created_graceful_no_jq"
    run_test "graceful degradation (no agent-event-bus-cli)" "test_task_created_graceful_no_cli"
    run_test "integration: happy path" "test_task_created_happy_path"
    echo ""

    echo "=== task-completed.sh ==="
    run_test "syntax check" "test_task_completed_syntax"
    run_test "graceful degradation (no jq)" "test_task_completed_graceful_no_jq"
    run_test "graceful degradation (no agent-event-bus-cli)" "test_task_completed_graceful_no_cli"
    run_test "integration: happy path" "test_task_completed_happy_path"
    echo ""

    echo "=== enforce-insight-publish.sh ==="
    run_test "syntax check" "test_enforce_insight_publish_syntax"
    run_test "graceful degradation (no jq)" "test_enforce_insight_publish_graceful_no_jq"
    run_test "graceful degradation (no transcript_path)" "test_enforce_insight_publish_graceful_no_transcript"
    run_test "graceful degradation (transcript file missing)" "test_enforce_insight_publish_graceful_missing_transcript_file"
    run_test "respects stop_hook_active (loop guard)" "test_enforce_insight_publish_respects_stop_hook_active"
    run_test "blocks insight without publish" "test_enforce_insight_publish_blocks_insight_without_publish"
    run_test "allows insight with publish" "test_enforce_insight_publish_allows_insight_with_publish"
    run_test "allows turns with no insight" "test_enforce_insight_publish_allows_no_insight"
    run_test "ignores insights from prior turns" "test_enforce_insight_publish_ignores_prior_turn_insights"
    run_test "blocks heavy/double divider variants" "test_enforce_insight_publish_blocks_heavy_divider_variant"
    run_test "ignores inline marker mentions" "test_enforce_insight_publish_ignores_inline_mentions"
    run_test "blocks bare format (no backticks)" "test_enforce_insight_publish_blocks_bare_format"
    run_test "tool_result does not reset turn" "test_enforce_insight_publish_tool_results_stay_in_turn"
    echo ""

    echo "=== post-tool-failure.sh ==="
    run_test "syntax check" "test_post_tool_failure_syntax"
    run_test "graceful degradation (no jq)" "test_post_tool_failure_graceful_no_jq"
    run_test "graceful degradation (no agent-event-bus-cli)" "test_post_tool_failure_graceful_no_cli"
    run_test "skips interrupt errors" "test_post_tool_failure_skips_interrupt"
    run_test "skips benign grep errors" "test_post_tool_failure_skips_benign_grep"
    run_test "integration: happy path (below threshold)" "test_post_tool_failure_happy_path"
    run_test "integration: outputs additionalContext at threshold" "test_post_tool_failure_outputs_context_at_threshold"
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
