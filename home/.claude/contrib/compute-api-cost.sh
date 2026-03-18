#!/usr/bin/env bash
#
# compute-api-cost.sh - Calculate estimated API costs from agent-session-analytics data
#
# Usage: compute-api-cost.sh [--days N] [--json]
#
# Calculates what the token usage would cost at API rates (Opus 4.5 pricing).
# Useful for understanding the value of Claude Max subscription vs pay-as-you-go.
#
# Pricing (Opus 4.5, as of Nov 2025):
#   Input:       $5.00 / MTok
#   Output:     $25.00 / MTok
#   Cache write: $6.25 / MTok (1.25x input)
#   Cache read:  $0.50 / MTok (0.1x input)
#
# Sources:
#   https://platform.claude.com/docs/en/about-claude/pricing
#   https://www.anthropic.com/claude/opus

set -euo pipefail

# Pricing per million tokens (Opus 4.5)
INPUT_PRICE="5.00"
OUTPUT_PRICE="25.00"
CACHE_WRITE_PRICE="6.25"
CACHE_READ_PRICE="0.50"

# Defaults
DAYS=17
JSON_OUTPUT=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Calculate estimated API costs from agent-session-analytics token data.

Options:
    --days N     Number of days to analyze (default: 17)
    --json       Output as JSON
    -h, --help   Show this help

Examples:
    $(basename "$0")              # Last 17 days
    $(basename "$0") --days 7     # Last 7 days
    $(basename "$0") --json       # JSON output for scripting
EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --days)
            DAYS="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Get token data using agent-session-analytics CLI
get_token_data() {
    local cli_path=""

    # Find CLI - check common locations
    if command -v agent-session-analytics-cli &>/dev/null; then
        cli_path="agent-session-analytics-cli"
    elif [[ -x "$HOME/projects/agent-session-analytics/.venv/bin/agent-session-analytics-cli" ]]; then
        cli_path="$HOME/projects/agent-session-analytics/.venv/bin/agent-session-analytics-cli"
    elif [[ -x "$HOME/.local/bin/agent-session-analytics-cli" ]]; then
        cli_path="$HOME/.local/bin/agent-session-analytics-cli"
    else
        echo "Error: agent-session-analytics-cli not found" >&2
        echo "Install from: https://github.com/evansenter/agent-session-analytics" >&2
        exit 1
    fi

    "$cli_path" --json tokens --days "$DAYS"
}

# Calculate costs
calculate_costs() {
    local data="$1"

    # Extract token counts
    local input_tokens output_tokens cache_read cache_write
    input_tokens=$(echo "$data" | jq -r '.total_input_tokens')
    output_tokens=$(echo "$data" | jq -r '.total_output_tokens')
    cache_read=$(echo "$data" | jq -r '.total_cache_read_tokens')
    cache_write=$(echo "$data" | jq -r '.total_cache_creation_tokens')

    # Convert to millions for cost calculation
    local input_m output_m cache_read_m cache_write_m
    input_m=$(echo "scale=6; $input_tokens / 1000000" | bc)
    output_m=$(echo "scale=6; $output_tokens / 1000000" | bc)
    cache_read_m=$(echo "scale=6; $cache_read / 1000000" | bc)
    cache_write_m=$(echo "scale=6; $cache_write / 1000000" | bc)

    # Calculate costs with caching
    local input_cost output_cost cache_read_cost cache_write_cost total_with_caching
    input_cost=$(echo "scale=2; $input_m * $INPUT_PRICE" | bc)
    output_cost=$(echo "scale=2; $output_m * $OUTPUT_PRICE" | bc)
    cache_read_cost=$(echo "scale=2; $cache_read_m * $CACHE_READ_PRICE" | bc)
    cache_write_cost=$(echo "scale=2; $cache_write_m * $CACHE_WRITE_PRICE" | bc)
    total_with_caching=$(echo "scale=2; $input_cost + $output_cost + $cache_read_cost + $cache_write_cost" | bc)

    # Calculate costs without caching (cache reads become regular input)
    local total_input_without_cache input_without_cache_cost total_without_caching
    total_input_without_cache=$(echo "scale=6; $input_m + $cache_read_m" | bc)
    input_without_cache_cost=$(echo "scale=2; $total_input_without_cache * $INPUT_PRICE" | bc)
    total_without_caching=$(echo "scale=2; $input_without_cache_cost + $output_cost" | bc)

    # Calculate savings multiplier
    local savings_multiplier
    savings_multiplier=$(echo "scale=1; $total_without_caching / $total_with_caching" | bc)

    # Format large numbers
    format_tokens() {
        local tokens=$1
        if (( tokens >= 1000000000 )); then
            echo "$(echo "scale=1; $tokens / 1000000000" | bc)B"
        elif (( tokens >= 1000000 )); then
            echo "$(echo "scale=1; $tokens / 1000000" | bc)M"
        elif (( tokens >= 1000 )); then
            echo "$(echo "scale=1; $tokens / 1000" | bc)K"
        else
            echo "$tokens"
        fi
    }

    format_currency() {
        local amount=$1
        if (( $(echo "$amount >= 1000" | bc -l) )); then
            printf "\$%.1fK" "$(echo "scale=1; $amount / 1000" | bc)"
        else
            printf "\$%.0f" "$amount"
        fi
    }

    if $JSON_OUTPUT; then
        cat <<EOF
{
  "days": $DAYS,
  "tokens": {
    "input": $input_tokens,
    "output": $output_tokens,
    "cache_read": $cache_read,
    "cache_write": $cache_write
  },
  "pricing": {
    "input_per_mtok": $INPUT_PRICE,
    "output_per_mtok": $OUTPUT_PRICE,
    "cache_write_per_mtok": $CACHE_WRITE_PRICE,
    "cache_read_per_mtok": $CACHE_READ_PRICE
  },
  "costs": {
    "with_caching": {
      "input": $input_cost,
      "output": $output_cost,
      "cache_write": $cache_write_cost,
      "cache_read": $cache_read_cost,
      "total": $total_with_caching
    },
    "without_caching": {
      "input": $input_without_cache_cost,
      "output": $output_cost,
      "total": $total_without_caching
    },
    "savings_multiplier": $savings_multiplier
  }
}
EOF
    else
        echo "=== API Cost Estimate (${DAYS} days) ==="
        echo ""
        echo "Token Usage:"
        echo "  Input:       $(format_tokens "$input_tokens")"
        echo "  Output:      $(format_tokens "$output_tokens")"
        echo "  Cache read:  $(format_tokens "$cache_read")"
        echo "  Cache write: $(format_tokens "$cache_write")"
        echo ""
        echo "Opus 4.5 Pricing (per MTok):"
        echo "  Input:       \$$INPUT_PRICE"
        echo "  Output:      \$$OUTPUT_PRICE"
        echo "  Cache write: \$$CACHE_WRITE_PRICE"
        echo "  Cache read:  \$$CACHE_READ_PRICE"
        echo ""
        echo "Cost Breakdown (with caching):"
        echo "  Input:       \$$input_cost"
        echo "  Output:      \$$output_cost"
        echo "  Cache write: \$$cache_write_cost"
        echo "  Cache read:  \$$cache_read_cost"
        echo "  ─────────────────────"
        echo "  Total:       $(format_currency "$total_with_caching")"
        echo ""
        echo "Without Caching:"
        echo "  Total:       $(format_currency "$total_without_caching")"
        echo ""
        echo "Caching Savings: ${savings_multiplier}x"
    fi
}

# Main
main() {
    local token_data
    token_data=$(get_token_data)
    calculate_costs "$token_data"
}

main
