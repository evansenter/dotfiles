#!/usr/bin/env bash
#
# Parse Claude Code session logs for usage metrics
# Usage: parse-session-logs.sh [--project|--global] [--days N]
#
# Session logs are stored in ~/.claude/projects/**/*.jsonl
# These files contain structured session data including tool calls, timestamps,
# and conversation content. Availability may vary based on Claude Code's
# cleanup/retention policies.
#
# This parser analyzes:
# - Tool frequency (Bash, Read, Edit, MCP tools, Skills, etc.)
# - Top commands (git, gh, cargo, etc.)
# - Tool sequences (common workflow patterns)
# - Evidence-based workflow improvement suggestions

set -euo pipefail

# Defaults
SCOPE="project"  # or "global"
DAYS=7
PROJECT_DIR="$(pwd)"
VERBOSE=0

# Colors
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
GRAY='\033[0;90m'
RESET='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --project) SCOPE="project"; shift ;;
    --global) SCOPE="global"; shift ;;
    --days) DAYS="$2"; shift 2 ;;
    --verbose|-v) VERBOSE=1; shift ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "OPTIONS:"
      echo "  --project       Analyze current project only (default)"
      echo "  --global        Analyze all projects"
      echo "  --days N        Look back N days (default: 7)"
      echo "  --verbose, -v   Show detailed output"
      echo "  --help          Show this help"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Calculate cutoff timestamp (7 days ago)
if date -v-${DAYS}d > /dev/null 2>&1; then
  # macOS
  CUTOFF=$(date -u -v-${DAYS}d +"%Y-%m-%dT%H:%M:%SZ")
else
  # Linux
  CUTOFF=$(date -u -d "$DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ")
fi

# Find log files
LOG_DIR="$HOME/.claude/projects"
if [[ "$SCOPE" == "project" ]]; then
  # Encode project path (slashes to dashes)
  PROJECT_ENCODED=$(echo "$PROJECT_DIR" | sed 's|/|-|g')
  LOG_FILES=$(find "$LOG_DIR/$PROJECT_ENCODED" -name "*.jsonl" 2>/dev/null || echo "")
else
  LOG_FILES=$(find "$LOG_DIR" -name "*.jsonl" 2>/dev/null || echo "")
fi

if [[ -z "$LOG_FILES" ]]; then
  echo "No session logs found"
  exit 1
fi

[[ $VERBOSE -eq 1 ]] && echo "Found log files: $LOG_FILES" >&2

# Extract tool calls with timestamps
# Format: timestamp TAB tool_name TAB details
extract_tool_calls() {
  local log_file="$1"
  jq -r --arg cutoff "$CUTOFF" '
    select(.timestamp >= $cutoff and .message.content[]?.type == "tool_use") |
    .timestamp as $ts |
    .message.content[] |
    select(.type == "tool_use") |
    [
      $ts,
      .name,
      (if .input.command then .input.command
       elif .input.skill then .input.skill
       elif .input.file_path then .input.file_path
       else "" end)
    ] |
    @tsv
  ' "$log_file" 2>/dev/null || true
}

# Collect all tool calls
TOOL_CALLS=$(mktemp)
for log_file in $LOG_FILES; do
  extract_tool_calls "$log_file" >> "$TOOL_CALLS"
done

# Check if we got any data
if [[ ! -s "$TOOL_CALLS" ]]; then
  echo "No tool usage found in the last $DAYS days"
  rm "$TOOL_CALLS"
  exit 0
fi

# Analyze frequency
analyze_frequency() {
  echo -e "${CYAN}Tool Frequency (last $DAYS days, $SCOPE scope)${RESET}"
  echo ""

  # Count by tool name
  awk -F'\t' '{print $2}' "$TOOL_CALLS" | \
    sort | uniq -c | sort -rn | \
    head -20 | \
    awk '{printf "  %3d  %s\n", $1, $2}'

  echo ""
}

# Analyze Bash commands
analyze_bash_commands() {
  echo -e "${CYAN}Top Bash Commands${RESET}"
  echo ""

  # Extract just Bash commands
  awk -F'\t' '$2 == "Bash" {print $3}' "$TOOL_CALLS" | \
    # Extract first word (the actual command)
    awk '{print $1}' | \
    sort | uniq -c | sort -rn | \
    head -15 | \
    awk '{printf "  %3d  %s\n", $1, $2}'

  echo ""
}

# Analyze sequences (simple: consecutive tool pairs)
analyze_sequences() {
  echo -e "${CYAN}Common Tool Sequences${RESET}"
  echo ""

  # Get tool names in order
  awk -F'\t' '{print $2}' "$TOOL_CALLS" | \
    # Create pairs (current + next line)
    awk 'NR > 1 {print prev " → " $0} {prev = $0}' | \
    sort | uniq -c | sort -rn | \
    head -10 | \
    awk '{printf "  %2d  %s\n", $1, substr($0, index($0, $2))}'

  echo ""
}

# Analyze Skills
analyze_skills() {
  local skill_count=$(awk -F'\t' '$2 == "Skill" {print $3}' "$TOOL_CALLS" | wc -l | tr -d ' ')

  if [[ $skill_count -gt 0 ]]; then
    echo -e "${CYAN}Skill Invocations${RESET}"
    echo ""

    awk -F'\t' '$2 == "Skill" {print $3}' "$TOOL_CALLS" | \
      sort | uniq -c | sort -rn | \
      awk '{printf "  %3d  %s\n", $1, $2}'

    echo ""
  fi
}

# Generate suggestions
generate_suggestions() {
  echo -e "${CYAN}Suggested Workflow Improvements${RESET}"
  echo ""

  # High-frequency manual git commands
  local git_status_count=$(awk -F'\t' '$2 == "Bash" && $3 ~ /^git status/' "$TOOL_CALLS" | wc -l | tr -d ' ')
  local git_diff_count=$(awk -F'\t' '$2 == "Bash" && $3 ~ /^git diff/' "$TOOL_CALLS" | wc -l | tr -d ' ')

  if [[ $git_status_count -gt 5 && $git_diff_count -gt 5 ]]; then
    echo -e "  ${YELLOW}●${RESET} High-value: You run 'git status' ($git_status_count×) and 'git diff' ($git_diff_count×) frequently"
    echo "    → Consider creating a '/git-summary' command that combines both"
    echo ""
  fi

  # Common sequences that could be automated
  local read_edit_count=$(grep "Read → Edit" "$TOOL_CALLS" 2>/dev/null | wc -l | tr -d ' ')
  if [[ $read_edit_count -gt 3 ]]; then
    echo -e "  ${YELLOW}●${RESET} Pattern: Read → Edit sequence appears ${read_edit_count}× in your workflow"
    echo "    → This is expected for file editing, no action needed"
    echo ""
  fi

  # Check for repeated tool usage (potential friction)
  local bash_count=$(awk -F'\t' '$2 == "Bash"' "$TOOL_CALLS" | wc -l | tr -d ' ')
  local total_count=$(wc -l < "$TOOL_CALLS" | tr -d ' ')
  local bash_pct=$((bash_count * 100 / total_count))

  if [[ $bash_pct -gt 80 ]]; then
    echo -e "  ${YELLOW}●${RESET} Heavy Bash usage: ${bash_pct}% of tool calls are Bash commands"
    echo "    → Consider which frequent commands could become dedicated tools"
    echo ""
  fi
}

# Run analysis
echo ""
analyze_frequency
analyze_bash_commands
analyze_sequences
analyze_skills
generate_suggestions

# Cleanup
rm "$TOOL_CALLS"
