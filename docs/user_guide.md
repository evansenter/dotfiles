# Agentic Development: A Case Study

A documented experiment in AI-augmented software development using Claude Code.

## The Thesis

The coding harness is solved—Cursor, Copilot, and Claude Code all generate competent code. The leverage multiplier is **workflow integration**: issue tracking, review workflows, cross-session coordination, and session continuity.

This document records an experiment in getting multi-agent-like behavior **without building a custom agent framework**. The "agents" are Claude Code sessions. Each session owns a repository. The human orchestrates via event bus and slash commands. The goal isn't to build the best agent platform—it's to show what's achievable with Claude Code + workflow infrastructure.

## The Architecture

### The Runtime System

Three repositories power this case study:

```
                        ┌─────────────────────────────────────┐
                        │          Claude Code Sessions        │
                        │  (the actual "agents" in this study) │
                        └─────────────────┬───────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
           ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
           │    dotfiles     │   │   event-bus     │   │   analytics     │
           │ (control plane) │◄─►│  (coordinate)   │──►│    (insight)    │
           │                 │   │                 │   │                 │
           │ - CLAUDE.md     │   │ - pub/sub       │   │ - tool patterns │
           │ - /work, hooks  │   │ - channels      │   │ - token usage   │
           │ - commands      │   │ - poll-based    │   │ - permissions   │
           └─────────────────┘   └─────────────────┘   └─────────────────┘
```

**What "agent" means here:** A Claude Code session + CLAUDE.md + repo ownership. Not autonomous execution—human-orchestrated via slash commands and event bus. Each session builds context within its repo; coordination happens through event bus broadcasts and DMs.

**dotfiles (control plane):** Workflows, commands, hooks that Claude Code executes. Changes here propagate to all sessions across all repositories instantly.

**event-bus (coordinate):** Cross-session communication via polling. Sessions announce progress, discoveries, and blockers.

**analytics (insight):** Mines session logs for patterns. Powers `/improve-workflow` suggestions.

### Projects Under Development

Two additional repositories are being built during this experiment. They don't power the current workflow—Claude Code sessions are the "agents" today—but represent where we're headed.

**Current state:**
```
┌─────────────────┐         ┌─────────────────┐
│    gemicro      │────────►│   rust-genai    │
│ (Gemini agents) │         │  (Gemini SDK)   │
│                 │         │                 │
│ - AgentRunner   │         │ - Gemini API    │
│ - Trajectory    │         │ - streaming     │
│ - MCP transport │         │ - tool use      │
└─────────────────┘         └─────────────────┘
```

**Future goal:** Replace Claude Code sessions with gemicro agents:

```
                        ┌─────────────────────────────────────┐
                        │         gemicro Agents               │
                        │  (autonomous, repo-owning agents)    │
                        └─────────────────┬───────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
           ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
           │    dotfiles     │   │   event-bus     │   │   analytics     │
           │ (control plane) │◄─►│  (coordinate)   │──►│    (insight)    │
           └─────────────────┘   └─────────────────┘   └─────────────────┘
                    │                     ▲
                    │                     │ SSE push (when MCP supports it)
                    │                     │
                    └─────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   rust-genai    │
                    │  (Gemini SDK)   │
                    └─────────────────┘
```

Same coordination infrastructure, but agents run autonomously instead of human-orchestrated.

**Two blockers to this future:**

1. **MCP push notifications** — Until MCP supports server-initiated messages, agents must poll the event bus themselves.

2. **Owned infrastructure** — Claude Code is a black box. We're hacking around its limitations with hooks (prompt injection), state files (`/work` resumption after compaction), and CLAUDE.md (behavioral contracts). With gemicro, we own the entire stack and can iterate on the agent architecture directly—add memory layers, change context management, modify tool execution patterns.

## The Experiment

**Period:** December 20, 2025 - January 5, 2026 (17 days)

### The Methodology: Cross-Session Refinement

This document itself is an experiment result. Each Repository Details section was generated by that repo's owner-session, not by a central author. The process:

1. Send `help_needed` event with a template prompt to another repo's session
2. That session explores their codebase first, then writes their own section
3. Iterate 2-3 rounds, explicitly asking "what's architecturally novel, not just useful?"
4. The final version incorporates perspectives the original author missed

**Result:** Every repo discovered patterns invisible to the original author:
- rust-genai: "Compile-Time Conversation Safety" (typestate pattern)—I had written "state management"
- event-bus: Corrected "SSE stream" to "poll-based"—I was wrong about my own architecture
- gemicro: "Generic Interceptor Semantics"—a unifying abstraction I hadn't named

**Limitation:** Only works for interactive sessions. Autonomous agents running tool loops won't see responses until completion.

### Repository Activity

**Runtime System:**

| Repository | PRs (open/merged) | Issues (open/closed) | LoC | +/- Lines |
|------------|-------------------|----------------------|-----|-----------|
| dotfiles | 0/114 | 5/51 | 6K Shell | +6.4K/-3.8K |
| claude-event-bus | 0/41 | 7/22 | 6K Python | +6.1K/-3.0K |
| claude-session-analytics | 0/30 | 4/19 | 12K Python | +19.0K/-1.8K |

**Projects Under Development:**

| Repository | PRs (open/merged) | Issues (open/closed) | LoC | +/- Lines |
|------------|-------------------|----------------------|-----|-----------|
| gemicro | 0/116 | 29/85 | 30K Rust | +17.5K/-3.7K |
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

Different sessions produce different but valid interpretations. The synthesis beats either alone. See "The Methodology" section above for details.

**Key insight:** The framing "what's architecturally novel, not just useful?" consistently produced deeper insights than "describe your features."

### 9. Self-Play API Testing

Before shipping an API, try to reach an actionable conclusion using only that API. If you get stuck, the API has a drill-down gap.

**Example:** session-analytics' RFC #49 work used this pattern. "821 Bash errors" → can I find out *which* commands? If `get_tool_frequency()` only returns counts, add `analyze_failures()`. If that only returns categories, add `get_session_events(tool='Bash')`.

Every aggregate should lead to source data. Self-play catches missing endpoints before users hit them.

## What to Build Next

Prioritized improvements based on impact and feasibility:

### Priority 1: Wire Event-Bus + Session-Analytics

**Repo:** claude-session-analytics | **Blocks:** Learning propagation

Currently event-bus and session-analytics are parallel systems. If session-analytics ingested event-bus events, `gotcha_discovered` would become queryable. Then `/improve-workflow` could surface: "3 sessions discovered gotchas in auth code this week—here they are."

This closes the learning propagation gap without waiting for MCP push support.

### Priority 2: Agent Memory Layer

**Repo:** gemicro | **Blocks:** Cross-run learning

Agents are stateless. A DeepResearchAgent that discovers a useful decomposition pattern doesn't share it with future runs. Persist useful patterns across runs—make agents that learn.

### Priority 3: Online Evaluation Hooks

**Repo:** gemicro | **Blocks:** Quality measurement

Trajectory replay enables offline testing, but no online evaluation—measuring agent quality *during* execution. Add scoring hooks that run mid-agent, not just post-mortem.

### Priority 4: Wire Format Fuzzer

**Repo:** rust-genai | **Blocks:** API reliability

Google's docs drift from reality. Build a fuzzer that generates requests and compares actual vs expected responses. CI job that detects when our types diverge from the real API.

## The Frontier

What's still broken (not yet actionable):

### MCP Doesn't Support Push (or Learning Propagation)

The Model Context Protocol is request/response only. Claude can call MCP tools, but servers can't push events to Claude. This blocks two critical capabilities:

**Real-time coordination:** When Session B publishes an event, Session A won't see it until the next prompt triggers a hook poll. Long tool-use loops run blind to external events.

**Learning propagation:** When one agent discovers something (a gotcha, a pattern, a better approach), that knowledge should flow to other agents automatically. The flow exists but with latency:
- `/work` → session activity → session-analytics ingests → `/improve-workflow` queries → CLAUDE.md updated → future sessions inherit

The gap is **latency**, not absence:
- End-of-session (not real-time)
- Human-gated (requires approval)
- Indirect (goes through CLAUDE.md, not session-to-session)

**Potential improvement:** If session-analytics ingested event-bus data, `gotcha_discovered` events would become queryable. Then `/improve-workflow` could surface: "3 sessions discovered gotchas in auth code this week." Currently event-bus and session-analytics are parallel systems—wiring them together would close the real-time gap with a structured batch process.

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

### Correlation Without Causation

Session analytics can tell you "821 Bash errors happened" but not "this error caused the session to fail." Temporal correlation isn't causation. Would need explicit dependency tracking or inference models to answer:
- "Was this rework triggered by that test failure?"
- "Did this discovery prevent future errors?"

### Broadcast Scalability Ceiling

The event bus broadcasts all events to all sessions. At Claude Code scale (5-15 sessions), this is fine. At 1000s of sessions, you'd need real pub/sub with subscriptions. The architecture has a ceiling—deliberately accepted for simplicity.

### External API Documentation Drift

Google's Gemini docs are sometimes wrong. `ENUM_WIRE_FORMATS.md` in rust-genai documents empirically-tested serialization (e.g., `ThinkingSummaries` requires `"THINKING_SUMMARIES_AUTO"`, not `"auto"` as docs claim). No automated verification that docs match reality—manual testing is the only ground truth.

### Typestate Complexity Ceiling

Builder states (`FirstTurn`, `Chained`, `StoreDisabled`) prevent API misuse at compile time, but adding new constraints requires combinatorial state explosion. There's a limit to what's expressible without dependent types. Eventually you hit "too many type parameters."

### Offline-Only Evaluation

Agent evaluation via `TrajectoryDataset` + `MockLlmClient` enables replay testing, but no online evaluation—measuring agent quality *during* execution, not just after. You can't score a live agent's decisions mid-run.

## Takeaway

**The control plane is the product.**

The coding problem is solved—Cursor, Copilot, and Claude Code all generate competent code. What's unsolved is workflow integration: issue tracking, review coordination, session continuity, cross-session learning. dotfiles (CLAUDE.md, hooks, commands) is where that integration lives and where improvements compound.

This experiment proves multi-agent-like behavior is achievable from single-agent tools. You don't need a custom agent framework. You need:
1. **Behavioral contracts** (CLAUDE.md) that propagate to all sessions
2. **Coordination primitives** (event bus) that enable cross-session awareness
3. **Feedback loops** (analytics → `/improve-workflow` → CLAUDE.md) that make the system self-improving

**What didn't work well:**
- **Push notification workarounds are annoying.** `prompt-events.sh` polls on every prompt, but autonomous tool loops run blind. Real-time coordination requires protocol changes.
- **Session-analytics utility is emerging.** The event-bus integration (Priority 1 above) would close the learning propagation gap. That said—the human's role analysis in this document came directly from session-analytics queries, demonstrating the self-play pattern working in practice.

**For agent researchers:** The human in this system makes low-bandwidth, high-leverage decisions at checkpoints. Session analytics shows 39% of tokens go to Task subagents, 61% to main sessions—but the human's input is sparse checkpoint approvals and course corrections. The leverage ratio is extreme: a few words of guidance shapes hours of autonomous work.

The limiting factor isn't code generation. It's the integration surface between AI capabilities and organizational workflow.

## Getting Started

1. Fork [evansenter/dotfiles](https://github.com/evansenter/dotfiles) and run `./bootstrap.sh`
2. Start with `/status-report` to orient
3. Use `/work <issue>` for guided development
4. Run `/improve-workflow` weekly

## Repository Details

_Each section below was written by that repository's owner-session through cross-session refinement via event bus. 2-3 rounds of `help_needed`/`help_response` exchanges surfaced architectural patterns the original author missed. See Key Learning #8._

### Runtime System

These three repositories power the current workflow.

#### dotfiles (Control Plane)

Runtime behavior framework for Claude Code sessions, using dotfiles as the delivery mechanism. Key capabilities:

**Session Lifecycle Inversion of Control** — Hooks as extension points, not event listeners:
- Each lifecycle moment (`SessionStart`, `PreCompact`, `UserPromptSubmit`) is a payload transformation point
- Input: JSON context → Output: XML tags injected into Claude's prompt + side effects (tmux, event bus)
- Graceful degradation when dependencies missing—hooks log and continue, never block Claude

**Discontinuity-Aware State Management** — Treating compaction as checkpoint/restore:
- `pre-compact.sh` publishes `wip_checkpoint` *right before* context is summarized away
- `session-start.sh` restores `<wip-checkpoint-restored>` on resume
- `/work --attach` detects position from WIP events, PR state, and CI results

**Persistent Workflow Topology** — Commands as resumable state machines:
- `/work` defines: explore → clarify → architect → implement → review → merge → reflect
- Each step is idempotent; workflows survive session boundaries
- Commands encode the *structure* of work, not just actions

**Declared Behavioral Contracts** — CLAUDE.md as runtime constraint specification:
- Global (`~/.claude/CLAUDE.md`): "Be autonomous about X, require discussion on Y"
- Per-repo overrides: "For this repo, test with `make check`, understand bootstrap pattern"
- Not documentation—behavioral specification that changes Claude's decision-making

#### claude-event-bus (Coordinate)

MCP server for cross-session Claude Code coordination via polling. Deliberately minimal—a coordination primitive, not a framework. Key capabilities:

**Hook-Driven Semi-Realtime Updates** — Pragmatic polling that works within MCP constraints:
- `prompt-events.sh` hook polls on every prompt, injects `<recent-events>` automatically
- Sessions see cross-session activity without manual checking or flow interruption
- Direct messages (`session:{id}`) trigger macOS notifications for higher priority
- Explicitly acknowledges MCP's request/response nature—doesn't try to fake push

**Broadcast-First Pub/Sub** — Simpler than traditional channel subscriptions:
- All sessions see all events; channels are priority metadata, not filters
- No subscription management—sessions implicitly belong to `all`, `repo:`, `machine:`, `session:`
- Trade-off: simplicity over efficiency (works at Claude Code scale, wouldn't scale to thousands)

**Cursor-Tracked Session Lifecycle** — Stateful polling with minimal client burden:
- `(machine, client_id)` dedup key enables session resumption across restarts
- `resume=True` auto-uses last cursor—no cursor management required
- Auto-heartbeat on `publish_event()` and `get_events()`; PID liveness checks for faster cleanup

**Observable Request Logging** — Every tool call pretty-printed for `tail -f`:
- ANSI colors: yellow for mutations, blue for reads
- UUIDs resolved to human-readable display_ids ("brave-tiger" not "b712a0ba...")
- Publisher attribution with active (cyan) vs inactive (red) session names

#### claude-session-analytics (Insight)

Queryable analytics for Claude Code session logs, designed for LLM consumption. Key capabilities:

**Raw Signals Over Interpretation** — Let consuming LLMs decide meaning:
- `get_session_signals()` returns observables (`error_count: 5`, `has_rework: true`), not conclusions
- RFC #17: "Don't over-distill—raw data with light structure beats heavily processed summaries"
- Enables context-aware interpretation—the LLM querying knows *why* it's asking

**Guaranteed Drill-Down Paths** — Every aggregate leads to source:
- "821 Bash errors" → `analyze_failures()` → `get_session_events(tool='Bash')` → specific commands
- Self-play tested: can you reach an actionable conclusion using only MCP tools?
- RFC #49 explicitly closes drill-down gaps

**Incremental Ingestion with Protected History** — Never-destructive data handling:
- JSONL files are append-only; ingestion tracks file positions
- Schema migrations via `@migration` decorator are idempotent (check before ALTER)
- Database is irreplaceable—CLAUDE.md explicitly bans DROP/DELETE on user tables

**Agent-Aware Token Deduplication** — Hierarchical event tracking (RFC #41):
- `parent_uuid` links tool_use events to their parent assistant turn
- Tokens attributed to assistant events only—avoids double-counting across hierarchy
- `agent_id` + `is_sidechain` distinguish Task subagents from main session
- Enables "how much work did agents do vs you?" queries (`get_agent_activity()`)

### Projects Under Development

These two repositories are being built during this experiment—the future runtime.

#### gemicro (Agents)

Agent patterns and tool orchestration on top of rust-genai's LLM client. Key capabilities:

**LLM-First Design** — Trust the model; don't over-engineer:
- Agents are thin wrappers that emit events, not complex state machines
- Breaking changes welcome—simplicity over backwards compatibility
- No agent-specific parsing; let the model handle ambiguity

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

#### rust-genai (SDK)

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
