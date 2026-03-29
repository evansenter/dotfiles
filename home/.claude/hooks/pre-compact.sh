#!/bin/bash
# Pre-compaction hook: Checkpoints WIP state before context summarization
#
# Input (via stdin): JSON with session_id, transcript_path, cwd, trigger
# Output: Text confirmation (does not affect compaction behavior)
#
# Stores WIP state to event bus so it can be restored after compaction.

set -euo pipefail

# Source user's environment for AGENT_EVENT_BUS_URL
[[ -f ~/.extra ]] && source ~/.extra

# Read and parse session info
INPUT=$(cat)

# Check for required dependencies
if ! command -v jq &>/dev/null; then
    echo "WIP checkpoint skipped (jq not installed)"
    exit 0
fi

if ! command -v agent-event-bus-cli &>/dev/null; then
    echo "WIP checkpoint skipped (agent-event-bus-cli not installed)"
    exit 0
fi

# Build URL args if AGENT_EVENT_BUS_URL is set (e.g., remote Tailscale endpoint)
URL_ARGS=()
[[ -n "${AGENT_EVENT_BUS_URL:-}" ]] && URL_ARGS=(--url "$AGENT_EVENT_BUS_URL")

# Parse input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "auto"')

[[ -z "$CWD" ]] && CWD="$PWD"
[[ -z "$SESSION_ID" ]] && { echo "WIP checkpoint skipped (no session_id)"; exit 0; }

# Get git info
BRANCH=""
WORKTREE=""
GIT_STATUS=""
if command -v git &>/dev/null && git -C "$CWD" rev-parse --git-dir &>/dev/null; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "")
    GIT_STATUS=$(git -C "$CWD" status --porcelain 2>/dev/null | head -3 || echo "")

    # Detect if we're in a worktree (using custom .worktrees/ directory structure)
    # Note: This matches the repo's worktree layout in .worktrees/<branch-name>/
    GIT_DIR=$(git -C "$CWD" rev-parse --git-dir 2>/dev/null || echo "")
    if [[ "$GIT_DIR" == *".worktrees"* ]]; then
        WORKTREE=$(basename "$(dirname "$GIT_DIR")")
    fi
fi

# Extract work ID from branch name (issue-N, pr-N, or adhoc)
WORK_ID=""
if [[ "$BRANCH" =~ ^issue-([0-9]+)$ ]]; then
    WORK_ID="issue-${BASH_REMATCH[1]}"
elif [[ "$BRANCH" =~ ^pr-([0-9]+)$ ]]; then
    WORK_ID="pr-${BASH_REMATCH[1]}"
elif [[ -n "$BRANCH" ]]; then
    WORK_ID="branch-${BRANCH}"
fi

# Get modified files (top 3 for brevity)
FILES_MODIFIED=""
if [[ -n "$GIT_STATUS" ]]; then
    FILES_MODIFIED=$(echo "$GIT_STATUS" | awk '{print $2}' | head -3 | xargs -I{} basename {} | tr '\n' ', ' | sed 's/,$//')
fi

# Get PR number if gh CLI available and we're on a feature branch
PR_NUMBER=""
if command -v gh &>/dev/null && [[ -n "$BRANCH" && "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
    PR_NUMBER=$(timeout 5 gh pr view --json number -q .number 2>/dev/null || echo "")
fi

# Get repo name (use git-common-dir to handle worktrees correctly)
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

# Build WIP state payload (compact, readable format for event bus)
# Format: [work:ID] | branch | pr | files | time
# Note: "next" and "decisions" require Claude context - use manual wip_progress events for those
CHECKPOINT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PAYLOAD="[work:${WORK_ID:-unknown}] | branch: ${BRANCH:-unknown}"
[[ -n "$PR_NUMBER" ]] && PAYLOAD="${PAYLOAD} | pr: #${PR_NUMBER}" || PAYLOAD="${PAYLOAD} | pr: none"
[[ -n "$WORKTREE" ]] && PAYLOAD="${PAYLOAD} | worktree: ${WORKTREE}"
[[ -n "$FILES_MODIFIED" ]] && PAYLOAD="${PAYLOAD} | files: ${FILES_MODIFIED}"
PAYLOAD="${PAYLOAD} | time: ${CHECKPOINT_TIME}"

# Publish to session-specific channel
RESULT=$(agent-event-bus-cli ${URL_ARGS[@]+"${URL_ARGS[@]}"} publish \
    --type "wip_checkpoint" \
    --payload "$PAYLOAD" \
    --session-id "$SESSION_ID" \
    --channel "session:${SESSION_ID}" \
    2>/dev/null) || true

if echo "$RESULT" | jq -e '.event_id' >/dev/null 2>&1; then
    echo "WIP state checkpointed before compaction"
    [[ -n "$WORK_ID" ]] && echo "  Work: $WORK_ID" || true
    [[ -n "$FILES_MODIFIED" ]] && echo "  Modified: $FILES_MODIFIED" || true
else
    echo "WIP checkpoint failed to publish"
fi
