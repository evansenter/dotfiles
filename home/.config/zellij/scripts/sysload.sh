#!/bin/bash
# macOS system load: CPU% + RAM%
output=$(top -l 1 -s 0 2>/dev/null)
cpu=$(echo "$output" | awk '/CPU usage/ { printf "%d%%", 100 - $7 }')
mem=$(echo "$output" | awk '/PhysMem/ {
    used = $2; unused = $6
    # Strip G/M suffix and normalize to MB
    if (index(used,"G")) { u = used * 1024 } else { u = used + 0 }
    if (index(unused,"G")) { f = unused * 1024 } else { f = unused + 0 }
    printf "%d%%", (u / (u + f)) * 100
}')
[ -n "$cpu" ] && printf '󰒼 %s  󰍛 %s' "$cpu" "$mem"
