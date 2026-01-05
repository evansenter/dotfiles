# How to Be an Effective Developer with AI

An opinionated guide from someone who's spent two weeks building a multi-agent coordination system with Claude Code.

## The Core Thesis

AI coding assistants are not productivity tools. They're **leverage multipliers**. The more you invest in teaching them your workflows, preferences, and patterns, the more they amplify your output. This guide documents what that investment looks like in practice.

## What I Built (And Why It Matters)

Over 14 days in December 2025, I transformed a dormant dotfiles repository (last meaningful commit: 2021) into a sophisticated multi-agent coordination hub. The numbers:

| Metric | Value |
|--------|-------|
| Sessions | 165 |
| Tool invocations | 24,587 |
| Input tokens | 4.1M |
| Output tokens | 4.8M |
| Cache read tokens | 5.4B |
| PRs merged | 140+ |
| Lines of code | 86K across 5 repos |

**Cache efficiency**: That 5.4B cache read vs 343M cache creation (16:1 ratio) is the key insight. The system learns your codebase once and reuses that context constantly.

### The Five Repositories

1. **dotfiles** (6K Shell) - Meta-orchestration hub
   - Started: Traditional zsh/tmux configs from 2011
   - Now: 12 custom commands, 6 agents, 3 lifecycle hooks, statusline integration

   **Why it matters**: This is the control plane for AI-augmented development. Instead of typing ad-hoc instructions to Claude Code, you define reusable workflows that encode your preferences, quality gates, and coordination patterns. The investment compounds—every workflow improvement benefits all future sessions across all repositories.

   - **Key features**:
     - `/work` - Full workflow orchestration with checkpoints and auto-reflection
     - `/pr-review local|remote` - Batch code review with AskUserQuestion decisions
     - `/parallel-work` - Git worktree management with tmux auto-launch
     - `/status-report` - Session-aware orientation with recommendations
     - `/improve-workflow` - Data-driven suggestions from session analytics
     - Session hooks - Auto-register/unregister with event bus, poll events on prompt
     - User-defined agents - Custom autonomous tasks with separate context windows
     - Statusline - Ambient awareness (repo/branch, session name, context %, model)
     - Bootstrap system - Idempotent symlinks, MCP server installation, LaunchAgents
     - Dark mode theme switching for btop via `dark-notify`
   - **Upcoming**: Trajectory integration for multi-session debugging (#57)

2. **rust-genai** (33K Rust) - Gemini Interactions API SDK
   - Started: From scratch, exploring Gemini API in Rust
   - Now: Full Gemini Interactions API (3.0+) implementation with streaming, tool use, vision

   **Why it matters**: Google's Gemini models offer competitive performance at lower cost, but the official SDKs lag behind the API. This library provides first-class Rust support for the Interactions API (3.0+), enabling high-performance agentic applications with proper streaming, tool use, and vision—features that are awkward or missing in alternatives.

   - **Key features**:
     - Gemini Interactions API - Native Rust SDK for Google's latest API surface
     - Streaming responses - `ChatResponseStream` with typed events (content, tool calls, usage)
     - Function calling - Full tool use with `tool_choice` (auto/any/none/specific)
     - Vision support - Multi-modal messages with image URLs and base64
     - Response caching - Caching layer for development and testing
     - Retry logic - Exponential backoff with configurable max retries
     - Model configuration - Gemini model variants with parameter tuning
     - Usage tracking - Token counts (input, output, cache read/write) per response
     - `LOUD_WIRE` debug mode - Raw request/response logging for debugging
     - Comprehensive examples - 30+ examples covering all features
   - **Upcoming**: 13 open issues including enhanced error handling, API coverage expansion

3. **gemicro** (30K Rust) - MCP server framework
   - Started: Exploration of Gemini-specific features
   - Now: Full MCP implementation (async + sync) with request batching, session management

   **Why it matters**: MCP (Model Context Protocol) is the emerging standard for tool integration, but building agents that use MCP servers is complex. gemicro provides the missing layer: `AgentRunner` for multi-turn execution, `Trajectory` for debugging and evaluation, and soon push notification support that bypasses MCP's request/response limitation entirely.

   - **Key features**:
     - `AgentRunner` - Multi-turn agent execution with phases and tool orchestration
     - `Trajectory` - Recording/replay of agent runs for debugging and evaluation
     - `TrajectoryDataset` - Batch evaluation across saved trajectories
     - MCP transports - Both async (`AsyncMcpTransport`) and sync implementations
     - Request batching - Efficient tool call grouping with deduplication
     - Session management - MCP session lifecycle with capability negotiation
     - REPL mode - Interactive agent development with `!save`/`!load`/`!replay`
     - `HubCoordination` - SSE connection to claude-event-bus for real-time events
     - Mock clients - `MockLlmClient` for deterministic testing with recorded responses
     - Structured observability - Integration-ready spans for distributed tracing
   - **Upcoming**: **Push notification injection via SSE** (#196) - the key to real-time event delivery; HubCoordination already connects to event bus, just needs `execute_with_coordination()` to inject events into agent update stream

4. **claude-event-bus** (6K Python) - Cross-session coordination
   - Started: From scratch Dec 30
   - Now: SQLite-backed pub/sub system, CLI + MCP server, channels, session lifecycle

   **Why it matters**: Running multiple Claude Code sessions in parallel is powerful, but they're blind to each other by default. The event bus enables coordination: Session A announces "auth feature done," Session B receives it and integrates. Discoveries, blockers, and CI results propagate automatically. This turns isolated sessions into a collaborating swarm.

   - **Key features**:
     - Channel-based pub/sub - 4 channel types (all/repo/machine/session) for targeted messaging
     - Session lifecycle - Register/unregister with heartbeat-based cleanup (30s timeout)
     - Cursor-based polling - Efficient event retrieval with "since cursor" semantics
     - MCP server - Full tool suite for Claude Code integration
     - CLI - `event-bus-cli` for shell scripting and manual testing
     - SSE endpoint - `/events/stream` for external consumers (gemicro uses this)
     - macOS notifications - `notify()` tool for user alerts
     - SQLite storage - Persistent events with FTS5 search capability
     - Client deduplication - `(machine, client_id)` prevents duplicate registrations
     - LaunchAgent - Auto-start on macOS login
   - **Upcoming**: Multi-machine via Tailscale (#3, blocked), SSE for MCP when supported (#10, blocked on MCP spec)

5. **claude-session-analytics** (11K Python) - Workflow insights
   - Started: From scratch Dec 31
   - Now: JSONL log parsing, tool sequences, failure analysis, permission gap detection

   **Why it matters**: Claude Code generates detailed session logs, but they're write-only by default. This tool mines those logs for actionable insights: which commands need auto-approval, which tool sequences indicate friction, which sessions have high error rates. The `/improve-workflow` command uses this data to suggest concrete improvements—making the system self-optimizing.

   - **Key features**:
     - Tool frequency analysis - Usage counts with breakdowns by Bash command, Skill, Task agent type
     - Tool sequence mining - Find common patterns (e.g., "Read → Edit" happens 847 times)
     - Permission gap detection - Commands frequently requiring approval that could be auto-allowed
     - Failure analysis - Error rates, rework detection (same file edited multiple times)
     - Session classification - Categorize as debugging, development, research, maintenance
     - Git commit correlation - Link commits to sessions that created them
     - FTS5 message search - Full-text search across all user messages
     - Trend analysis - Compare periods to detect workflow changes
     - Handoff context - Recent activity summary for session continuity
     - MCP server + CLI - Both `mcp__session-analytics__*` tools and `session-analytics-cli`
   - **Upcoming**: No open issues - stable and feature-complete for current needs

## The Core Workflow

Before diving into accelerants, here's the 10-step workflow that ties everything together. This is what `/work <issue>` orchestrates:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  1. Orient          │  /status-report                                   │
│                     │  See recent work, open issues, recommendations    │
├─────────────────────┼───────────────────────────────────────────────────┤
│  2. Start work      │  /work <issue-number>                             │
│                     │  Create tracked plan with explicit checkpoints    │
├─────────────────────┼───────────────────────────────────────────────────┤
│  3. Develop         │  Make changes, run tests/linters                  │
│                     │  Claude tracks progress via [work:N] todos        │
├─────────────────────┼───────────────────────────────────────────────────┤
│  4. Self-review     │  /pr-review local                                 │
│                     │  Catch issues before pushing (batch decisions)    │
├─────────────────────┼───────────────────────────────────────────────────┤
│  5. Iterate         │  Address feedback, repeat step 4 until clean      │
│                     │                                                   │
├─────────────────────┼───────────────────────────────────────────────────┤
│  6. Create PR       │  /pr-create                                       │
│                     │  Commit, push, open PR in one step                │
├─────────────────────┼───────────────────────────────────────────────────┤
│  7. Monitor CI      │  /watch-ci <PR#>                                  │
│                     │  Background monitoring with notification          │
├─────────────────────┼───────────────────────────────────────────────────┤
│  8. Process feedback│  /pr-review remote                                │
│                     │  Handle reviewer comments (batch decisions)       │
├─────────────────────┼───────────────────────────────────────────────────┤
│  9. Merge & cleanup │  Merge PR + /commit-commands:clean_gone           │
│                     │  Remove stale local branches                      │
├─────────────────────┼───────────────────────────────────────────────────┤
│ 10. Reflect         │  /improve-workflow (auto-runs after merge)        │
│                     │  Surface friction, create infrastructure issues   │
└─────────────────────┴───────────────────────────────────────────────────┘
```

**The critical insight**: Step 10 feeds back into the system. Every completed task potentially improves the workflow for future tasks. This is how the tooling compounds.

**Navigation aids**:
- Lost context? Run `/im-lost` to see current workflow position
- Joining existing work? Run `/work --attach` to pick up from current checkpoint
- Active sessions show `[work:N]` in todo list for progress tracking

## Key Developer Accelerants

### 1. Workflow Commands Over Ad-Hoc Instructions

Stop typing instructions. Define reusable commands.

**Bad**: "Please check the git status, read the issue, create a branch, and start working on it"

**Good**: `/work 42`

My `/work` command handles:
- Reading the issue and understanding requirements
- Creating appropriately-named branches
- Planning with explicit checkpoints
- Self-review before pushing
- CI monitoring
- Post-merge cleanup and workflow improvement suggestions

Other high-leverage commands:
- `/status-report` - Orient at session start (what's been done, what's pending)
- `/pr-review local|remote` - Self-review or process reviewer feedback
- `/improve-workflow` - Data-driven suggestions from session analytics
- `/parallel-work` - Manage concurrent PRs via git worktrees + tmux

### 2. Session Lifecycle Hooks

Automate the ceremony of starting and ending work.

```bash
# ~/.claude/hooks/session-start.sh
# Auto-register with event bus, fetch recent activity
event-bus-cli register --name "$(basename $PWD)/$(git branch --show-current)"
event-bus-cli events --since 10m --format summary
```

```bash
# ~/.claude/hooks/session-end.sh
# Clean unregister so other sessions see accurate state
event-bus-cli unregister
```

```bash
# ~/.claude/hooks/prompt-events.sh (runs on every prompt)
# Check for DMs, CI notifications, help requests
event-bus-cli events --cursor "$CURSOR" --session-filter
```

### 3. Cross-Session Coordination

When you run multiple Claude Code sessions in parallel:

**The Problem**: Sessions don't know about each other. Session A finishes work that Session B was waiting for. Session B keeps working on a now-outdated assumption.

**The Solution**: Event bus for broadcast coordination.

```
# Session A finishes auth feature
mcp__event-bus__publish_event(
  event_type="task_completed",
  payload="Auth feature merged - you can integrate now",
  session_id="<your-session-id>",
  channel="repo:my-app"
)

# Session B receives notification, adjusts approach
```

Channel types:
- `all` - Broadcast everywhere (rare, major announcements only)
- `repo:<name>` - Most common, coordinate within codebase
- `machine:<host>` - Cross-repo local coordination
- `session:<id>` - Direct messages

Event types I actually use:
- `task_completed` / `task_started` - Coordinate handoffs
- `ci_completed` - CI results (auto-published by `/watch-ci`)
- `gotcha_discovered` - Non-obvious issues (save other sessions time)
- `help_needed` - Request assistance from parallel sessions

### 4. Parallel Development with Worktrees

Don't context-switch between branches. Run them simultaneously.

```bash
/parallel-work start 42  # Creates worktree, opens tmux session
/parallel-work start 43  # Another worktree, another session
/parallel-work list      # See all active parallel work
```

Each worktree gets:
- Isolated working directory
- Own Claude Code session (separate context)
- Event bus coordination
- Independent CI pipelines

I regularly run 5-8 parallel sessions overnight, each working on different issues.

### 5. Self-Improving Workflows

The workflow should improve itself.

```bash
/improve-workflow
```

This command:
1. Queries session analytics (tool frequency, sequences, failures)
2. Identifies friction patterns (rework, permission denials, repeated failures)
3. Suggests improvements categorized as:
   - **Local** (this repo's CLAUDE.md)
   - **Global** (dotfiles for all repos)
4. Creates issues for infrastructure gaps in appropriate repos

Example output:
```
## Suggested Improvements

### Global (dotfiles)
- [ ] Add `timeout` to allowed Bash commands (blocked 12 times last week)
- [ ] Create /audit-flaky-tests command (3 flaky test patterns found)

### Local (rust-genai)
- [ ] Document the streaming response pattern in CLAUDE.md
- [ ] Add example for multi-turn tool use
```

### 6. User-Defined Agents

For autonomous background tasks, define agents:

```markdown
---
name: audit-codebase
description: Audits for anti-patterns and Evergreen violations
model: opus
---

You are a code auditor. Scan the codebase for...
```

Available agents:
- `audit-codebase` - Code quality, anti-patterns, Evergreen violations
- `audit-tests` - Test redundancy, staleness, coverage gaps
- `audit-issues` - Issue triage, priority alignment, staleness
- `audit-docs` - CLAUDE.md, README, and documentation accuracy
- `status-report` - Repo status with recent work and recommendations
- `summarize-work` - Summarize current branch work for PR creation

Agents get their own context window (not affected by main conversation compaction).

### 7. Statusline for Ambient Awareness

Don't lose track of context:

```
[repo/branch | session_name | 42% ctx | opus]
```

Shows:
- Current repo and branch
- Event bus session name
- Context window usage
- Active model

When context hits 60%+, you know compaction is coming. Plan accordingly.

### 8. Interactive Code Review via AskUserQuestion

The `/pr-review` workflow uses `AskUserQuestion` to create a batch decision interface for code review feedback. This is how I handle all code review - both self-review and processing external comments.

**The Pattern**:

1. **Gather feedback** - Claude identifies issues (self-review) or fetches reviewer comments (remote)
2. **Categorize by severity** - Critical, Important, Suggestion
3. **Form opinions** - Claude assesses each item's validity given context
4. **Present batch decisions** - All items shown via AskUserQuestion with options

**Example `/pr-review local` flow**:

```
## Code Review Findings

### Critical
1. SQL injection vulnerability in user_search() - raw string interpolation
   My opinion: Valid, must fix before merge

### Important
2. Missing error handling for network timeout in fetch_data()
   My opinion: Valid, edge case worth handling
3. Function exceeds 50 lines, could be decomposed
   My opinion: Borderline - function is linear, decomposition might hurt readability

### Suggestions
4. Consider using dataclass instead of dict for UserConfig
   My opinion: Good idea but scope creep for this PR

---
For each item, choose: Implement | Skip | Defer (create issue)
```

**Why AskUserQuestion over back-and-forth chat**:

- **Batch processing** - Review all findings at once, make decisions in parallel
- **Preserved context** - Your choices are recorded, Claude acts on them immediately
- **Explicit tradeoffs** - "Skip" is a valid choice when you disagree with feedback
- **Defer option** - Creates GitHub issues for legitimate-but-not-now items

**Key insight**: Claude has context on why the code was written that way. Automated reviewers don't. The opinion field helps you quickly assess whether feedback is valid or a false positive.

**The `/pr-review remote` variant**:

Same pattern, but fetches comments from GitHub PR reviewers:
```bash
/pr-review remote  # After CI passes
```

This processes:
- Automated reviewer comments (claude-review, CodeRabbit, etc.)
- Human reviewer comments
- Inline code suggestions

Each gets categorized, opinionated, and batched for decision.

## Opinionated Principles

### 1. Invest in CLAUDE.md

Your project-level CLAUDE.md is the highest-leverage documentation you'll write. It's read on every interaction.

**Include**:
- Allowed autonomous decisions (don't ask, just do)
- Required discussion points (ask before proceeding)
- Quality gates (what to run before pushing)
- Workflow patterns (how PRs work, how issues work)
- Common commands and their meaning

**Don't include**:
- Generic coding standards (the model knows those)
- Obvious requirements ("write good code")
- Lengthy explanations (be concise, this burns context)

### 2. Permissions Are Trust Boundaries

Add tools to `settings.json` only after you've used them repeatedly. The permission prompt is a feature, not a bug - it surfaces what automation you actually need.

Session analytics tracks permission denials. Review them weekly:
```
mcp__session-analytics__get_permission_gaps(days=7, min_count=5)
```

### 3. Every Friction Is an Issue

When something is annoying:
1. Don't just work around it
2. Create an issue (in the appropriate repo)
3. Tag it for `/improve-workflow` to surface

Most of my infrastructure improvements came from accumulated friction, not grand planning.

### 4. Parallel Work Beats Sequential Work

One session doing 5 tasks sequentially: 5 hours
Five sessions doing 1 task each: 1 hour (+ coordination overhead)

The coordination overhead is smaller than you think when you have event bus coordination. CI becomes the bottleneck, not Claude.

### 5. Let Claude Self-Review

Before pushing, always: `/pr-review local`

The model catches issues the model created. Sounds circular, but works:
- Fresh context (just finished work vs. planning it)
- Explicit review checklist (different mental mode)
- Pattern recognition (sees anti-patterns it tends to generate)

### 6. CI Is the Ground Truth

Never declare "ready to merge" until:
1. CI passes
2. `/pr-review remote` processed (automated reviewers leave comments)
3. All critical/important feedback addressed

CI failures are information. Run `/watch-ci` immediately after pushing.

### 7. Document Discoveries via Event Bus

When you learn something non-obvious:
```
mcp__event-bus__publish_event(
  event_type="gotcha_discovered",
  payload="SQLite datetime needs explicit adapters in Python 3.12+",
  session_id="<your-session-id>",
  channel="repo:claude-session-analytics"
)
```

Future sessions incorporate these discoveries via `/improve-workflow`.

## Cost Considerations

This workflow is not cheap. 14 days of aggressive parallel development:
- ~9M tokens processed
- 5.4B cache reads (prompt caching is essential)

Without prompt caching, this would be roughly 60x more expensive. Enable it.

The ROI equation:
- Time saved: ~100 hours of manual work
- Quality improvement: More consistent, better tested, better documented
- Learning acceleration: Model discovers patterns I wouldn't have noticed

Whether that's worth it depends on what you're building and your hourly rate.

## Remaining Friction Points

This system isn't perfect. Here's what still causes friction:

### MCP Doesn't Support Push Notifications

The Model Context Protocol is request/response only. Claude can call MCP tools, but MCP servers can't push events to Claude. This creates a fundamental limitation:

**The Problem**: When Session B publishes an event, Session A can't receive it until Session A's next prompt triggers a hook that polls the event bus.

**Current Workaround**: The `prompt-events.sh` hook polls on every user prompt. But if you're in a long tool-use loop, you won't see events until it completes.

**What Would Fix It**: MCP server-sent events or websocket support. Until then, polling is the only option.

### Context Compaction Loses Working Memory

When context hits ~80%, Claude Code compacts the conversation. This preserves facts but loses nuance:

- Reasoning chains get summarized
- Code snippets get truncated
- Multi-step debugging context flattens

**Mitigation**: The `/im-lost` command and `[work:N]` todos help reconstruct context, but it's not seamless.

### Agent Handoffs Are Implicit

When you launch a Task agent (like `Explore` or `Plan`), there's no explicit handoff protocol:

- Parent doesn't know agent's intermediate state
- Agent can't ask parent for clarification
- No structured result schema

**Current Workaround**: Detailed prompts and hoping the agent returns what you need.

### No Cross-Machine Coordination

The event bus runs locally. If you have Claude Code on two machines:

- Events don't sync between them
- Session state is machine-local
- No remote database option (yet)

**In-progress work**: The infrastructure for multi-machine coordination exists:
- claude-event-bus [#3](https://github.com/evansenter/claude-event-bus/issues/3): Tailscale support for network binding + auth
- claude-event-bus [#10](https://github.com/evansenter/claude-event-bus/issues/10): SSE support when MCP adds server-push

However, both are **blocked by the MCP push notification limitation** above. Without push, remote event bus is just more latent polling—low value.

**The path forward**: gemicro [#196](https://github.com/evansenter/gemicro/issues/196) adds `execute_with_coordination()` that injects external events via SSE directly into the agent's update stream, bypassing MCP entirely. This enables real-time coordination without waiting for MCP spec changes.

**Current workaround**: Use GitHub issues as the coordination layer for cross-machine work.

### Statusline Cache Lag

The statusline uses a 30-second cache to avoid hammering the event bus. This means:

- New session registrations take up to 30s to appear
- Event bus status can be slightly stale

**Workaround**: Run `/event-bus-status` for real-time data.

### Rate Limiting During Parallel Work

Running 5+ parallel sessions can hit API rate limits, especially with Opus:

- Requests get queued or rejected
- Cache misses during high load
- Unpredictable latency spikes

**Mitigation**: Stagger session starts, use Sonnet for lighter tasks, monitor usage.

---

These are active pain points. If you solve any of them, please contribute back.

## Getting Started

1. **Fork my dotfiles** - https://github.com/evansenter/dotfiles
   - Run `./bootstrap.sh` to install
   - Customize `home/.claude/CLAUDE.md` for your preferences

2. **Start with `/status-report`** - Orient yourself in a new codebase

3. **Use `/work <issue>` religiously** - The checkpoints prevent drift

4. **Run `/improve-workflow` weekly** - Let the system tell you what's broken

5. **Graduate to parallel work** - `/parallel-work start <issue>` once you trust the workflow

## Further Reading

- [Multi-Agent Research Discussion](multi-agent-research-discussion.md) - Deep dive on agent swarm architectures
- [Multi-Agent Ecosystem Coordination](multi-agent-ecosystem-coordination.md) - Synthesis of coordination challenges
- [Event Bus Guide](../home/.claude/contrib/README.md) - Implementation details
- [Session Analytics Guide](../home/.claude/contrib/README.md) - How insights are generated

## Acknowledgments

This system was built entirely with Claude Code, using Claude Code. The recursive nature isn't coincidental - the best way to improve AI tooling is to use it intensively and let friction drive improvements.

Every command, hook, and pattern documented here was discovered through actual use, not planned upfront. Start simple, observe friction, automate ruthlessly.
