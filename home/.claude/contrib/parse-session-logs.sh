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

# Collect all tool calls with project info
TOOL_CALLS=$(mktemp)
PROJECT_STATS=$(mktemp)
trap 'rm -f "$TOOL_CALLS" "$PROJECT_STATS"' EXIT

# Process log files (handle spaces in paths)
while IFS= read -r log_file; do
  [[ -z "$log_file" ]] && continue
  # Extract project name from log path (encoded form with leading dash stripped)
  project_name=$(echo "$log_file" | sed "s|$LOG_DIR/||" | cut -d'/' -f1 | sed 's/^-//')
  call_count=$(extract_tool_calls "$log_file" | tee -a "$TOOL_CALLS" | wc -l | tr -d ' ')
  if [[ $call_count -gt 0 ]]; then
    echo "$call_count $project_name" >> "$PROJECT_STATS"
  fi
done <<< "$LOG_FILES"

# Check if we got any data
if [[ ! -s "$TOOL_CALLS" ]]; then
  echo "No tool usage found in the last $DAYS days"
  exit 0  # trap handles cleanup
fi

# Show date range and project breakdown
show_header() {
  # Get date range from tool calls
  local oldest=$(awk -F'\t' 'NR==1 {print $1}' "$TOOL_CALLS" | cut -dT -f1)
  local newest=$(awk -F'\t' 'END {print $1}' "$TOOL_CALLS" | cut -dT -f1)
  local total=$(wc -l < "$TOOL_CALLS" | tr -d ' ')

  echo -e "${CYAN}Session Log Analysis${RESET}"
  echo -e "${GRAY}Analyzing $total tool calls from $oldest to $newest ($DAYS days, $SCOPE scope)${RESET}"
  echo ""

  # Project breakdown (only for global scope or if multiple projects)
  if [[ "$SCOPE" == "global" ]] && [[ -s "$PROJECT_STATS" ]]; then
    echo -e "${CYAN}Project Breakdown${RESET}"
    echo ""
    # Aggregate by project and show percentages
    awk '{sum[$2]+=$1; total+=$1} END {for(p in sum) printf "  %3d (%4.1f%%)  %s\n", sum[p], (sum[p]*100.0/total), p}' "$PROJECT_STATS" | \
      sort -rn | head -10
    echo ""
  fi
}

# Analyze frequency
analyze_frequency() {
  echo -e "${CYAN}Tool Frequency${RESET}"
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

# Compare against settings.json for missing permissions
analyze_missing_permissions() {
  local settings_file="$HOME/.claude/settings.json"
  [[ ! -f "$settings_file" ]] && return

  echo -e "${CYAN}Commands Needing Permission (not in settings.json)${RESET}"
  echo ""

  # Extract allowed Bash patterns from settings (patterns like "git status", "gh pr view", etc.)
  local allowed_patterns=$(jq -r '.permissions.allow[]? | select(startswith("Bash(")) | sub("^Bash\\("; "") | sub(":\\*\\)$"; "")' "$settings_file" 2>/dev/null | sort -u)

  # Get unique command prefixes from Bash calls (first two words, or first word if only one)
  local used_commands=$(awk -F'\t' '$2 == "Bash" {
    # Extract first two words (or first word if only one)
    split($3, words, " ")
    if (words[2] != "") print words[1]" "words[2]
    else print words[1]
  }' "$TOOL_CALLS" | sort -u)

  # Find commands not covered by allowed patterns
  local found_missing=0
  while IFS= read -r cmd; do
    # Skip empty or command substitution artifacts
    [[ -z "$cmd" ]] && continue
    [[ "$cmd" == *'$('* ]] && continue
    [[ "$cmd" == *'=('* ]] && continue

    # Check if any allowed pattern matches this command prefix
    # A command is allowed if:
    # 1. It exactly matches a pattern, OR
    # 2. The command extends a pattern (cmd starts with pattern), OR
    # 3. A pattern extends the command (pattern starts with cmd - means specific subcommands are allowed)
    local is_allowed=0
    while IFS= read -r pattern; do
      [[ -z "$pattern" ]] && continue
      if [[ "$cmd" == "$pattern" ]] || [[ "$cmd" == "$pattern "* ]] || [[ "$pattern" == "$cmd "* ]]; then
        is_allowed=1
        break
      fi
    done <<< "$allowed_patterns"

    if [[ $is_allowed -eq 0 ]]; then
      # Count occurrences using prefix match
      local count=$(awk -F'\t' -v cmd="$cmd" '$2 == "Bash" && index($3, cmd) == 1' "$TOOL_CALLS" | wc -l | tr -d ' ')
      if [[ $count -ge 3 ]]; then
        echo -e "  ${YELLOW}$cmd${RESET}: $count calls"
        found_missing=1
      fi
    fi
  done <<< "$used_commands"

  if [[ $found_missing -eq 0 ]]; then
    echo -e "  ${GREEN}All frequent commands are permitted${RESET}"
  fi
  echo ""
}

# Generate suggestions (only prints if there are suggestions to show)
generate_suggestions() {
  # Initialize counters with defaults to avoid unbound variable errors
  local git_status_count=0
  local git_diff_count=0
  local bash_count=0
  local total_count=0
  local suggestions=""

  # High-frequency manual git commands
  git_status_count=$(awk -F'\t' '$2 == "Bash" && $3 ~ /^git status/' "$TOOL_CALLS" | wc -l | tr -d ' ')
  git_diff_count=$(awk -F'\t' '$2 == "Bash" && $3 ~ /^git diff/' "$TOOL_CALLS" | wc -l | tr -d ' ')

  # Ensure numeric values
  git_status_count=${git_status_count:-0}
  git_diff_count=${git_diff_count:-0}

  if [[ $git_status_count -gt 5 && $git_diff_count -gt 5 ]]; then
    suggestions+="  ${YELLOW}●${RESET} High-value: You run 'git status' ($git_status_count×) and 'git diff' ($git_diff_count×) frequently\n"
    suggestions+="    → Consider creating a '/git-summary' command that combines both\n\n"
  fi

  # Check for repeated tool usage (potential friction)
  bash_count=$(awk -F'\t' '$2 == "Bash"' "$TOOL_CALLS" | wc -l | tr -d ' ')
  total_count=$(wc -l < "$TOOL_CALLS" | tr -d ' ')

  # Ensure numeric values
  bash_count=${bash_count:-0}
  total_count=${total_count:-1}  # Avoid division by zero

  if [[ $total_count -gt 0 ]]; then
    local bash_pct=$((bash_count * 100 / total_count))

    if [[ $bash_pct -gt 80 ]]; then
      suggestions+="  ${YELLOW}●${RESET} Heavy Bash usage: ${bash_pct}% of tool calls are Bash commands\n"
      suggestions+="    → Consider which frequent commands could become dedicated tools\n\n"
    fi
  fi

  # Only print header and suggestions if we have any
  if [[ -n "$suggestions" ]]; then
    echo -e "${CYAN}Suggested Workflow Improvements${RESET}"
    echo ""
    echo -e "$suggestions"
  fi
}

# Run analysis
echo ""
show_header
analyze_frequency
analyze_bash_commands
analyze_sequences
analyze_skills
analyze_missing_permissions
generate_suggestions

# Cleanup handled by EXIT trap
