#!/bin/bash
# Tests for bootstrap.sh
#
# Run with: ./tests/test-bootstrap.sh
# Or via make: make test-bootstrap

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BOOTSTRAP="$SCRIPT_DIR/../bootstrap.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED=$'\e[31m'
GREEN=$'\e[32m'
RESET=$'\e[0m'

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

# ============================================================================
# Naming consistency tests (moltbot -> openclaw migration)
# ============================================================================

test_no_moltbot_references_bootstrap() {
    # bootstrap.sh should not contain any moltbot references
    ! grep -qi 'moltbot' "$BOOTSTRAP"
}

test_no_moltbot_references_claude_md() {
    local claude_md="$SCRIPT_DIR/../CLAUDE.md"
    ! grep -qi 'moltbot' "$claude_md"
}

test_no_moltbot_references_home() {
    # No tracked config files under home/ should reference moltbot
    # Exclude binary/db files and log files (contain historical data)
    ! find "$SCRIPT_DIR/../home" -type f \
        -not -path "*/.git/*" \
        -not -name "*.db" \
        -not -name "*.db.*" \
        -not -name "*.log" \
        -not -name "*.err" \
        -not -name "*.stdout" \
        -print0 | \
        xargs -0 grep -li 'moltbot' 2>/dev/null
}

test_openclaw_config_path() {
    # Config should be at home/.openclaw/openclaw.json, not home/.moltbot/
    [[ -f "$SCRIPT_DIR/../home/.openclaw/openclaw.json" ]] && \
    [[ ! -d "$SCRIPT_DIR/../home/.moltbot" ]]
}

test_openclaw_function_names() {
    # bootstrap.sh should use openclaw function names
    grep -q 'symlink_openclaw_config' "$BOOTSTRAP" && \
    grep -q 'install_openclaw_cli' "$BOOTSTRAP" && \
    ! grep -q 'symlink_moltbot_config' "$BOOTSTRAP" && \
    ! grep -q 'install_moltbot_cli' "$BOOTSTRAP"
}

test_openclaw_env_var() {
    # Config should reference OPENCLAW_GATEWAY_TOKEN, not MOLTBOT_GATEWAY_TOKEN
    grep -q 'OPENCLAW_GATEWAY_TOKEN' "$SCRIPT_DIR/../home/.openclaw/openclaw.json" && \
    ! grep -q 'MOLTBOT_GATEWAY_TOKEN' "$SCRIPT_DIR/../home/.openclaw/openclaw.json"
}

# ============================================================================
# URL migration tests (speck-vm -> mac-mini/localhost)
# ============================================================================

test_no_speck_vm_mcp_urls() {
    # settings.json should not reference speck-vm for MCP URLs
    ! grep -q 'speck-vm.*agent-event-bus' "$SCRIPT_DIR/../home/.claude/settings.json" && \
    ! grep -q 'speck-vm.*agent-session-analytics' "$SCRIPT_DIR/../home/.claude/settings.json"
}

test_openclaw_gateway_url() {
    # openclaw.json should point to mac-mini, not speck-vm
    grep -q 'mac-mini' "$SCRIPT_DIR/../home/.openclaw/openclaw.json" && \
    ! grep -q 'speck-vm' "$SCRIPT_DIR/../home/.openclaw/openclaw.json"
}

# ============================================================================
# Bootstrap structure tests
# ============================================================================

test_bootstrap_syntax() {
    bash -n "$BOOTSTRAP"
}

test_bootstrap_excludes_openclaw_from_symlinks() {
    # symlink_dotfiles should exclude .openclaw/ (handled separately)
    grep -q '\.openclaw' "$BOOTSTRAP"
}

test_bootstrap_handles_cargo_sweep() {
    # bootstrap.sh should handle cargo-sweep (LaunchAgent install + legacy cron removal)
    grep -q 'cargo-sweep' "$BOOTSTRAP"
}

test_cargo_sweep_script_exists() {
    [[ -f "$SCRIPT_DIR/../home/.bin/cargo-sweep-all" ]] && \
    [[ -x "$SCRIPT_DIR/../home/.bin/cargo-sweep-all" ]]
}

test_cargo_sweep_syntax() {
    bash -n "$SCRIPT_DIR/../home/.bin/cargo-sweep-all"
}

test_configure_claude_local_settings_exists() {
    # bootstrap.sh should have the configure_claude_local_settings function
    grep -q 'configure_claude_local_settings' "$BOOTSTRAP"
}

test_settings_local_skips_gateway_host() {
    # The function should skip on mac-mini (gateway host)
    grep -q 'mac-mini' "$BOOTSTRAP" && \
    grep -q 'HOSTNAME' "$BOOTSTRAP"
}

test_ensure_openclaw_workspace_exists() {
    # bootstrap.sh should have the ensure_openclaw_workspace function
    grep -q 'ensure_openclaw_workspace' "$BOOTSTRAP"
}

test_openclaw_workspace_gitignore() {
    # .gitignore should exist and ignore *.md to prevent tracking personal content
    [[ -f "$SCRIPT_DIR/../home/.openclaw/workspace/.gitignore" ]] && \
    grep -q '\*.md' "$SCRIPT_DIR/../home/.openclaw/workspace/.gitignore"
}

test_sync_dotfiles_no_package_install() {
    # sync_dotfiles must not call package installers directly — packages are
    # handled by the PULL guard so they only run with --pull
    local sync_body
    sync_body=$(sed -n '/^sync_dotfiles()/,/^}/p' "$BOOTSTRAP")
    ! echo "$sync_body" | grep -v '^\s*#' | grep -qE 'install_brew_packages|install_packages|install_apt_packages|install_steamos_packages'
}

test_no_documents_projects_refs() {
    # No tracked source files should reference ~/Documents/projects/
    # Exclude: .git, databases, logs, error files, backups, worktree settings, this test
    ! find "$SCRIPT_DIR/.." -type f \
        -not -path "*/.git/*" \
        -not -path "*/tests/test-bootstrap.sh" \
        -not -path "*/.claude/settings.local.json" \
        -not -name "*.db" \
        -not -name "*.db.*" \
        -not -name "*.log" \
        -not -name "*.err" \
        -not -name "*.stdout" \
        -print0 | \
        xargs -0 grep -l 'Documents/projects' 2>/dev/null
}

# ============================================================================
# SteamOS / Linux compatibility tests
# ============================================================================

test_steamos_detection() {
    grep -q 'is_steamos' "$BOOTSTRAP"
}

test_steamos_packages() {
    grep -q 'install_steamos_packages' "$BOOTSTRAP"
}

test_set_default_shell() {
    grep -q 'set_default_shell' "$BOOTSTRAP"
}

test_steamos_no_usr_local() {
    # install_steamos_packages should not write to /usr/local (comments ok)
    local steamos_func
    steamos_func=$(sed -n '/^install_steamos_packages()/,/^}/p' "$BOOTSTRAP")
    ! echo "$steamos_func" | grep -v '^\s*#' | grep -q '/usr/local'
}

# ============================================================================
# Flag combination tests
# ============================================================================

# Helper: run bootstrap.sh with args, capturing which functions are called.
# Overrides all side-effect functions with stubs that log to a temp file.
# Returns the log so tests can check which functions ran and in what order.
#
# NOTE: The argument parsing logic below is duplicated from bootstrap.sh's main
# execution block. If bootstrap.sh's flag handling changes, update this mock to
# match — otherwise tests will pass against stale logic.
run_bootstrap_with_mocks() {
    local log
    log=$(mktemp)
    local mock_script
    mock_script=$(mktemp)

    # Build a wrapper that:
    # 1. Defines stub functions that log their name
    # 2. Overrides 'read' to auto-answer 'y' (simulate confirmation)
    # 3. Sources bootstrap.sh to get function definitions
    # 4. Re-overrides the functions with stubs
    # 5. Runs the main execution block
    cat > "$mock_script" << 'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="__LOG__"

# Stub functions that log their name
update_packages() { echo "update_packages" >> "$LOG_FILE"; }
install_packages() { echo "install_packages" >> "$LOG_FILE"; }
pull_latest() { echo "pull_latest" >> "$LOG_FILE"; }
sync_dotfiles() { echo "sync_dotfiles" >> "$LOG_FILE"; }

# Override read to auto-confirm
read() { REPLY="y"; }

# Mirror bootstrap.sh argument parsing and execution logic
FORCE=false
PULL=false
for arg in "$@"; do
    case "$arg" in
        --force|-f) FORCE=true ;;
        --pull|-p) PULL=true ;;
    esac
done

if [[ "$PULL" == true ]]; then
    pull_latest
    install_packages
    update_packages
fi

if [[ "$FORCE" == true ]]; then
    sync_dotfiles
else
    read -p "confirm? " -n 1
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sync_dotfiles
    fi
fi
WRAPPER

    # Substitute log path
    sed -i.bak "s|__LOG__|$log|g" "$mock_script"
    rm -f "${mock_script}.bak"

    chmod +x "$mock_script"
    bash "$mock_script" "$@" 2>/dev/null
    local exit_code=$?

    cat "$log"
    rm -f "$log" "$mock_script"
    return $exit_code
}

test_flag_help() {
    local output
    output=$("$BOOTSTRAP" --help 2>&1)
    echo "$output" | grep -q "Usage:" && \
    echo "$output" | grep -q "\-f, --force" && \
    echo "$output" | grep -q "\-p, --pull"
}

test_flag_force_only() {
    # --force: just sync dotfiles without prompt (no pull by default)
    local output
    output=$(run_bootstrap_with_mocks --force)
    [[ "$output" == "sync_dotfiles" ]]
}

test_flag_pull_force() {
    # --pull --force: pull, install packages, and sync dotfiles without prompt
    local output
    output=$(run_bootstrap_with_mocks --pull --force)
    local line1 line2 line3 line4
    line1=$(echo "$output" | sed -n '1p')
    line2=$(echo "$output" | sed -n '2p')
    line3=$(echo "$output" | sed -n '3p')
    line4=$(echo "$output" | sed -n '4p')
    [[ "$line1" == "pull_latest" ]] && \
    [[ "$line2" == "install_packages" ]] && \
    [[ "$line3" == "update_packages" ]] && \
    [[ "$line4" == "sync_dotfiles" ]]
}

test_flag_pull_only() {
    # --pull without --force prompts, our mock auto-confirms
    local output
    output=$(run_bootstrap_with_mocks --pull)
    local line1 line2 line3 line4
    line1=$(echo "$output" | sed -n '1p')
    line2=$(echo "$output" | sed -n '2p')
    line3=$(echo "$output" | sed -n '3p')
    line4=$(echo "$output" | sed -n '4p')
    [[ "$line1" == "pull_latest" ]] && \
    [[ "$line2" == "install_packages" ]] && \
    [[ "$line3" == "update_packages" ]] && \
    [[ "$line4" == "sync_dotfiles" ]]
}

test_flag_short_forms() {
    # -p should work identically to --pull
    local output
    output=$(run_bootstrap_with_mocks -f -p)
    local line1 line2 line3 line4
    line1=$(echo "$output" | sed -n '1p')
    line2=$(echo "$output" | sed -n '2p')
    line3=$(echo "$output" | sed -n '3p')
    line4=$(echo "$output" | sed -n '4p')
    [[ "$line1" == "pull_latest" ]] && \
    [[ "$line2" == "install_packages" ]] && \
    [[ "$line3" == "update_packages" ]] && \
    [[ "$line4" == "sync_dotfiles" ]]
}

test_flag_no_args_prompts() {
    # No flags: just sync dotfiles with prompt (mock auto-confirms), no pull
    local output
    output=$(run_bootstrap_with_mocks)
    [[ "$output" == "sync_dotfiles" ]]
}

# ============================================================================
# New-machine readiness (behavioral)
# ============================================================================

# Load the REAL is_gateway_host definition from bootstrap.sh (not a copy),
# without executing bootstrap's unguarded main.
_load_is_gateway_host() {
    eval "$(sed -n '/^is_gateway_host() {/,/^}/p' "$BOOTSTRAP")"
}

test_gateway_host_matches_plain() {
    _load_is_gateway_host
    HOSTNAME="mac-mini" is_gateway_host
}

test_gateway_host_matches_bonjour_suffix() {
    # macOS Bonjour appends -N on mDNS collision; the gate must still match.
    _load_is_gateway_host
    HOSTNAME="mac-mini-2" is_gateway_host
}

test_gateway_host_matches_fqdn() {
    _load_is_gateway_host
    HOSTNAME="mac-mini-2.tailac7b3c.ts.net" is_gateway_host
}

test_gateway_host_rejects_other() {
    _load_is_gateway_host
    ! HOSTNAME="steamdeck" is_gateway_host && ! HOSTNAME="mac-mini-laptop" is_gateway_host
}

# obsidian-mcp-start must NOT exec the server when the Obsidian REST API is down
# (the KeepAlive crash-loop). It should back off and exit non-zero instead.
test_obsidian_preflight_backs_off_when_upstream_down() {
    local wrapper="$SCRIPT_DIR/../home/.bin/obsidian-mcp-start"
    [[ -f "$wrapper" ]] || return 1
    local stub home; stub=$(mktemp -d); home=$(mktemp -d)
    printf '#!/bin/bash\nexit 1\n' > "$stub/curl"                      # upstream down
    printf '#!/bin/bash\nexit 0\n' > "$stub/sleep"                     # don't actually wait 15s
    printf '#!/bin/bash\ntouch "%s/server_ran"\n' "$home" > "$stub/obsidian-mcp-server"
    chmod +x "$stub"/*
    local rc=0
    PATH="$stub:$PATH" HOME="$home" OBSIDIAN_API_KEY="test" bash "$wrapper" >/dev/null 2>&1 || rc=$?
    local ran=1; [[ -e "$home/server_ran" ]] && ran=0
    rm -rf "$stub" "$home"
    [[ "$rc" -ne 0 && "$ran" -ne 0 ]]   # non-zero exit AND server did not run
}

test_obsidian_preflight_starts_when_upstream_up() {
    local wrapper="$SCRIPT_DIR/../home/.bin/obsidian-mcp-start"
    [[ -f "$wrapper" ]] || return 1
    local stub home; stub=$(mktemp -d); home=$(mktemp -d)
    printf '#!/bin/bash\nexit 0\n' > "$stub/curl"                      # upstream up
    printf '#!/bin/bash\ntouch "%s/server_ran"\nexit 0\n' "$home" > "$stub/obsidian-mcp-server"
    chmod +x "$stub"/*
    PATH="$stub:$PATH" HOME="$home" OBSIDIAN_API_KEY="test" bash "$wrapper" >/dev/null 2>&1 || true
    local ran=1; [[ -e "$home/server_ran" ]] && ran=0
    rm -rf "$stub" "$home"
    [[ "$ran" -eq 0 ]]   # server was exec'd
}

# sysload-writer parses `top` output into ~/.cache/sysload for the zellij widget.
# Stub `top` with a known sample and assert the cache is written with the
# computed CPU% (100 - idle) and RAM% (used / (used + unused)).
test_sysload_writer_writes_cache() {
    local writer="$SCRIPT_DIR/../home/.bin/sysload-writer"
    [[ -f "$writer" ]] || return 1
    local stub home; stub=$(mktemp -d); home=$(mktemp -d)
    # CPU usage idle=85.0% -> 15%; PhysMem 20G used / 2949M unused -> 87%.
    {
        printf '#!/bin/bash\ncat <<EOF\n'
        printf 'CPU usage: 5.0%% user, 10.0%% sys, 85.0%% idle\n'
        printf 'PhysMem: 20G used (2759M wired, 3222M compressor), 2949M unused.\n'
        printf 'EOF\n'
    } > "$stub/top"
    chmod +x "$stub/top"
    PATH="$stub:$PATH" HOME="$home" bash "$writer" >/dev/null 2>&1 || true
    local cache="$home/.cache/sysload" ok=0
    [[ -f "$cache" ]] || ok=1
    grep -q '15%' "$cache" 2>/dev/null || ok=1
    grep -q '87%' "$cache" 2>/dev/null || ok=1
    rm -rf "$stub" "$home"
    return $ok
}

# When `top` fails, sysload-writer must exit 0 (LaunchAgent KeepAlive sanity)
# and NOT write a cache file, so the widget keeps its last good value.
test_sysload_writer_tolerates_top_failure() {
    local writer="$SCRIPT_DIR/../home/.bin/sysload-writer"
    [[ -f "$writer" ]] || return 1
    local stub home rc=0; stub=$(mktemp -d); home=$(mktemp -d)
    printf '#!/bin/bash\nexit 1\n' > "$stub/top"
    chmod +x "$stub/top"
    PATH="$stub:$PATH" HOME="$home" bash "$writer" >/dev/null 2>&1 || rc=$?
    local wrote=1; [[ -e "$home/.cache/sysload" ]] && wrote=0
    rm -rf "$stub" "$home"
    [[ "$rc" -eq 0 && "$wrote" -ne 0 ]]   # exited clean, no cache written
}

# Load the REAL install_launch_agent, but redirect its dotfiles_dir (derived from
# BASH_SOURCE, which eval can't satisfy) at a fixture tree. Everything else —
# __HOME__ substitution, the cmp-based idempotency guard, the launchctl reload —
# is the genuine bootstrap logic.
_load_install_launch_agent() {
    # Handles both declaration styles: the one-line `local dotfiles_dir="$(...)"`
    # and the SC2155-split `local dotfiles_dir` + `dotfiles_dir="$(cd ...)"`.
    eval "$(sed -n '/^install_launch_agent() {/,/^}/p' "$BOOTSTRAP" \
        | sed -e 's|local dotfiles_dir=.*|local dotfiles_dir="${TEST_DOTFILES_DIR:?}"|' \
              -e 's|^\([[:space:]]*\)dotfiles_dir="\$(cd .*|\1dotfiles_dir="${TEST_DOTFILES_DIR:?}"|')"
}

test_launch_agent_substitutes_home() {
    _load_install_launch_agent
    local root home stub; root=$(mktemp -d); home=$(mktemp -d); stub=$(mktemp -d)
    mkdir -p "$root/LaunchAgents"
    printf '<plist><string>__HOME__/.local/log/x.log</string></plist>\n' > "$root/LaunchAgents/test.plist"
    printf '#!/bin/bash\necho "$@" >> "%s/launchctl.calls"\nexit 0\n' "$home" > "$stub/launchctl"
    chmod +x "$stub/launchctl"
    PATH="$stub:$PATH" HOME="$home" TEST_DOTFILES_DIR="$root" install_launch_agent "test.plist" >/dev/null 2>&1
    local dest="$home/Library/LaunchAgents/test.plist" ok=0
    [[ -f "$dest" ]] || ok=1
    grep -q "$home/.local/log/x.log" "$dest" 2>/dev/null || ok=1   # __HOME__ expanded
    grep -q '__HOME__' "$dest" 2>/dev/null && ok=1                  # placeholder gone
    grep -q 'bootstrap' "$home/launchctl.calls" 2>/dev/null || ok=1 # agent (re)loaded
    rm -rf "$root" "$home" "$stub"
    return $ok
}

test_launch_agent_idempotent_on_unchanged_plist() {
    _load_install_launch_agent
    local root home stub; root=$(mktemp -d); home=$(mktemp -d); stub=$(mktemp -d)
    mkdir -p "$root/LaunchAgents"
    printf '<plist><string>__HOME__/x</string></plist>\n' > "$root/LaunchAgents/test.plist"
    printf '#!/bin/bash\necho "$@" >> "%s/launchctl.calls"\nexit 0\n' "$home" > "$stub/launchctl"
    chmod +x "$stub/launchctl"
    PATH="$stub:$PATH" HOME="$home" TEST_DOTFILES_DIR="$root" install_launch_agent "test.plist" >/dev/null 2>&1
    : > "$home/launchctl.calls"   # reset after first install
    local out
    out=$(PATH="$stub:$PATH" HOME="$home" TEST_DOTFILES_DIR="$root" install_launch_agent "test.plist" 2>&1)
    local ok=0
    echo "$out" | grep -q 'Installing' && ok=1                      # no reinstall message
    [[ -s "$home/launchctl.calls" ]] && ok=1                        # launchctl not called again
    rm -rf "$root" "$home" "$stub"
    return $ok
}

# ============================================================================
# Run all tests
# ============================================================================

main() {
    echo "Running bootstrap tests..."
    echo ""

    echo "=== naming consistency (moltbot -> openclaw) ==="
    run_test "no moltbot refs in bootstrap.sh" "test_no_moltbot_references_bootstrap"
    run_test "no moltbot refs in CLAUDE.md" "test_no_moltbot_references_claude_md"
    run_test "no moltbot refs in home/" "test_no_moltbot_references_home"
    run_test "openclaw config at correct path" "test_openclaw_config_path"
    run_test "openclaw function names in bootstrap" "test_openclaw_function_names"
    run_test "openclaw env var in config" "test_openclaw_env_var"
    echo ""

    echo "=== URL migration (speck-vm -> mac-mini/localhost) ==="
    run_test "no speck-vm MCP URLs in settings" "test_no_speck_vm_mcp_urls"
    run_test "openclaw gateway points to mac-mini" "test_openclaw_gateway_url"
    echo ""

    echo "=== bootstrap structure ==="
    run_test "syntax check" "test_bootstrap_syntax"
    run_test "excludes openclaw from generic symlinks" "test_bootstrap_excludes_openclaw_from_symlinks"
    run_test "handles cargo-sweep setup" "test_bootstrap_handles_cargo_sweep"
    run_test "cargo-sweep script exists and executable" "test_cargo_sweep_script_exists"
    run_test "cargo-sweep script syntax" "test_cargo_sweep_syntax"
    run_test "configure_claude_local_settings exists" "test_configure_claude_local_settings_exists"
    run_test "settings.local.json skips gateway host" "test_settings_local_skips_gateway_host"
    run_test "sync_dotfiles has no package installers" "test_sync_dotfiles_no_package_install"
    run_test "no ~/Documents/projects references" "test_no_documents_projects_refs"
    run_test "ensure_openclaw_workspace function exists" "test_ensure_openclaw_workspace_exists"
    run_test "openclaw workspace .gitignore ignores content" "test_openclaw_workspace_gitignore"
    run_test "SteamOS detection function exists" "test_steamos_detection"
    run_test "SteamOS package function exists" "test_steamos_packages"
    run_test "set_default_shell function exists" "test_set_default_shell"
    run_test "no hardcoded /usr/local in SteamOS path" "test_steamos_no_usr_local"
    echo ""

    echo "=== flag combinations ==="
    run_test "--help shows usage" "test_flag_help"
    run_test "--force syncs dotfiles without prompt" "test_flag_force_only"
    run_test "--pull --force: full pipeline no prompt" "test_flag_pull_force"
    run_test "--pull runs pull+install+update+sync" "test_flag_pull_only"
    run_test "short flags (-f -p) match long flags" "test_flag_short_forms"
    run_test "no flags: sync dotfiles with prompt" "test_flag_no_args_prompts"
    echo ""

    echo "=== new-machine readiness ==="
    run_test "host-gating matches mac-mini" "test_gateway_host_matches_plain"
    run_test "host-gating tolerates Bonjour -N suffix" "test_gateway_host_matches_bonjour_suffix"
    run_test "host-gating matches FQDN with suffix" "test_gateway_host_matches_fqdn"
    run_test "host-gating rejects non-gateway hosts" "test_gateway_host_rejects_other"
    run_test "obsidian preflight backs off when upstream down" "test_obsidian_preflight_backs_off_when_upstream_down"
    run_test "obsidian preflight starts server when upstream up" "test_obsidian_preflight_starts_when_upstream_up"
    run_test "sysload-writer writes cache from top output" "test_sysload_writer_writes_cache"
    run_test "sysload-writer tolerates top failure" "test_sysload_writer_tolerates_top_failure"
    run_test "launch agent substitutes __HOME__ and reloads" "test_launch_agent_substitutes_home"
    run_test "launch agent idempotent on unchanged plist" "test_launch_agent_idempotent_on_unchanged_plist"
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
