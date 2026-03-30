# Auto-Create Error Memories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically detect recurring tool errors via event bus and surface them to Claude in real-time, plus auto-create memory entries from cross-session error patterns.

**Architecture:** PostToolUseFailure hook publishes error_pattern events to event bus, queries for recurring matches, and injects additionalContext when threshold (3) is met. improve-workflow agent enhancement auto-creates feedback memory files from session analytics error data.

**Tech Stack:** Bash (hooks), Markdown (agent/docs), event bus CLI, session analytics MCP

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `home/.claude/hooks/post-tool-failure.sh` | PostToolUseFailure hook: publish errors, detect patterns, inject context |
| Modify | `home/.claude/settings.json:98` | Wire PostToolUseFailure hook event |
| Modify | `home/.claude/agents/improve-workflow.md:50` | Add Phase 2b: auto-create error memories |
| Modify | `home/.claude/hooks/README.md` | Lifecycle diagram + hook details |
| Modify | `docs/agent-teams-setup.md:39` | Add PostToolUseFailure to hooks table |
| Modify | `tests/test-hooks.sh` | Tests for post-tool-failure.sh |

---

### Task 1: PostToolUseFailure Hook — Core Script

**Files:**
- Create: `home/.claude/hooks/post-tool-failure.sh`

- [ ] **Step 1: Create the hook script**

```bash
#!/bin/bash
# PostToolUseFailure hook: Detects recurring error patterns via event bus
#
# Input (via stdin): JSON with session_id, cwd, tool_name, tool_input, error, is_interrupt
# Output: JSON with additionalContext when recurring pattern detected (≥3 in 24h)
#
# Uses event bus as a cross-session error tally. Publishes error_pattern events,
# then queries for matches. If threshold met, injects context back to Claude.

set -euo pipefail

# Source user's environment for AGENT_EVENT_BUS_URL
[[ -f ~/.extra ]] && source ~/.extra

# Read input (must consume stdin before any exit)
INPUT=$(cat)

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    exit 0
fi

if ! command -v agent-event-bus-cli &>/dev/null; then
    exit 0
fi

# Parse input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
ERROR=$(echo "$INPUT" | jq -r '.error // ""')
IS_INTERRUPT=$(echo "$INPUT" | jq -r '.is_interrupt // false')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

[[ -z "$SESSION_ID" ]] && exit 0
[[ -z "$TOOL_NAME" ]] && exit 0
[[ -z "$ERROR" ]] && exit 0
[[ -z "$CWD" ]] && CWD="$PWD"

# Skip benign errors
[[ "$IS_INTERRUPT" == "true" ]] && exit 0

# Skip expected exploration errors
case "$TOOL_NAME:$ERROR" in
    Grep:*"No files found"*|Grep:*"No matches"*) exit 0 ;;
    Glob:*"No files found"*|Glob:*"No matches"*) exit 0 ;;
    Read:*"does not exist"*|Read:*"No such file"*) exit 0 ;;
esac

# Build URL args if AGENT_EVENT_BUS_URL is set
URL_ARGS=()
[[ -n "${AGENT_EVENT_BUS_URL:-}" ]] && URL_ARGS=(--url "$AGENT_EVENT_BUS_URL")

# Derive repo name
REPO_NAME=""
if command -v git &>/dev/null && git -C "$CWD" rev-parse --git-dir &>/dev/null; then
    GIT_COMMON=$(git -C "$CWD" rev-parse --git-common-dir 2>/dev/null || echo "")
    if [[ -n "$GIT_COMMON" ]]; then
        REPO_NAME=$(basename "$(dirname "$GIT_COMMON")")
    else
        REPO_NAME=$(basename "$CWD")
    fi
else
    REPO_NAME=$(basename "$CWD")
fi

# Build pattern signature: tool_name + first 80 chars of error
ERROR_PREFIX="${ERROR:0:80}"
SIGNATURE="${TOOL_NAME}:${ERROR_PREFIX}"

# Publish error_pattern event to event bus
agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} publish \
    --type "error_pattern" \
    --payload "$SIGNATURE" \
    --session-id "$SESSION_ID" \
    --channel "repo:${REPO_NAME}" \
    2>/dev/null || true

# Query event bus for matching error_pattern events in last 24h
EVENTS=$(agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} events \
    --session-id "$SESSION_ID" \
    --include "error_pattern" \
    --limit 50 \
    --timeout 200 \
    2>/dev/null) || true

# Count matches for this signature
MATCH_COUNT=0
if [[ -n "$EVENTS" && "$EVENTS" != "No events" && "$EVENTS" != "No new events" ]]; then
    MATCH_COUNT=$(echo "$EVENTS" | grep -cF "$SIGNATURE" || true)
fi

# If threshold met, inject additionalContext
THRESHOLD=3
if [[ "$MATCH_COUNT" -ge "$THRESHOLD" ]]; then
    # Output JSON that Claude Code reads as additionalContext
    cat <<CONTEXT_JSON
{
  "hookSpecificOutput": {
    "additionalContext": "⚠️ Recurring error (${MATCH_COUNT} occurrences in recent sessions): ${TOOL_NAME} — ${ERROR_PREFIX}. This pattern keeps happening. Consider investigating the root cause or creating a memory entry to prevent it."
  }
}
CONTEXT_JSON
fi
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x home/.claude/hooks/post-tool-failure.sh
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n home/.claude/hooks/post-tool-failure.sh`
Expected: No output (clean syntax)

- [ ] **Step 4: Commit**

```bash
git add home/.claude/hooks/post-tool-failure.sh
git commit -m "feat: Add PostToolUseFailure hook for recurring error detection"
```

---

### Task 2: Wire Hook into Settings.json

**Files:**
- Modify: `home/.claude/settings.json:98`

- [ ] **Step 1: Add PostToolUseFailure hook event**

In `home/.claude/settings.json`, after the `TaskCompleted` hook block (line 98, before the closing `]`), add:

```json
    "PostToolUseFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/post-tool-failure.sh"
          }
        ]
      }
    ]
```

Note: This goes after the `TaskCompleted` entry's closing `]` — add a comma after that `]` and then the new block, before the closing `}` of the `hooks` object.

- [ ] **Step 2: Validate JSON**

Run: `jq . home/.claude/settings.json > /dev/null`
Expected: No output (valid JSON)

- [ ] **Step 3: Commit**

```bash
git add home/.claude/settings.json
git commit -m "feat: Wire PostToolUseFailure hook in settings.json"
```

---

### Task 3: Enhance improve-workflow Agent

**Files:**
- Modify: `home/.claude/agents/improve-workflow.md:50`

- [ ] **Step 1: Add Phase 2b after existing Phase 2 Error Patterns section**

In `home/.claude/agents/improve-workflow.md`, after the "Error Patterns" section in Phase 2 (after line ~50 `Focus on: what specific commands/hooks/scripts are failing? Are they fixable?`), add:

```markdown
### Auto-Create Error Memories

Only if error analysis found recurring patterns (3+ occurrences of the same tool+error):

```
mcp__agent-session-analytics__get_error_details(days=7, limit=20)
```

For each error pattern with 3+ occurrences across sessions:

1. Check if MEMORY.md already has a memory covering this error (search for tool name + error substring)
2. If not already covered, create a `feedback` memory file:

   ```markdown
   ---
   name: <tool-name>-<error-slug>
   description: <one-line description of recurring error pattern>
   type: feedback
   ---

   <Tool name> frequently fails with: <error description>

   **Why:** Occurred <N> times across sessions in the last 7 days.
   **How to apply:** <Suggested fix or avoidance strategy based on error context>
   ```

3. Add entry to MEMORY.md index
4. Publish `gotcha_discovered` to event bus with memory details

**Cap:** Create at most 3 error memories per invocation. Prioritize by occurrence count.

**Skip if:** Error rate is ≤ 5% (Phase 2 already gates this).
```

- [ ] **Step 2: Verify the markdown renders correctly**

Run: `head -70 home/.claude/agents/improve-workflow.md`
Expected: Phase 2b appears after Phase 2's Error Patterns section, before Phase 3.

- [ ] **Step 3: Commit**

```bash
git add home/.claude/agents/improve-workflow.md
git commit -m "feat: Add auto-create error memories to improve-workflow agent"
```

---

### Task 4: Hook Tests

**Files:**
- Modify: `tests/test-hooks.sh`

- [ ] **Step 1: Add test functions before the `# Run all tests` section**

```bash
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
    # Create a mock that returns 3+ matching events for the signature
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

    local output
    local exit_code=0
    output=$(echo '{"session_id":"test-session","cwd":"/tmp","tool_name":"Bash","error":"Command exited with non-zero status code 1"}' | \
        bash "$HOOKS_DIR/post-tool-failure.sh" 2>&1) || exit_code=$?

    # Should output additionalContext JSON when threshold met
    [[ $exit_code -eq 0 ]] && \
    [[ "$output" == *"hookSpecificOutput"* ]] && \
    [[ "$output" == *"additionalContext"* ]] && \
    [[ "$output" == *"Recurring error"* ]]
}
```

- [ ] **Step 2: Add test runner entries in `main()` function**

After the `task-completed.sh` test section, before `# Summary`:

```bash
    echo "=== post-tool-failure.sh ==="
    run_test "syntax check" "test_post_tool_failure_syntax"
    run_test "graceful degradation (no jq)" "test_post_tool_failure_graceful_no_jq"
    run_test "graceful degradation (no agent-event-bus-cli)" "test_post_tool_failure_graceful_no_cli"
    run_test "skips interrupt errors" "test_post_tool_failure_skips_interrupt"
    run_test "skips benign grep errors" "test_post_tool_failure_skips_benign_grep"
    run_test "integration: happy path (below threshold)" "test_post_tool_failure_happy_path"
    run_test "integration: outputs additionalContext at threshold" "test_post_tool_failure_outputs_context_at_threshold"
    echo ""
```

- [ ] **Step 3: Run tests**

Run: `make test-hooks`
Expected: All tests pass including 7 new post-tool-failure tests (75 total)

- [ ] **Step 4: Commit**

```bash
git add tests/test-hooks.sh
git commit -m "test: Add tests for PostToolUseFailure hook"
```

---

### Task 5: Documentation Updates

**Files:**
- Modify: `home/.claude/hooks/README.md`
- Modify: `docs/agent-teams-setup.md`

- [ ] **Step 1: Update hooks/README.md lifecycle diagram**

In the lifecycle diagram, after the `TaskCompleted` hook block and before the `Stop` hook, add:

```
│      │                              │
│      ├── PostToolUseFailure hook    │
│      │   - post-tool-failure.sh     │
│      │   (detects recurring errors) │
```

- [ ] **Step 2: Add hook detail section**

After the `task-completed.sh` detail section and before `## Writing Hooks`, add:

```markdown
---

### post-tool-failure.sh
**Trigger:** `PostToolUseFailure`

**Purpose:** Detect recurring tool error patterns via event bus and inject context back to Claude.

**Actions:**
1. Skip benign errors (interrupts, expected exploration failures)
2. Build pattern signature from tool name + error prefix (80 chars)
3. Publish `error_pattern` event to event bus on `repo:<name>` channel
4. Query event bus for matching recent events
5. If ≥3 matches: output JSON with `additionalContext` for Claude

**Input JSON fields:** `session_id`, `cwd`, `tool_name`, `tool_input`, `error`, `is_interrupt`

**Output:** JSON with `hookSpecificOutput.additionalContext` when recurring pattern detected. Silent otherwise.

**Exit code:** Always 0. Uses `additionalContext` for feedback, not exit codes.
```

- [ ] **Step 3: Update README configuration example**

In the `## Configuration` section's JSON example at the bottom of README.md, add after the `TaskCompleted` line:

```json
    "PostToolUseFailure": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/post-tool-failure.sh" }] }]
```

- [ ] **Step 4: Update docs/agent-teams-setup.md hooks table**

In the hooks table (around line 39), add a new row:

```markdown
| `PostToolUseFailure` | `post-tool-failure.sh` | `error_pattern` | Exit 2 = block (unused) |
```

- [ ] **Step 5: Commit**

```bash
git add home/.claude/hooks/README.md docs/agent-teams-setup.md
git commit -m "docs: Add PostToolUseFailure hook to README and porting guide"
```

---

### Task 6: Quality Gates & Final Verification

- [ ] **Step 1: Run all quality gates**

Run: `make check`
Expected: All lint, test, hooks, and bootstrap checks pass

- [ ] **Step 2: Verify JSON output format manually**

Run:
```bash
echo '{"session_id":"test","cwd":"/tmp","tool_name":"Bash","error":"test error"}' | \
  bash home/.claude/hooks/post-tool-failure.sh 2>/dev/null | jq .
```
Expected: Either empty (below threshold) or valid JSON with `hookSpecificOutput.additionalContext`

- [ ] **Step 3: Final commit if any fixups needed**

```bash
git add -A
git commit -m "fix: Address quality gate findings"
```
