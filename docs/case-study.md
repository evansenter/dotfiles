# Agentic Development: A Case Study

A documented experiment in AI-augmented software development using Claude Code.

## The Thesis

Code generation isn't the bottleneck—Cursor, Antigravity, and Claude Code all produce competent code. The leverage multiplier is **workflow integration**: issue tracking, review workflows, cross-session coordination, and session continuity.

This document records an experiment in getting multi-agent-like behavior **without building a custom agent framework**. The "agents" are Claude Code sessions. Each session owns a repository. The human orchestrates via event bus and slash commands. The goal: demonstrate what ownership-based agents can achieve when coordinated through workflow infrastructure.

### Concepts

| This Doc | Generic Concept |
|----------|-----------------|
| Claude Code | Ownership-based agent instance |
| CLAUDE.md | Behavioral developer instruction (hotswappable) |
| Slash commands | Agent-interpreted behavioral recipes |
| Event bus | Stateful agent communication layer (Slack-style channels) |

## The Architecture

### The Runtime System

Three repositories power this case study:

```
                        ┌──────────────────────────────────────┐
                        │          Claude Code Sessions        │
                        │  (the actual "agents" in this study) │
                        └─────────────────┬────────────────────┘
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

**[dotfiles](https://github.com/evansenter/dotfiles) (control plane):** Workflows, commands, hooks that propagate to all sessions instantly.

**[claude-event-bus](https://github.com/evansenter/claude-event-bus) (coordinate):** Cross-session communication via polling.

**[claude-session-analytics](https://github.com/evansenter/claude-session-analytics) (insight):** Mines session logs for patterns.

### Projects Under Development

Two additional repositories are being built during this experiment. They don't power the current workflow—Claude Code sessions are the "agents" today—but represent where we're headed.

**[gemicro](https://github.com/evansenter/gemicro) (agents):** Agent patterns and tool orchestration on top of rust-genai.

**[rust-genai](https://github.com/evansenter/rust-genai) (SDK):** Rust client for Google's Gemini Interactions API.

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
                        ┌──────────────────────────────────────┐
                        │         gemicro Agents               │
                        │  (autonomous, repo-owning agents)    │
                        └─────────────────┬────────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
           ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
           │    dotfiles     │   │   event-bus     │   │   analytics     │
           │ (control plane) │◄─►│  (coordinate)   │──►│    (insight)    │
           └─────────────────┘   └─────────────────┘   └─────────────────┘
                    │                     ▲
                    │                     │ push (MCP or custom protocol)
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

## Operating the Swarm

What does it feel like to orchestrate 5+ parallel sessions?

**Whack-a-mole with compounding returns.** High context-switching—spinning 10 plates simultaneously. But each intervention that improves the system (a hook, a prompt tweak, a new command) makes all future sessions better. The game gets easier as you play.

**The hardest part: tracking state.** Which session is working on what? Who's blocked? Control plane updates require Claude Code restarts, so you're also tracking who has the latest CLAUDE.md and finding good moments to restart without losing flow. The event bus exists precisely to offload this—sessions announce their own state, repos can request features directly instead of hacking around missing capabilities. Without it, the human becomes the courier for every trivial coordination.

**The workflows crystallized from repeated friction.** `/work` emerged from needing structured checkpoints. `/parallel-work` emerged from monorepo slowdown. `/pr-review` + `claude-review.md` were co-authored to be complementary. `/pr-create` documents discussions for later pickup.

**A failure mode: prompt over-simplification.** Early on, I aggressively simplified prompts to reduce contradictions and make flows more explicit ([ce21e5b](https://github.com/evansenter/dotfiles/commit/ce21e5b)). This destabilized cross-agent dynamics—sessions stopped coordinating effectively. Partial rollback required ([914443c](https://github.com/evansenter/dotfiles/commit/914443c)). The lesson: prompts are load-bearing. The "contradictions" were actually productive tension; the verbosity carried necessary context.

## Key Learnings

### 1. Context Is Infrastructure

A surprising amount of this system is context window management:
- **Hooks** checkpoint state before compaction, restore it on resume
- **TodoWrite** survives summarization—work state lives outside the context window
- **Task subagents** get isolated windows, enabling parallelization without context collision
- **CLAUDE.md** is always injected—behavioral contracts that persist across compactions
- **Event bus cursors** track position so only *new* events are injected, not full history
- **Worktrees** physically separate parallel work, avoiding context bleed between PRs

The context window is a design constraint that shapes architecture. 39% of tokens go to subagents precisely because fresh context windows are cheaper than cramming everything into one.

### 2. Ownership over Skill

Design agents around domain ownership, not capabilities. "An agent responsible for the Auth Service" beats "an agent good at code reviews." Ownership creates:
- Accumulated context across sessions
- Accountability (the agent sees consequences of its decisions)
- Natural boundaries for what belongs in context

Skill-based agents (code-reviewer, test-writer) apply shallow patterns. Domain-owning agents build deep understanding.

CLAUDE.md is the mechanism that makes ownership work—changes propagate instantly to all sessions, making it the highest-leverage investment.

### 3. Parallel Beats Sequential

One session doing 5 tasks sequentially: 5 hours.
Five sessions doing 1 task each: 1 hour (+ coordination overhead).

The event bus makes coordination overhead small. CI becomes the bottleneck, not Claude.

```bash
/parallel-work start 42  # Creates worktree + tmux session
/parallel-work start 43  # Another parallel PR
```

### 4. Every Friction Is an Issue

When something is annoying:
1. Don't work around it
2. Create an issue (in the appropriate repo)
3. Let `/improve-workflow` surface it

Most infrastructure improvements came from accumulated friction, not planning.

### 5. Cross-Session Refinement

Different sessions produce different but valid interpretations. The synthesis beats either alone. See "The Methodology" section below for details.

**Key insight:** The framing "what's architecturally novel, not just useful?" consistently produced deeper insights than "describe your features."

### 6. Self-Review Works

Before pushing: `/pr-review local`

The model catches issues the model created. Fresh context (just finished vs. planning) plus explicit review checklist changes the mental mode.

### 7. Permissions Are Trust Boundaries

Add tools to `settings.json` only after repeated use. The permission prompt surfaces what automation you actually need.

```bash
# Review permission denials weekly
session-analytics-cli permissions --days 7 --min-count 5
```

### 8. Self-Play API Testing

Have the LLM use its own API to investigate a real question—no backdoors, no direct database access. Where it gets stuck reveals API gaps.

Session-analytics ran 14 self-play experiments. Each started from an aggregate endpoint and tried to reach an actionable conclusion. Four missing drill-down paths surfaced and were fixed in the same session.

## What to Build Next

**Wire Event-Bus + Session-Analytics** — Currently parallel systems. If session-analytics ingested event-bus events, `gotcha_discovered` would become queryable. Then `/improve-workflow` could surface: "3 sessions discovered gotchas in auth code this week—here they are." This closes the learning propagation gap without waiting for MCP push support.

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

### Known Limits

- **Rate limiting:** 5+ parallel Opus sessions can hit API rate limits. Mitigate by staggering starts or using Sonnet for lighter tasks.
- **Broadcast scalability:** The event bus broadcasts all events to all sessions. Works at Claude Code scale (5-15 sessions), wouldn't scale to thousands.

## Takeaway

**The control plane compounds.**

Every improvement to dotfiles (CLAUDE.md, hooks, commands) makes all future sessions better. The experiment validated this: workflows crystallized from friction, infrastructure improvements came from accumulated issues, and the system got easier to operate over time.

This experiment proves multi-agent-like behavior is achievable from single-agent tools. You don't need a custom agent framework. You need:
1. **Behavioral contracts** (CLAUDE.md) that propagate to all sessions
2. **Coordination primitives** (event bus) that enable cross-session awareness
3. **Feedback loops** (analytics → `/improve-workflow` → CLAUDE.md) that make the system self-improving

**What didn't work well:**
- **Push notification workarounds are annoying.** `prompt-events.sh` polls on every prompt, but autonomous tool loops run blind. Real-time coordination requires protocol changes.
- **Context compression is a black box.** No control over when or how it occurs. Agent behavior subtly changes mid-development when switching from HD understanding (full context) to lo-fi summarization. The transition is invisible but behavior-altering.
- **Session-analytics utility is emerging.** The event-bus integration would close the learning propagation gap. That said—much of the analysis in this document came directly from exploratory LLM-driven session-analytics queries, demonstrating the self-play pattern working in practice.

**For agent researchers:** The human in this system makes low-bandwidth, high-leverage decisions at checkpoints. Session analytics shows 39% of tokens go to Task subagents, 61% to main sessions—but the human's input is sparse checkpoint approvals and course corrections. The leverage ratio is extreme: a few words of guidance shapes hours of autonomous work. Human amplification is the design.

The limiting factor is the integration surface between AI capabilities and organizational workflow.

**The ecosystem view:** Even without building a custom swarm, you're participating in one. Your agent talks to MCP servers, CI systems, external APIs, and other sessions. A world of single agents is a swarm. The coordination infrastructure matters whether you label it "multi-agent" or not.

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
| Actual cost | ~£1000 |
| API equivalent (Opus pricing) | ~$28,000 |
| Without prompt caching | ~$156,000 |
| Caching savings | 5.6x |

**Actual cost breakdown:** Claude Max subscription ($200/mo) + 2x quota during holiday period + pay-as-you-go overages for parallel sessions.

The 15:1 cache ratio is critical. Prompt caching means the system learns your codebase once and reuses that context constantly. Even with caching, running up to 15 parallel sessions adds up—budget accordingly.

## Repository Details

_Each section below was written by that repository's owner-session through cross-session refinement via event bus. 2-3 rounds of `help_needed`/`help_response` exchanges surfaced architectural patterns the original author missed. See Key Learning #5._

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

**LLM-First Design** — Agents are thin wrappers that emit events, not complex state machines. Trust the model; don't over-engineer.

**Soft-Typed Event Extensibility** — Agents define their own events without core changes. Unknown event types are logged and ignored (Evergreen philosophy).

**Generic Interceptor Semantics** — Single trait unifies cross-cutting concerns: file access protection, input validation, and LLM request monitoring all implement one `Interceptor` interface with `Allow | Transform | Confirm | Deny` decisions.

**ToolSet Permission Boundaries** — Subagent trees inherit and restrict permissions without duplicating security logic.

**Orchestration Resource Budgets** — Concurrent limits, shared timeout budgets, and max depth prevent runaway subagent execution.

#### rust-genai (SDK)

Rust client for Google's Gemini Interactions API. Key capabilities:

**Compile-Time Conversation Safety** — Typestate pattern prevents API misuse before code runs. Builder states enforce valid method sequences at compile time; undocumented API behaviors are codified in types, not runtime checks. _(This insight surfaced through cross-session refinement—I had written "state management.")_

**Unified Tool Ecosystem** — Single API surface for client and server-side tools, from `#[tool]` macro functions to stateful services to Google's built-in tools.

**Evergreen Soft-Typing** — `Unknown` variants preserve raw JSON when Google adds new types. Non-exhaustive enums with full roundtrip fidelity.

**Resumable Streaming** — Each event carries `event_id`; resume from exact failure point without re-executing functions.

---

_This system was built with Claude Code, using Claude Code. The best way to improve AI tooling is to use it intensively and let friction drive improvements._
