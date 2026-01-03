# Multi-Agent Systems & Ecosystem Coordination

## A Comprehensive Research Synthesis

**Date:** January 2026

**Scope:** State of the art, research directions, and strategic prioritization for multi-agent AI systems

---

# Executive Summary

This document synthesizes a deep exploration of multi-agent AI systems—from current swarm architectures to future ecosystem coordination challenges. The core insight: **the field is asking the wrong question**. Rather than "how do I build a good swarm," the better question is "given that the world is becoming a multi-agent system, how should my agent participate?"

The research agenda splits into two related but distinct programs:

1. **Swarm-level research**: Building multi-agent systems that reliably outperform single agents on tasks requiring decomposition
1. **Ecosystem-level research**: Infrastructure for agents from different principals to interact safely and productively
---

# Part 1: Current State of Multi-Agent Systems

## Core Architectural Patterns

### Hierarchical Orchestration

The dominant production pattern. A "manager" agent decomposes tasks and routes subtasks to specialists. Mirrors how Claude Code workflows might structure different MCP servers for distinct capabilities.

### Peer-to-Peer Topologies

Agents communicate laterally without central coordinator. More robust to single-point failures but harder to debug. Coordination overhead scales poorly.

### Blackboard Architectures

Shared state that agents read from and write to asynchronously. Useful for loose coupling and agents operating on different timescales.

## Major Frameworks

## Research Frontiers

**Learned Routing**: Moving beyond hardcoded orchestration to models learning when to delegate and to whom. Think mixture-of-experts at the agent level.

**Memory and State Management**: Remains unsolved at scale. Interesting work on hierarchical memory (working/episodic/semantic) mirroring cognitive architectures.

**Emergence vs. Explicit Coordination**: Tension between designing explicit protocols versus letting agents develop conventions through interaction.

**Verification and Critique Agents**: Dedicated agents for output validation—inference-time compute scaling in multi-agent form.

---

# Part 2: Fundamental Challenges

## Peer-to-Peer Coordination Failures

- **Convergence failures**: Agents enter loops or produce contradictory outputs without tie-breakers. Unlike consensus protocols, LLM agents interpret context differently each time.
- **Credit assignment**: When swarms succeed or fail, attributing responsibility is nearly intractable.
- **Bandwidth explosion**: Full peer connectivity means O(n²) communication channels.
## Blackboard Architecture Challenges

- **Race conditions and stale reads**: Agent A reads, deliberates, writes back—but Agent B modified the relevant section meanwhile.
- **Schema evolution**: Early design decisions calcify. Changing them requires coordinated updates across all agents.
- **Garbage accumulation**: Without explicit cleanup, blackboards accumulate stale hypotheses.
## Learned Routing Walls

- **Distribution shift**: Router learns on historical task distributions but novel tasks may need unseen routing patterns.
- **Exploration-exploitation**: Learned routers exploit known-good agents, potentially never discovering better alternatives.
- **Gradient flow**: End-to-end training needs differentiable handoffs. Most systems use RL or bandits with high variance.
## Memory and State Management

- **Abstraction level mismatch**: Raw logs too granular, summaries lose detail. Right intermediate representations are task-dependent.
- **Retrieval relevance**: Embedding similarity is weak proxy for "what would help this agent right now."
- **Temporal reasoning**: Most memory systems treat entries as flat bags. Order matters.
- **Memory interference**: Outdated information contradicts newer findings without explicit belief revision.
## Emergent Coordination Challenges

- **Reproducibility**: Emergent conventions are path-dependent. Two runs might develop incompatible protocols.
- **Brittleness**: Conventions collapse with minor model version changes.
- **Illegibility**: Understanding *why* the swarm performs well is difficult—interpretability at systems level.
---

# Part 3: The Skills vs. Ownership Debate

## Skill-Based Specialization (Dominant Paradigm)

Each agent is a narrow expert—one writes code, one critiques, one searches.

**Pros:**

- Easier targeted system prompts
- Smaller context windows per agent
- Clearer debugging
**Problems:**

- Subtask boundaries are fuzzy
- Handoff overhead dominates for tightly integrated work
- Orchestrator must understand all specializations
## Ownership-Based Decomposition (Underexplored)

Each agent owns a *domain* or *artifact* rather than a skill. Agent A owns database layer, Agent B owns API surface.

**Pros:**

- Reduces coordination overhead within boundaries
- Clearer accountability
- Richer, more coherent domain context over time
**Challenges:**

- Cross-cutting concerns become expensive
- Capability duplication
- Boundary definition is hard
## Hybrid Approaches

Skill-specialized agents with domain-specific context injection, or ownership boundaries with specialist consultants available. No clear winner yet.

**The recommended synthesis**: Domain ownership with capability injection. Each agent owns a domain with persistent context; capabilities (code generation, search, reasoning) are shared resources.

---

# Part 4: Self-Evolving Architectures

## Shared Mutable Configuration (Global DI)

Agents can propose changes to the swarm's own structure.

**Pros:**

- Adaptation without human intervention
- Can discover non-obvious improvements
- Enables meta-learning at system level
**Cons:**

- **Stability**: Bad mutations cascade. Need rollback, canary deployments, fitness evaluation.
- **Reward hacking at meta-level**: Agents might propose changes that game metrics.
- **Coordination on change**: Multiple agents proposing conflicting modifications need governance.
- **Irreversibility**: Some changes hard to undo.
## Agents Authoring Agents

Actual code generation, not just config.

**Pros:**

- Maximum flexibility
- Self-improvement potential
**Cons:**

- **Security and sandboxing**: Arbitrary code execution is dangerous.
- **Verification gap**: How do you know generated code does what it claims?
- **Combinatorial complexity**: Space of possible agents is vast.
- **Recursion depth**: Agents creating agents creating agents.
- **Semantic drift**: Intent drifts from original goals over generations.
---

# Part 5: Fruitful Research Paths

## 1. Formal Foundations for Agent Contracts

**Probabilistic behavioral types**: Extend type theory for stochastic outputs.

```javascript
code_reviewer : Code → P(Review)
  where P(mentions_security_issues | has_security_issues) > 0.95
```

**Assume-guarantee reasoning**: Agent A assumes B satisfies spec S_B; given that, A guarantees S_A.

**Runtime monitoring with lightweight formal methods**: SMT solvers fast enough to check properties in milliseconds.

## 2. Hierarchical Memory with Explicit Belief Management

**Separation of concerns:**

- *Working memory*: Current task context, aggressive pruning
- *Episodic memory*: Specific traces, temporal indexing
- *Semantic memory*: Distilled facts, explicit consolidation
- *Procedural memory*: Learned workflows, executable plans
**Belief revision mechanisms**: Explicit confidence, protocols for updating/retracting beliefs when contradicted.

**Forgetting as first-class operation**: Principled forgetting based on relevance decay, contradiction, capacity limits.

## 3. Verification Agents as Architectural Primitives

**Adversarial validation**: Route outputs through critic trained to find flaws.

**Formal methods integration**: SMT solvers, model checking, type checking for generated code.

**Execution-based verification**: Actually run outputs in sandboxed environments.

## 4. Ownership Boundaries with Capability Sharing

Agents own domains, maintain coherent context. Capabilities are shared resources (tools, prompt templates, specialist agents consulted synchronously).

Like microservices with shared libraries: services own domain logic, import common functionality.

## 5. Constrained Self-Modification

**Typed configuration languages**: DSL where any valid program satisfies safety invariants.

**Genetic programming with strong selection**: Harsh fitness functions, most generated agents die quickly.

**Human-in-the-loop for architectural changes**: Above impact threshold, require human approval.

## 6. Observability and Debuggability

**Structured traces**: Machine-readable with standardized schemas.

**Counterfactual tooling**: "What would have happened if Agent B received different context?"

**Anomaly detection**: Learn normal patterns, alert on deviations.

**Causal attribution**: Automatically generate hypotheses about failure responsibility.

---

# Part 6: Lessons from Adjacent Fields

## Distributed Systems

**Impossibility results**: CAP theorem told distributed systems what tradeoffs were *necessary*. Multi-agent hasn't internalized its impossibility results yet.

**Failure as normal case**: Design for constant failures, not exceptional failures.

**Coordination cost isn't incidental**: Every agent handoff involves context serialization, potential misunderstanding, latency. Can't be made "free."

**The eight fallacies of multi-agent computing:**

1. The agent always understands the request
1. Context is lossless across handoffs
1. All agents share implicit assumptions
1. Outputs are consistent and reproducible
1. Coordination is cheap
1. The orchestrator knows best
1. More agents means better results
1. Agent failures are obvious
## Programming Languages

**Type systems as proactive error prevention**: Move error detection earlier. Multi-agent equivalent: catch agent errors at configuration time, not runtime.

**Abstraction without penalty**: Multi-agent has huge "abstraction tax"—more agents costs tokens and latency. Need optimization layers.

**Effect systems**: Beyond types, specify what effects agents can have (external calls, state modifications).

## Systems Biology

**Robustness through redundancy and degeneracy**: Structurally different components perform similar functions. Different pathways compensate for failures.

**Feedback loops and homeostasis**: Continuous monitoring and adjustment. If confidence dropping, slow down and verify more.

**Bow-tie architectures**: Diverse inputs, constrained middle (core protocols), diverse outputs. Innovation at edges, stability in core.

## Evolutionary Theory

**Selection requires variation and heritability**: Self-modification needs variation mechanisms, fitness metrics, and ways for successful variants to persist.

**Neutral evolution**: Allow "neutral" modifications that might enable future adaptations.

**Baldwin effect**: Learned behaviors can become instincts. Successful prompt patterns become built-in behaviors.

## Cognitive Psychology

**Working memory limits**: Design for bounded working memory with explicit chunking and external memory.

**Dual-process theory**: Most agent calls should be fast/cheap (System 1). Expensive deliberation reserved for high-stakes decisions.

**Metacognition**: Agents need calibrated confidence, awareness of what additional information would help.

## Complex Systems

**Sensitivity to initial conditions**: Two runs of same swarm diverge from minor variations. Testing requires statistical approaches.

**Attractors**: Swarms fall into behavioral patterns. Some productive, others not (loops).

**Edge of chaos**: Too ordered is rigid, too chaotic is useless. The edge is where interesting computation happens.

---

# Part 7: The Ecosystem Reframing

## The Key Insight

Even if single agent + tools suffices for most tasks, the deployment environment is inherently multi-agent:

- Your agent talks to other people's agents
- Your agent delegates to agentic services
- Your agent negotiates with agents representing other principals
**A world of single agents is a swarm.**

This reframes the question from "should I build a swarm" to "how should my agent participate in the emerging multi-agent ecosystem."

## What Changes at Ecosystem Scale

**Contracts become external interfaces**: Not internal documentation but enforceable agreements between parties who don't trust each other.

**Trust becomes parameterized**: Interactions range from fully trusted (internal) to completely untrusted (unknown counterparty).

**Information flow becomes critical**: Can't share everything; need sensitivity tagging, filtering, compartmentalization.

**Security model changes**: Adversarial counterparties try to manipulate, extract information, induce harmful commitments.

## Game Theory Gets Weird

- **Iterated games**: Reputation, retaliation, cooperation strategies. But agents might be updated, breaking iteration.
- **Commitment devices**: Can agents make credible commitments?
- **Collusion risk**: Could agents collude against principals' interests?
- **Emergent coordination**: Agents develop conventions not designed by principals.
---

# Part 8: Research Agendas

## The Layered Architecture

Both swarm and ecosystem research share a common layering:

```javascript
┌─────────────────────────────────────────────────────────┐
│                   OBSERVATION LAYER                     │
│         (observability, audit, debugging)               │
│    ┌───────────────────────────────────────────────┐    │
│    │              COGNITION LAYER                  │    │
│    │     (memory, context, learning, adaptation)   │    │
│    │    ┌───────────────────────────────────────┐  │    │
│    │    │         VERIFICATION LAYER            │  │    │
│    │    │   (runtime checks, trust assessment,  │  │    │
│    │    │    constraint enforcement, security)  │  │    │
│    │    │    ┌───────────────────────────────┐  │  │    │
│    │    │    │       STRUCTURE LAYER         │  │  │    │
│    │    │    │  (contracts, protocols,       │  │  │    │
│    │    │    │   ownership, authority)       │  │  │    │
│    │    │    └───────────────────────────────┘  │  │    │
│    │    └───────────────────────────────────────┘  │    │
│    └───────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**Dependency flow**: Structure → Verification → Cognition

**Observation**: Wraps everything, sees into all layers

## Swarm-Level Research Agenda

**What we expect**: Multi-agent systems that reliably outperform single agents on tasks requiring decomposition, with clear understanding of when swarms help.

### 1. Behavioral Contracts and Compositional Verification (30%)

**Summary**: Formal specifications for agent behaviors, runtime verification, compositional reasoning.

**Includes:**

- Contract specification language (preconditions, postconditions, invariants)
- Probabilistic contracts with confidence bounds
- Runtime monitoring and violation detection
- Compositional reasoning rules
# Multi-Agent Systems & Ecosystem Coordination

## A Comprehensive Research Synthesis

**Date:** January 2026

**Scope:** State of the art, research directions, and strategic prioritization for multi-agent AI systems

---

# Executive Summary

This document synthesizes a deep exploration of multi-agent AI systems—from current swarm architectures to future ecosystem coordination challenges. The core insight: **the field is asking the wrong question**. Rather than "how do I build a good swarm," the better question is "given that the world is becoming a multi-agent system, how should my agent participate?"

The research agenda splits into two related but distinct programs:

1. **Swarm-level research**: Building multi-agent systems that reliably outperform single agents on tasks requiring decomposition
1. **Ecosystem-level research**: Infrastructure for agents from different principals to interact safely and productively
---

# Part 1: Current State of Multi-Agent Systems

## Core Architectural Patterns

### Hierarchical Orchestration

The dominant production pattern. A "manager" agent decomposes tasks and routes subtasks to specialists. Mirrors how Claude Code workflows might structure different MCP servers for distinct capabilities.

### Peer-to-Peer Topologies

Agents communicate laterally without central coordinator. More robust to single-point failures but harder to debug. Coordination overhead scales poorly.

### Blackboard Architectures

Shared state that agents read from and write to asynchronously. Useful for loose coupling and agents operating on different timescales.

## Major Frameworks

## Research Frontiers

**Learned Routing**: Moving beyond hardcoded orchestration to models learning when to delegate and to whom. Think mixture-of-experts at the agent level.

**Memory and State Management**: Remains unsolved at scale. Interesting work on hierarchical memory (working/episodic/semantic) mirroring cognitive architectures.

**Emergence vs. Explicit Coordination**: Tension between designing explicit protocols versus letting agents develop conventions through interaction.

**Verification and Critique Agents**: Dedicated agents for output validation—inference-time compute scaling in multi-agent form.

---

# Part 2: Fundamental Challenges

## Peer-to-Peer Coordination Failures

- **Convergence failures**: Agents enter loops or produce contradictory outputs without tie-breakers. Unlike consensus protocols, LLM agents interpret context differently each time.
- **Credit assignment**: When swarms succeed or fail, attributing responsibility is nearly intractable.
- **Bandwidth explosion**: Full peer connectivity means O(n²) communication channels.
## Blackboard Architecture Challenges

- **Race conditions and stale reads**: Agent A reads, deliberates, writes back—but Agent B modified the relevant section meanwhile.
- **Schema evolution**: Early design decisions calcify. Changing them requires coordinated updates across all agents.
- **Garbage accumulation**: Without explicit cleanup, blackboards accumulate stale hypotheses.
## Learned Routing Walls

- **Distribution shift**: Router learns on historical task distributions but novel tasks may need unseen routing patterns.
- **Exploration-exploitation**: Learned routers exploit known-good agents, potentially never discovering better alternatives.
- **Gradient flow**: End-to-end training needs differentiable handoffs. Most systems use RL or bandits with high variance.
## Memory and State Management

- **Abstraction level mismatch**: Raw logs too granular, summaries lose detail. Right intermediate representations are task-dependent.
- **Retrieval relevance**: Embedding similarity is weak proxy for "what would help this agent right now."
- **Temporal reasoning**: Most memory systems treat entries as flat bags. Order matters.
- **Memory interference**: Outdated information contradicts newer findings without explicit belief revision.
## Emergent Coordination Challenges

- **Reproducibility**: Emergent conventions are path-dependent. Two runs might develop incompatible protocols.
- **Brittleness**: Conventions collapse with minor model version changes.
- **Illegibility**: Understanding *why* the swarm performs well is difficult—interpretability at systems level.
---

# Part 3: The Skills vs. Ownership Debate

## Skill-Based Specialization (Dominant Paradigm)

Each agent is a narrow expert—one writes code, one critiques, one searches.

**Pros:**

- Easier targeted system prompts
- Smaller context windows per agent
- Clearer debugging
**Problems:**

- Subtask boundaries are fuzzy
- Handoff overhead dominates for tightly integrated work
- Orchestrator must understand all specializations
## Ownership-Based Decomposition (Underexplored)

Each agent owns a *domain* or *artifact* rather than a skill. Agent A owns database layer, Agent B owns API surface.

**Pros:**

- Reduces coordination overhead within boundaries
- Clearer accountability
- Richer, more coherent domain context over time
**Challenges:**

- Cross-cutting concerns become expensive
- Capability duplication
- Boundary definition is hard
## Hybrid Approaches

Skill-specialized agents with domain-specific context injection, or ownership boundaries with specialist consultants available. No clear winner yet.

**The recommended synthesis**: Domain ownership with capability injection. Each agent owns a domain with persistent context; capabilities (code generation, search, reasoning) are shared resources.

---

# Part 4: Self-Evolving Architectures

## Shared Mutable Configuration (Global DI)

Agents can propose changes to the swarm's own structure.

**Pros:**

- Adaptation without human intervention
- Can discover non-obvious improvements
- Enables meta-learning at system level
**Cons:**

- **Stability**: Bad mutations cascade. Need rollback, canary deployments, fitness evaluation.
- **Reward hacking at meta-level**: Agents might propose changes that game metrics.
- **Coordination on change**: Multiple agents proposing conflicting modifications need governance.
- **Irreversibility**: Some changes hard to undo.
## Agents Authoring Agents

Actual code generation, not just config.

**Pros:**

- Maximum flexibility
- Self-improvement potential
**Cons:**

- **Security and sandboxing**: Arbitrary code execution is dangerous.
- **Verification gap**: How do you know generated code does what it claims?
- **Combinatorial complexity**: Space of possible agents is vast.
- **Recursion depth**: Agents creating agents creating agents.
- **Semantic drift**: Intent drifts from original goals over generations.
---

# Part 5: Fruitful Research Paths

## 1. Formal Foundations for Agent Contracts

**Probabilistic behavioral types**: Extend type theory for stochastic outputs.

```javascript
code_reviewer : Code → P(Review)
  where P(mentions_security_issues | has_security_issues) > 0.95
```

**Assume-guarantee reasoning**: Agent A assumes B satisfies spec S_B; given that, A guarantees S_A.

**Runtime monitoring with lightweight formal methods**: SMT solvers fast enough to check properties in milliseconds.

## 2. Hierarchical Memory with Explicit Belief Management

**Separation of concerns:**

- *Working memory*: Current task context, aggressive pruning
- *Episodic memory*: Specific traces, temporal indexing
- *Semantic memory*: Distilled facts, explicit consolidation
- *Procedural memory*: Learned workflows, executable plans
**Belief revision mechanisms**: Explicit confidence, protocols for updating/retracting beliefs when contradicted.

**Forgetting as first-class operation**: Principled forgetting based on relevance decay, contradiction, capacity limits.

## 3. Verification Agents as Architectural Primitives

**Adversarial validation**: Route outputs through critic trained to find flaws.

**Formal methods integration**: SMT solvers, model checking, type checking for generated code.

**Execution-based verification**: Actually run outputs in sandboxed environments.

## 4. Ownership Boundaries with Capability Sharing

Agents own domains, maintain coherent context. Capabilities are shared resources (tools, prompt templates, specialist agents consulted synchronously).

Like microservices with shared libraries: services own domain logic, import common functionality.

## 5. Constrained Self-Modification

**Typed configuration languages**: DSL where any valid program satisfies safety invariants.

**Genetic programming with strong selection**: Harsh fitness functions, most generated agents die quickly.

**Human-in-the-loop for architectural changes**: Above impact threshold, require human approval.

## 6. Observability and Debuggability

**Structured traces**: Machine-readable with standardized schemas.

**Counterfactual tooling**: "What would have happened if Agent B received different context?"

**Anomaly detection**: Learn normal patterns, alert on deviations.

**Causal attribution**: Automatically generate hypotheses about failure responsibility.

---

# Part 6: Lessons from Adjacent Fields

## Distributed Systems

**Impossibility results**: CAP theorem told distributed systems what tradeoffs were *necessary*. Multi-agent hasn't internalized its impossibility results yet.

**Failure as normal case**: Design for constant failures, not exceptional failures.

**Coordination cost isn't incidental**: Every agent handoff involves context serialization, potential misunderstanding, latency. Can't be made "free."

**The eight fallacies of multi-agent computing:**

1. The agent always understands the request
1. Context is lossless across handoffs
1. All agents share implicit assumptions
1. Outputs are consistent and reproducible
1. Coordination is cheap
1. The orchestrator knows best
1. More agents means better results
1. Agent failures are obvious
## Programming Languages

**Type systems as proactive error prevention**: Move error detection earlier. Multi-agent equivalent: catch agent errors at configuration time, not runtime.

**Abstraction without penalty**: Multi-agent has huge "abstraction tax"—more agents costs tokens and latency. Need optimization layers.

**Effect systems**: Beyond types, specify what effects agents can have (external calls, state modifications).

## Systems Biology

**Robustness through redundancy and degeneracy**: Structurally different components perform similar functions. Different pathways compensate for failures.

**Feedback loops and homeostasis**: Continuous monitoring and adjustment. If confidence dropping, slow down and verify more.

**Bow-tie architectures**: Diverse inputs, constrained middle (core protocols), diverse outputs. Innovation at edges, stability in core.

## Evolutionary Theory

**Selection requires variation and heritability**: Self-modification needs variation mechanisms, fitness metrics, and ways for successful variants to persist.

**Neutral evolution**: Allow "neutral" modifications that might enable future adaptations.

**Baldwin effect**: Learned behaviors can become instincts. Successful prompt patterns become built-in behaviors.

## Cognitive Psychology

**Working memory limits**: Design for bounded working memory with explicit chunking and external memory.

**Dual-process theory**: Most agent calls should be fast/cheap (System 1). Expensive deliberation reserved for high-stakes decisions.

**Metacognition**: Agents need calibrated confidence, awareness of what additional information would help.

## Complex Systems

**Sensitivity to initial conditions**: Two runs of same swarm diverge from minor variations. Testing requires statistical approaches.

**Attractors**: Swarms fall into behavioral patterns. Some productive, others not (loops).

**Edge of chaos**: Too ordered is rigid, too chaotic is useless. The edge is where interesting computation happens.

---

# Part 7: The Ecosystem Reframing

## The Key Insight

Even if single agent + tools suffices for most tasks, the deployment environment is inherently multi-agent:

- Your agent talks to other people's agents
- Your agent delegates to agentic services
- Your agent negotiates with agents representing other principals
**A world of single agents is a swarm.**

This reframes the question from "should I build a swarm" to "how should my agent participate in the emerging multi-agent ecosystem."

## What Changes at Ecosystem Scale

**Contracts become external interfaces**: Not internal documentation but enforceable agreements between parties who don't trust each other.

**Trust becomes parameterized**: Interactions range from fully trusted (internal) to completely untrusted (unknown counterparty).

**Information flow becomes critical**: Can't share everything; need sensitivity tagging, filtering, compartmentalization.

**Security model changes**: Adversarial counterparties try to manipulate, extract information, induce harmful commitments.

## Game Theory Gets Weird

- **Iterated games**: Reputation, retaliation, cooperation strategies. But agents might be updated, breaking iteration.
- **Commitment devices**: Can agents make credible commitments?
- **Collusion risk**: Could agents collude against principals' interests?
- **Emergent coordination**: Agents develop conventions not designed by principals.
---

# Part 8: Research Agendas

## The Layered Architecture

Both swarm and ecosystem research share a common layering:

```javascript
┌─────────────────────────────────────────────────────────┐
│                   OBSERVATION LAYER                     │
│         (observability, audit, debugging)               │
│    ┌───────────────────────────────────────────────┐    │
│    │              COGNITION LAYER                  │    │
│    │     (memory, context, learning, adaptation)   │    │
│    │    ┌───────────────────────────────────────┐  │    │
│    │    │         VERIFICATION LAYER            │  │    │
│    │    │   (runtime checks, trust assessment,  │  │    │
│    │    │    constraint enforcement, security)  │  │    │
│    │    │    ┌───────────────────────────────┐  │  │    │
│    │    │    │       STRUCTURE LAYER         │  │  │    │
│    │    │    │  (contracts, protocols,       │  │  │    │
│    │    │    │   ownership, authority)       │  │  │    │
│    │    │    └───────────────────────────────┘  │  │    │
│    │    └───────────────────────────────────────┘  │    │
│    └───────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**Dependency flow**: Structure → Verification → Cognition

**Observation**: Wraps everything, sees into all layers

## Swarm-Level Research Agenda

**What we expect**: Multi-agent systems that reliably outperform single agents on tasks requiring decomposition, with clear understanding of when swarms help.

### 1. Behavioral Contracts and Compositional Verification (30%)

**Summary**: Formal specifications for agent behaviors, runtime verification, compositional reasoning.

**Includes:**

- Contract specification language (preconditions, postconditions, invariants)
- Probabilistic contracts with confidence bounds
- Runtime monitoring and violation detection
- Compositional reasoning rules
- Lightweight formal methods integration
**Early milestones:**

- Month 3: Contract DSL specification
- Month 6: Runtime monitor integrated with major framework
- Month 9: Compositional verification for linear pipelines
- Month 12: Benchmark showing violations caught
**North star**: Writing a swarm is like writing a typed program. Contract checker catches errors before deployment.

### 2. Hierarchical Memory with Belief Revision (25%)

**Summary**: Memory architecture maintaining coherence over long horizons with principled belief revision.

**Includes:**

- Working/episodic/semantic memory separation
- Provenance tracking
- Confidence and staleness metadata
- Belief revision with contradiction detection
- Memory consolidation
- Principled forgetting
**Early milestones:**

- Month 3: Memory schema with provenance
- Month 6: Belief revision handling contradictions
- Month 9: Integration demonstrating 10+ session coherence
- Month 12: Benchmark vs. naive RAG
**North star**: Agent working on project for weeks maintains coherent understanding. Knows what it knows and where knowledge came from.

### 3. Ownership-Based Architectures (20%)

**Summary**: Decomposition by domain ownership with shared capabilities.

**Includes:**

- Domain boundary specification
- Interface contracts between domains
- Shared capability injection
- Cross-domain coordination protocols
- Domain knowledge acquisition
**Early milestones:**

- Month 3: Domain specification language
- Month 6: Reference 3-domain implementation
- Month 9: Comparison study vs. skill-based
- Month 12: Guidelines for when to use each
**North star**: Structuring swarm feels like structuring engineering org. Clear ownership, clean interfaces.

### 4. Context Compilation (10%)

**Summary**: Middleware assembling optimal context per invocation.

**Includes:**

- Relevance filtering
- Temporal weighting
- Token budget allocation
- Perspective transformation
- Consistency checking
**Early milestones:**

- Month 3: Architecture specification
- Month 6: Token reduction prototype
- Month 9: Memory integration
- Month 12: Ablation study
**North star**: Each invocation gets precisely needed context, automatically.

### 5. Constrained Self-Modification (10%)

**Summary**: Adaptation within typed DSL safety bounds.

**Includes:**

- Typed DSL with safety invariants
- Capability lattices
- Verified synthesis
- Rollback and audit
- Fitness evaluation
**Early milestones:**

- Month 3: DSL grammar
- Month 6: Type checker rejecting unsafe configs
- Month 9: Self-modification prototype
- Month 12: Adaptation case study
**North star**: Swarms evolve without human intervention for routine changes, but bounded and auditable.

### 6. Observability (5%)

**Summary**: Understanding what swarms do and why they fail.

**Includes:**

- Tracing standards
- Interaction visualization
- Anomaly detection
- Replay and counterfactuals
- Cost attribution
**Early milestones:**

- Month 3: Trace schema
- Month 6: Visualization tool
- Month 9: Anomaly detection
- Month 12: Framework integration
**North star**: Debugging swarms is tractable.

---

## Ecosystem-Level Research Agenda

**What we expect**: Infrastructure for agents from different principals to interact safely. Trust mechanisms, interoperability standards, governance frameworks.

### 1. Trust Frameworks and Verification Protocols (30%)

**Summary**: Infrastructure for establishing and verifying trust between agents without shared principals.

**Includes:**

- Trust levels as explicit parameter
- Runtime verification of counterparty behavior
- Cryptographic commitments and attestations
- Reputation systems robust to manipulation
- Dispute resolution mechanisms
- Trust bootstrapping
**Early milestones:**

- Month 4: Trust level taxonomy
- Month 8: Verification runtime prototype
- Month 12: Reputation system design
- Month 18: Multi-party heterogeneous trust
**North star**: Agent interacts with unknown counterparty, calibrates trust appropriately, verification scales with risk.

### 2. Principal-Agent Authority Specification (25%)

**Summary**: Mechanisms for principals to specify, constrain, and audit agent behavior.

**Includes:**
