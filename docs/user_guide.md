# Agentic Development: A Case Study

A documented experiment in AI-augmented software development using Claude Code.

## The Thesis

AI coding assistants are leverage multipliers. The more you invest in teaching them your workflows, the more they amplify output. This document records that investment.

## The Experiment

**Period:** December 20, 2025 - January 5, 2026 (17 days)

### Repository Activity

| Repository | PRs (open/merged) | Issues (open/closed) | Code | +/- Lines |
|------------|-------------------|----------------------|------|-----------|
| dotfiles | 0/114 | 5/51 | 6K Shell | +6.4K/-3.8K |
| gemicro | 0/116 | 29/85 | 30K Rust | +17.5K/-3.7K |
| claude-event-bus | 0/41 | 7/22 | 6K Python | +6.1K/-3.0K |
| claude-session-analytics | 0/30 | 4/19 | 12K Python | +19.0K/-1.8K |
| rust-genai | 1/166 | 6/125 | 37K Rust | +21.1K/-4.6K |
| **Total** | **1/467** | **51/302** | **91K** | **+70K/-17K** |

_Source: `gh pr list`, `gh issue list`, `scc`, `git log --stat`_

### Session Analytics

_Data available since December 30, 2025 (session log retention)._

| Metric | Value | Source |
|--------|-------|--------|
| Sessions | 258 | `session-analytics-cli sessions` |
| Tool invocations | 33,073 | `session-analytics-cli frequency` |
| Input tokens | 10.0M | `session-analytics-cli tokens` |
| Output tokens | 10.9M | `session-analytics-cli tokens` |
| Cache read | 9.7B | `session-analytics-cli tokens` |
| Cache creation | 658M | `session-analytics-cli tokens` |
| Cache ratio | 15:1 | cache_read / cache_creation |

**Regenerate:** `~/.claude/contrib/repo-stats.sh --days 17 --session-stats`

### Cost

| Metric | Value |
|--------|-------|
| Actual cost (Claude Code subscription) | ~£1,000 |
| API equivalent (Opus pricing) | ~$28,000 |
| Without prompt caching | ~$156,000 |
| Caching savings | 5.6x |

The 15:1 cache ratio is critical. Prompt caching means the system learns your codebase once and reuses that context constantly. Even with caching, intensive parallel development adds up—budget accordingly.

## The Architecture

Five repositories form an integrated system:

```
┌─────────────────┐     events      ┌─────────────────┐
│    dotfiles     │◄───────────────►│   event-bus     │
│   (control)     │                 │   (coordinate)  │
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

**Data flow:**
1. **dotfiles** defines workflows (commands, hooks, agents) that Claude Code executes
2. **event-bus** enables cross-session coordination—sessions announce progress, discoveries, blockers
3. **analytics** mines session logs for patterns, feeding `/improve-workflow` suggestions
4. **gemicro** provides agent infrastructure for external Gemini-based agents
5. **rust-genai** is the underlying Gemini API SDK

The key insight: dotfiles is the control plane. Instead of ad-hoc instructions, you define reusable workflows that encode preferences, quality gates, and coordination patterns.

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

### 5. CLAUDE.md Is High Leverage

Your project-level CLAUDE.md is read on every interaction. Include:
- Allowed autonomous decisions
- Required discussion points
- Quality gates
- Workflow patterns

Don't include generic coding standards (the model knows those).

## The Frontier

What's still broken:

### MCP Doesn't Support Push

The Model Context Protocol is request/response only. Claude can call MCP tools, but servers can't push events to Claude.

**Impact:** When Session B publishes an event, Session A won't see it until the next prompt triggers a hook poll.

**Workaround:** `prompt-events.sh` hook polls on every user prompt.

### Context Compaction Loses Nuance

At ~80% context, Claude Code compacts. Facts survive; reasoning chains and code snippets get summarized.

**Mitigation:** `/im-lost` and `[work:N]` todos help reconstruct context.

### No Cross-Machine Coordination

The event bus runs locally. Events don't sync between machines.

**Workaround:** Use GitHub issues as the coordination layer for cross-machine work.

### Rate Limiting During Parallel Work

5+ parallel Opus sessions can hit API rate limits.

**Mitigation:** Stagger session starts, use Sonnet for lighter tasks.

## Getting Started

1. Fork [evansenter/dotfiles](https://github.com/evansenter/dotfiles) and run `./bootstrap.sh`
2. Start with `/status-report` to orient
3. Use `/work <issue>` for guided development
4. Run `/improve-workflow` weekly

## Further Reading

- [Multi-Agent Research Discussion](multi-agent-research-discussion.md)
- [Multi-Agent Ecosystem Coordination](multi-agent-ecosystem-coordination.md)
- [Event Bus Guide](../home/.claude/contrib/README.md)

---

_This system was built with Claude Code, using Claude Code. The recursive nature isn't coincidental—the best way to improve AI tooling is to use it intensively and let friction drive improvements._

_Session analytics data available since December 30, 2025._
