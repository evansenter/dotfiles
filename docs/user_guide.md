# Architecting Agency: A 14-Day Experiment in AI-Native Development

**An architectural case study on transforming a dormant 2011 dotfiles repo into a multi-agent coordination hub.**

## The Core Thesis

AI coding assistants are typically treated as productivity tools—faster autocorrect. This is a category error. They are **leverage multipliers**.

If you treat an LLM as a stateless chatbot, you get linear returns. If you treat it as a **stateful coworker**—investing in its context, teaching it protocols, and giving it memory—you get exponential returns.

This document serves as a blueprint for that transition.

## The Experiment: By The Numbers

Over 14 days in December 2025, I orchestrated a system of 5 interconnected repositories.

| Metric | Value | Implication |
|--------|-------|-------------|
| **Sessions** | 165 | High fragmentation; distinct tasks per session. |
| **Lines of Code** | 86,000 | velocity impossible for a solo human. |
| **PRs Merged** | 140+ | High cadence, atomic delivery. |
| **Cache Efficiency** | **16:1** | **The Critical Stat.** |

**The 16:1 Ratio**: For every token I paid to generate, I read 16 from cache (5.4B reads vs 343M writes). This is the key to economic viability. The system "learns" the codebase once and reuses that context cheaply. Without prompt caching, this workflow is economically impossible.

## The Architecture: An Agentic OS

To move beyond "chatting with code," I built a layered ecosystem.

### 1. The Kernel: Dotfiles (Meta-Orchestration)
*Function: Control Plane*
Most dotfiles are static configs. These are dynamic workflows.
- **Protocol Standardization**: Replaced ad-hoc prompts with rigid commands (`/work`, `/pr-review`). This ensures every agent follows the same quality gates, regardless of the prompt.
- **Ambient Awareness**: Custom statuslines expose context usage and active models, preventing "context blindness."

### 2. The Nervous System: Claude Event Bus
*Function: Cross-Session Coordination*
Running multiple agents in parallel fails if they are blind to each other.
- **Pub/Sub Architecture**: Session A finishes an auth backend; Session B (working on frontend) receives the `task_completed` event and unblocks itself.
- **Discovery Propagation**: When Session C discovers a "gotcha" (e.g., specific SQLite version quirks), it publishes a `gotcha_discovered` event. Future sessions ingest this to avoid repeating the mistake.

### 3. The Engine: Gemicro & Rust-Genai
*Function: High-Performance Execution*
Python scripts weren't fast enough for the tool-use loop.
- **Rust Integration**: Built a native Interactions API SDK to handle streaming, tool use, and vision with low latency.
- **MCP Framework**: Developed `gemicro` to standardize how tools are exposed to the agents, including `Trajectory` recording for debugging agent thought processes.

### 4. The Analyst: Session Analytics
*Function: Self-Optimization*
An LLM that doesn't learn from its mistakes is a waste of money.
- **Data Mining**: Parses logs to find failed tool invocations, friction points, and permission denials.
- **Feedback Loop**: The `/improve-workflow` command turns these stats into Jira-style issues. The system suggests its own infrastructure upgrades.

## Key Primitives

### 1. Workflows > Prompts
I stopped typing "Please review this code."
I built `/pr-review local`.
This command triggers a deterministic sequence:
1.  Scan changes.
2.  Categorize findings (Critical vs. Suggestion).
3.  Inject "Opiniated" context (Why did we do this?).
4.  Present a batch-decision UI to the user.
**Result**: Code review becomes a swift managerial action, not a chat debate.

### 2. Parallelism via Worktrees
Humans serialize tasks. Agents parallelize them.
I regularly run 5-8 sessions simultaneously:
- **Session 1**: Refactoring the event bus.
- **Session 2 & 3**: Writing unit tests for the Rust SDK.
- **Session 4**: Updating documentation.
The **Event Bus** keeps them synchronized. CI is the only bottleneck.

### 3. Permissions as Trust Boundaries
The permission prompt is not a nuisance; it is a discovery mechanism.
- I start with zero permissions.
- I grant them only when the friction becomes unbearable.
- **Analytics** track these denials (`permission_gaps`).
- This ensures the agent effectively "requests" the tools it actually needs, not what I think it needs.

## Open Research Problems

This system is powerful, but immature.

1.  **MCP push-notifications are missing**: The Model Context Protocol is request/response. Agents must "poll" for events. True real-time coordination requires server-sent events (SSE).
2.  **Context Compaction is lossy**: When context hits 80%, summarization kicks in. Nuance (reasoning chains) is lost, though facts remain. This makes deep debugging across long sessions difficult.
3.  **Implicit Handoffs**: Spawning sub-agents (e.g., "Audit Codebase") lacks a formal schema for returning results. It feels like shouting instructions into a void and waiting for a report.

## Conclusion

This 14-day sprint proved that **Agentic Development** is distinct from **AI-Assisted Coding**.

- **AI-Assisted**: You type, AI autocompletes. You are the driver.
- **Agentic**: You define the protocol, AI executes. You are the architect.

The repositories in this case study (`dotfiles`, `claude-event-bus`, `gemicro`) are an attempt to build the standard library for this new paradigm.

---
*For implementation details, see [README.md](../README.md) or explore the `/.claude` directory.*
