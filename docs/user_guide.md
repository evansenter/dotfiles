# Agentic Development: A Case Study

A documented experiment in AI-augmented software development using Claude Code.

## The Thesis

The coding harness is solved—Cursor, Copilot, and Claude Code all generate competent code. The leverage multiplier is **workflow integration**: issue tracking, review workflows, cross-session coordination, and session continuity. This document records that investment.

## The Architecture

Five repositories form an integrated system:

```
┌─────────────────┐     events      ┌─────────────────┐
│    dotfiles     │◄───────────────►│   event-bus     │
│  (control plane)│                 │   (coordinate)  │
│                 │                 │                 │
│ - /work         │                 │ - pub/sub       │
│ - /pr-review    │                 │ - channels      │
│ - hooks         │                 │ - SSE stream    │
└────────┬────────┘                 └────────┬────────┘
         │                                   │
         │ commands/agents                   │ real-time events
         │                                   │
         ▼                                   ▼
┌─────────────────┐                 ┌─────────────────┐
│   analytics     │                 │    gemicro      │
│   (insight)     │                 │   (agents)      │
│                 │                 │                 │
│ - tool patterns │                 │ - AgentRunner   │
│ - token usage   │                 │ - Trajectory    │
│ - permissions   │                 │ - MCP transport │
└─────────────────┘                 └────────┬────────┘
                                             │
                                             │ API calls
                                             ▼
                                    ┌─────────────────┐
                                    │   rust-genai    │
                                    │     (SDK)       │
                                    │                 │
                                    │ - Gemini API    │
                                    │ - streaming     │
                                    │ - tool use      │
                                    └─────────────────┘
```

**Control plane (dotfiles):** Workflows, commands, hooks, and agents that Claude Code executes. This is where you encode preferences, quality gates, and coordination patterns. Changes here propagate to all sessions across all repositories.

**Data plane:** The other four repositories handle execution—event coordination, session analytics, agent infrastructure, and API calls.

## The Experiment

**Period:** December 20, 2025 - January 5, 2026 (17 days)

### Repository Activity

| Repository | PRs (open/merged) | Issues (open/closed) | LoC | +/- Lines |
|------------|-------------------|----------------------|-----|-----------|
| dotfiles | 0/114 | 5/51 | 6K Shell | +6.4K/-3.8K |
| gemicro | 0/116 | 29/85 | 30K Rust | +17.5K/-3.7K |
| claude-event-bus | 0/41 | 7/22 | 6K Python | +6.1K/-3.0K |
| claude-session-analytics | 0/30 | 4/19 | 12K Python | +19.0K/-1.8K |
| rust-genai | 1/166 | 6/125 | 37K Rust | +21.1K/-4.6K |
| **Total** | **1/467** | **51/302** | **91K** | **+70K/-17K** |

_Source: `gh pr list`, `gh issue list`, `scc`, `git log --stat`_

### Session Analytics

_Data available since December 30, 2025 (when session logging began via the session-analytics trajectory store)._

| Metric | Value | Source |
|--------|-------|--------|
| Sessions | 258 | `session-analytics-cli sessions --days 17` |
| Tool invocations | 33,073 | `session-analytics-cli frequency --days 17` |
| Input tokens | 10.0M | `session-analytics-cli tokens --days 17` |
| Output tokens | 10.9M | `session-analytics-cli tokens --days 17` |
| Cache read | 9.7B | `session-analytics-cli tokens --days 17` |
| Cache creation | 658M | `session-analytics-cli tokens --days 17` |
| Cache ratio | 15:1 | cache_read / cache_creation |

**Regenerate:** `~/.claude/contrib/repo-stats.sh --days 17 --session-stats`

### Cost since Dec 30th

_Estimated from session analytics (Dec 30+)._

| Metric | Value |
|--------|-------|
| Actual cost | ~£700 |
| API equivalent (Opus pricing) | ~$28,000 |
| Without prompt caching | ~$156,000 |
| Caching savings | 5.6x |

**Actual cost breakdown:** Claude Max subscription ($200/mo) + 2x quota during holiday period + pay-as-you-go overages for parallel sessions.

The 15:1 cache ratio is critical. Prompt caching means the system learns your codebase once and reuses that context constantly. Even with caching, running up to 15 parallel sessions adds up—budget accordingly.

## The Protocol

This is the quality enforcement workflow that `/work <issue>` orchestrates:

| Step | Command | Purpose |
|------|---------|---------|
| 1. Orient | `/status-report` | See recent work, open issues, recommendations |
| 2. Start | `/work <issue>` | Create branch, plan with checkpoints |
| 3. Develop | (work) | Make changes, run tests/linters |
| 4. Self-review | `/pr-review local` | Catch issues before pushing |
| 5. Iterate | (fix) | Address feedback, repeat step 4 |
| 6. Create PR | `/pr-create` | Commit, push, open PR |
| 7. Monitor | `/watch-ci <PR#>` | Background CI monitoring |
| 8. Process feedback | `/pr-review remote` | Handle reviewer comments |
| 9. Merge | (merge) | Merge PR, clean stale branches |
| 10. Reflect | `/improve-workflow` | Surface friction, create issues |

**Step 10 feeds back into the system.** Every completed task potentially improves the workflow for future tasks. This is how the tooling compounds.

**Navigation:**
- Lost context? `/im-lost` shows current position
- Joining existing work? `/work --attach`

## Key Learnings

### 1. Permissions Are Trust Boundaries

Add tools to `settings.json` only after repeated use. The permission prompt surfaces what automation you actually need.

```bash
# Review permission denials weekly
session-analytics-cli permissions --days 7 --min-count 5
```

### 2. Parallel Beats Sequential

One session doing 5 tasks sequentially: 5 hours.
Five sessions doing 1 task each: 1 hour (+ coordination overhead).

The event bus makes coordination overhead small. CI becomes the bottleneck, not Claude.

```bash
/parallel-work start 42  # Creates worktree + tmux session
/parallel-work start 43  # Another parallel PR
```

### 3. Self-Review Works

Before pushing: `/pr-review local`

The model catches issues the model created. Fresh context (just finished vs. planning) plus explicit review checklist changes the mental mode.

### 4. Every Friction Is an Issue

When something is annoying:
1. Don't work around it
2. Create an issue (in the appropriate repo)
3. Let `/improve-workflow` surface it

Most infrastructure improvements came from accumulated friction, not planning.

### 5. System-Wide Dependency Injection

CLAUDE.md files are read on every interaction—a form of dependency injection for AI behavior. A single global file (`~/.claude/CLAUDE.md`) propagates changes to all sessions across all repositories instantly.

This is the highest-leverage investment: one hour improving your global CLAUDE.md saves hundreds of hours of repeated instruction across future sessions.

### 6. Ownership over Skill

Design agents around domain ownership, not capabilities. "An agent responsible for the Auth Service" beats "an agent good at code reviews." Ownership creates:
- Accumulated context across sessions
- Accountability (the agent sees consequences of its decisions)
- Natural boundaries for what belongs in context

Skill-based agents (code-reviewer, test-writer) apply shallow patterns. Domain-owning agents build deep understanding.

### 7. Workflow Integration over Code Generation

The coding problem is solved. Cursor, Copilot, and Claude Code all write competent code. The unsolved problem is integration with your organization's workflow:
- Issue tracking (Buganizer, Jira, GitHub Issues)
- Code review (Critique, Gerrit, GitHub PRs)
- Code search (internal tools, cross-repo grep)
- CI/CD coordination

This system's value isn't better code generation—it's the `/work` command that orchestrates issue→branch→PR→review→merge, the event bus that coordinates parallel sessions, and the hooks that maintain context across compactions.

### 8. Cross-Session Refinement

Different sessions produce different but valid interpretations. Iteration surfaces deeper insights. The synthesis beats either alone.

**Pattern:** Send `help_needed` with a template prompt to another repo's session. They respond with `help_response`. Iterate 2-3 rounds. The final version incorporates perspectives neither session had initially.

**Example:** This document's rust-genai section was refined through 3 rounds of event bus feedback:
- Round 1: "Unified Tool Ecosystem", "Multi-Turn State Management"
- Round 2: Discovered "Compile-Time Conversation Safety" (typestate pattern)
- Round 3: Converged—kept the deep insight, restored good framing

The typestate insight ("impossible states unrepresentable") is deeper than "state management"—a fresh session recognized architectural patterns the original author missed.

**Limitation:** Only works for interactive sessions (hook polls on prompt). Autonomous agents running tool loops won't see responses until completion.

## The Frontier

What's still broken:

### MCP Doesn't Support Push (or Learning Propagation)

The Model Context Protocol is request/response only. Claude can call MCP tools, but servers can't push events to Claude. This blocks two critical capabilities:

**Real-time coordination:** When Session B publishes an event, Session A won't see it until the next prompt triggers a hook poll. Long tool-use loops run blind to external events.

**Learning propagation:** When one agent discovers something (a gotcha, a pattern, a better approach), that knowledge should flow to other agents automatically. Currently learning propagates via:
- Events (ephemeral, require polling)
- GitHub issues (persistent, but manual triage)
- CLAUDE.md edits (manual, requires human approval)

None of these are automatic agent-to-agent learning. The event bus *is* a proper pub/sub system—it could be the solution, but MCP's request/response model prevents push delivery to sessions.

**Workaround:** `prompt-events.sh` hook polls on every user prompt. Works for interactive sessions, but doesn't help autonomous agents.

### Context Compaction Loses Nuance

At ~80% context, Claude Code compacts. Facts survive; reasoning chains and code snippets get summarized.

**Mitigation:** Event bus hooks publish `wip_checkpoint` events with branch, PR, and file state. On session resume, hooks restore this context automatically. `/im-lost` and `[work:N]` todos provide additional navigation.

### No Cross-Machine Coordination

The event bus runs locally. Events don't sync between machines.

**Workaround:** Use GitHub issues as the coordination layer for cross-machine work.

### Rate Limiting During Parallel Work

5+ parallel Opus sessions can hit API rate limits.

**Mitigation:** Stagger session starts, use Sonnet for lighter tasks.

### Limited Self-Evolution

Agents should be able to update their own CLAUDE.md (their "dependency injection") within constraints. Currently:
- Agents can propose changes via issues
- Agents can draft CLAUDE.md edits
- But humans must approve and apply

**Partial implementation:** Running Claude Code in dotfiles/ acts as a swarm controller—it can update CLAUDE.md, and changes propagate to all repos. But two design constraints limit this:
- **No push notifications:** Sessions don't see CLAUDE.md changes until restart
- **No dynamic reload:** Claude Code reads CLAUDE.md at session start only

**Workarounds:** `claude --continue` preserves context across restarts. Event bus can broadcast "reload recommended" events. But true real-time behavioral updates require protocol changes.

**Missing:** Constraint mechanism. Currently we allow *unconstrained* self-modification—if you approve an edit to CLAUDE.md, there are no guardrails on scope, no automatic rollback on regression, no approval thresholds for "large" behavioral changes. The human is the only constraint.

## Getting Started

1. Fork [evansenter/dotfiles](https://github.com/evansenter/dotfiles) and run `./bootstrap.sh`
2. Start with `/status-report` to orient
3. Use `/work <issue>` for guided development
4. Run `/improve-workflow` weekly

## Repository Details

### dotfiles (Control Plane)

The orchestration hub. Key capabilities:

**Workflow Orchestration** — The core loop that turns issues into merged PRs:
- `/work <issue>` orchestrates branch creation, checkpoints, self-review, and cleanup
- `/pr-review local|remote` batches feedback into AskUserQuestion decisions
- `/watch-ci` monitors CI in background, broadcasts results to event bus

**Parallel Development** — Run multiple PRs simultaneously:
- `/parallel-work` creates git worktrees with dedicated tmux sessions
- Event bus coordinates discoveries and blockers across sessions
- Up to 15 parallel Opus sessions—limited by user context-switching overhead and API rate limits, not tooling

**Context Continuity** — Survive compaction and session switches:
- `pre-compact` hook publishes `wip_checkpoint` with branch/PR/file state
- `session-start` hook restores WIP context on resume
- `/im-lost` shows current workflow position when disoriented

**Self-Improvement** — The system improves itself:
- `/improve-workflow` mines session analytics for friction patterns
- `audit-*` agents run background analysis (codebase, tests, issues, docs)
- Every friction becomes an issue; event bus routes to the appropriate repo owner; free agents (with human approval) pick up the work

**Ambient Awareness** — Always know where you are:
- Statusline shows repo/branch, session name, context %, model
- `tmux-status` hook indicates working/waiting state per pane
- Event bus surfaces cross-session activity on each prompt

### claude-event-bus (Coordinate)

Cross-session pub/sub with SQLite persistence. Key capabilities:

**Session Lifecycle** — Sessions announce presence, resume across restarts, and auto-cleanup on death:
- Human-readable IDs (Docker-style: "brave-tiger") for display, UUIDs for APIs
- Client deduplication via `(machine, client_id)` enables seamless session resumption
- Process liveness checking via signals; 24-hour heartbeat timeout

**Broadcast-First Pub/Sub** — All sessions see all events; channels are priority metadata, not routing rules:
- Channel types: `all` (broadcast), `repo:<name>` (most common), `session:<id>` (DMs with notification), `machine:<host>`
- Cursor-based polling with automatic high-water mark tracking
- SSE endpoint `/events/stream` for external consumers (gemicro uses this)

**MCP + CLI Parity** — Every operation available from both interfaces:
- MCP server at `http://localhost:8080/mcp` with 7 tools
- CLI `event-bus-cli` for hooks, scripts, and manual testing
- `--track-state FILE` enables stateful polling in shell scripts

**Observable Logging** — Real-time visibility via colored `tail -f` output:
- Tool color coding (yellow=writes, blue=reads)
- Session ID resolution to human-readable names
- Result summaries (event counts, publishers, timespan)

### claude-session-analytics (Insight)

Session log mining for workflow optimization. Key capabilities:

**Incremental Ingestion** — Transforms JSONL logs into queryable events without re-processing:
- File-level state tracking skips unchanged logs
- Agent tracking (RFC #41) separates main session from Task subagent activity
- FTS5 full-text search across all user messages

**Pattern Detection** — Surfaces friction points automatically:
- Tool sequence mining (e.g., "Read → Edit" happens 847 times)
- Permission gap detection (commands needing auto-approval)
- Rework detection (same file edited 3+ times in 10 minutes)

**Session Intelligence** — Classification and relationship discovery:
- Auto-categorizes sessions: debugging, development, research, maintenance
- Detects parallel sessions (overlapping time windows)
- Finds related sessions by shared files, commands, or temporal proximity

**Git Correlation** — Links commits to sessions based on timing:
- Calculates time-to-commit from session start
- Tracks first commit per session
- Enables commit→session→events traceability

**Raw Signals over Interpretations** — Per RFC #17, returns observable metrics for LLM interpretation:
- `get_session_signals()` returns counts and flags, not outcomes
- Consuming LLM decides meaning (success, abandonment, blocked)
- Avoids over-distillation that loses context

### gemicro (Owner)

CLI agent exploration platform for Gemini API via rust-genai. Key capabilities:

**Soft-Typed Event Extensibility** — Agents define their own events without core changes:
- `AgentUpdate` uses `event_type: String` + `data: JSON` instead of rigid enums
- Only `final_result` is privileged (universal completion signal)
- Unknown event types logged and ignored, never errors (Evergreen philosophy)

**Generic Interceptor Semantics** — Single trait unifies cross-cutting concerns:
- `Interceptor<In, Out>` with universal decision tree: `Allow | Transform(T) | Confirm | Deny`
- Same pattern protects file access, validates user input, or monitors LLM requests
- Path sandbox, audit log, input sanitizer all implement one interface

**ToolSet Permission Boundaries** — Fine-grained access control with inheritance:
- `All | None | Specific(Vec) | Except(Vec) | Inherit | InheritExcept(Vec)`
- Child toolsets resolve against parent: `Except(bash) + InheritExcept(file_write)` → both excluded
- Subagent trees inherit+restrict without duplicating security logic

**Orchestration Resource Budgets** — Subagent execution within explicit limits:
- Global + per-parent concurrent limits via semaphores
- Shared timeout budget across entire execution tree
- Max depth prevents infinite nesting; `child_context()` auto-tracks hierarchy

**Agent-Owned Progress Reporting** — Streaming without introspection:
- Agents provide `ExecutionTracking` implementations
- CLI calls `tracker.status_message()`—meaningful for any agent type
- Deep Research tracks sub-queries; Developer tracks tool calls; SimpleQA uses default

### rust-genai (SDK)

Rust client for Google's Gemini Interactions API. Key capabilities:

**Compile-Time Conversation Safety** — Typestate pattern prevents API misuse before code runs:
- Builder states (`FirstTurn`, `Chained`, `StoreDisabled`) enforce valid method sequences at compile time
- `CanAutoFunction` trait makes impossible states unrepresentable
- Undocumented API behaviors codified in types, not runtime checks

**Unified Tool Ecosystem** — Single API surface for client and server-side tools:
- `#[tool]` macro: compile-time stateless functions with automatic schema generation
- `ToolService` trait: runtime stateful tools sharing DB pools/API clients via Arc cloning
- Built-in tools (Google Search, Code Execution, File Search) configured the same way as custom functions

**Evergreen Soft-Typing** — Graceful API evolution without breaking deployments:
- `Unknown { <context>_type, data }` variants preserve raw JSON when Google adds new types
- `ENUM_WIRE_FORMATS.md` captures empirically-tested serialization (docs sometimes lie)
- Non-exhaustive enums with full roundtrip fidelity

**Resumable Streaming** — Network-resilient real-time responses:
- Each event carries `event_id`; resume from exact failure point without re-executing functions
- `create_stream_with_auto_functions()` streams intermediate results during multi-turn loops

## Further Reading

- [Multi-Agent Research Discussion](multi-agent-research-discussion.md)
- [Multi-Agent Ecosystem Coordination](multi-agent-ecosystem-coordination.md)
- [Event Bus Guide](../home/.claude/contrib/README.md)

---

_This system was built with Claude Code, using Claude Code. The recursive nature isn't coincidental—the best way to improve AI tooling is to use it intensively and let friction drive improvements._

_Session analytics data available since December 30, 2025._
