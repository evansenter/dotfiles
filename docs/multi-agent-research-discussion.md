# Multi-Agent Systems Research Discussion

*A conversation about agent swarms, ecosystem coordination, and research priorities.*

---

**Date:** January 2026

**Participants:** Evan, Claude

---

## Opening Question

**Evan:** Give me a rundown on agent swarms. What's the SotA from the field?

**Claude:** Agent swarms are an emerging paradigm for tackling complex tasks by orchestrating multiple specialized LLM agents that collaborate, delegate, and iterate rather than relying on a single monolithic model call.

### Core Architectural Patterns

**Hierarchical orchestration** remains the most common production pattern—a "manager" agent decomposes tasks and routes subtasks to specialist agents (coder, researcher, critic, etc.). This mirrors how you might structure a Claude Code workflow with different MCP servers handling distinct capabilities.

**Peer-to-peer topologies** let agents communicate laterally without a central coordinator. More robust to single-point failures but harder to debug and can lead to coordination overhead that scales poorly.

**Blackboard architectures** use a shared state that agents read from and write to asynchronously—useful when you need loose coupling and agents operating on different timescales.

### Current State of the Art

**AutoGen (Microsoft)** is probably the most mature framework, supporting flexible multi-agent conversations with human-in-the-loop patterns. Their recent work on "GroupChat" allows dynamic agent selection based on conversation context.

**CrewAI** has gained traction for its simpler mental model—you define agents with roles, goals, and tools, then compose them into "crews" with explicit task delegation graphs.

**LangGraph** (from LangChain) offers the most control over state machines and cycles, which matters when you need agents to iterate or backtrack. The graph-based formalism maps well to complex workflows.

**OpenAI's Swarm** (released late 2024) is intentionally minimal—lightweight handoffs between agents with explicit tool-based routing. More of a reference architecture than a framework.

### Research Frontiers

**Learned routing**: Moving beyond hardcoded orchestration to having models learn when to delegate and to whom. Think of it as a mixture-of-experts but at the agent level rather than within the FFN blocks.

**Memory and state management** remains unsolved at scale. Most systems use naive context stuffing or basic RAG. The interesting work is around hierarchical memory (working/episodic/semantic) that mirrors cognitive architectures.

**Emergence vs. explicit coordination**: There's a tension between designing explicit communication protocols versus letting agents develop conventions through interaction. The latter is more elegant but currently unreliable.

**Verification and critique agents**: Using dedicated agents for output validation—essentially building inference-time compute scaling into multi-agent systems. Related to what you'd see in reward model ensembles but more flexible.

### Practical Considerations

The overhead is real. Each agent hop adds latency and token costs. For your Gemini work, you'd recognize the serving complexity—now multiply it by N agents with potentially different models, context windows, and tool configurations.

The debugging story is rough. Tracing failures through multi-agent conversations is painful, and most frameworks have immature observability. This is where explicit state machines (LangGraph style) shine over more implicit orchestration.

Context window management becomes a distributed systems problem. How do you summarize and propagate relevant context without blowing token budgets? Most production systems end up with aggressive summarization or structured handoff protocols.

---

## Deep Dive on Challenges

**Evan:** Tell me more about the challenges across everything above. In particular P2P, blackboard architectures, learned routing, memory / state management, and emergent coordination.

What is the conceptual model for the responsibilities of an agent in these models? Specialization in terms of skills? Why not have ownership boundaries instead and make each agent similarly capable?

What about architectures that are self-evolving (shared global DI that any agent can suggest writing to), or the ability for agents to author complex agents themselves (not just config, actual code, using the same library they are written in)? What are the pros / cons here?

**Claude:** These are the right questions—they get at the fundamental tensions in multi-agent system design that aren't well-resolved yet.

### Challenge Deep Dives

**Peer-to-peer coordination** struggles with the classic distributed systems problems but worse, because the "nodes" are stochastic. You get:

- **Convergence failures**: Agents can enter loops of mutual delegation or contradictory outputs without a tie-breaker. Unlike consensus protocols where nodes follow deterministic rules, LLM agents might interpret the same context differently each time.
- **Credit assignment**: When a swarm succeeds or fails, attributing responsibility for debugging or improvement is nearly intractable. This matters for any online learning or RLHF-style feedback.
- **Bandwidth explosion**: Full peer connectivity means O(n²) communication channels. Most systems cheat by imposing implicit hierarchy or limiting who can talk to whom.
**Blackboard architectures** have different failure modes:

- **Race conditions and stale reads**: Agent A reads state, deliberates for 30 seconds, writes back—but Agent B modified the relevant section in the meantime. You need either pessimistic locking (kills parallelism) or conflict resolution strategies (complex and domain-specific).
- **Schema evolution**: The shared state structure tends to calcify. Early design decisions about what to represent become load-bearing, and changing them requires coordinated updates across all agents.
- **Garbage accumulation**: Without explicit cleanup policies, blackboards accumulate stale hypotheses and intermediate work products. Attention over the blackboard becomes a retrieval problem.
**Learned routing** is appealing but hits several walls:

- **Distribution shift**: The router learns on historical task distributions, but novel tasks may need routing patterns never seen in training. Generalizing the "task → agent assignment" mapping is itself a hard meta-learning problem.
- **Exploration-exploitation**: A learned router will exploit known-good agents, potentially never discovering that a different agent would perform better on certain subtasks. You need exploration strategies, but exploration in production is expensive.
- **Gradient flow**: If you want end-to-end training, you need differentiable handoffs. Most systems punt on this and use RL or bandit approaches, which have high variance and sample complexity.
**Memory and state management** is where I think the field is most undercooked:

- **Abstraction level mismatch**: Raw conversation logs are too granular; high-level summaries lose critical details. The right intermediate representations are task-dependent and poorly understood.
- **Retrieval relevance**: Embedding similarity is a weak proxy for "what information would help this agent right now." The failure mode is retrieving semantically similar but functionally irrelevant context.
- **Temporal reasoning**: Most memory systems treat entries as a flat bag. But order matters—knowing *when* something was learned relative to other events is often crucial. Implementing proper episodic memory with temporal indexing is hard.
- **Memory interference**: In long-running swarms, outdated information can contradict newer findings. Without explicit belief revision mechanisms, agents can act on stale or inconsistent state.
**Emergent coordination** is the most intellectually interesting and least practical:

- **Reproducibility**: Emergent conventions are path-dependent. Two runs of the same swarm might develop incompatible protocols, making debugging and testing nightmarish.
- **Brittleness to perturbation**: A convention that emerged over many interactions might collapse if you swap in a slightly different model version or change a system prompt.
- **Illegibility**: Even if the swarm performs well, understanding *why* is difficult. This is the interpretability problem but at the systems level.
### Conceptual Models for Agent Responsibility

This is the core architectural question, and there are genuinely different schools of thought:

**Skill-based specialization** (the dominant paradigm) says each agent is a narrow expert—one writes code, one critiques, one searches, etc. The appeal is:

- Easier to craft targeted system prompts
- Smaller context windows per agent (only domain-relevant tools and examples)
- Clearer debugging ("the coding agent failed")
But the problems are real:

- Subtask boundaries are often fuzzy; real work doesn't decompose cleanly into "research then code then test"
- Handoff overhead dominates for tasks that require tight integration across skills
- You need the orchestrator to understand all specializations well enough to route correctly
**Ownership-based decomposition** (your alternative) would give each agent a *domain* or *artifact* rather than a skill. Agent A owns the database layer, Agent B owns the API surface, etc. Each is similarly capable but has different context and authority.

This maps better to how human teams often work and has advantages:

- Reduces coordination overhead for changes within a boundary
- Clearer accountability—if the database layer is broken, you know who to ask
- Agents can maintain richer, more coherent context about their domain over time
The challenges:

- Cross-cutting concerns become expensive (a feature touching multiple domains requires multi-agent coordination)
- Capability duplication means more total tokens and potential inconsistency in how similar problems are solved
- Boundary definition is itself hard—Conway's Law applies, and bad boundaries create friction
**Hybrid approaches** are emerging: skill-specialized agents but with domain-specific context injection, or ownership boundaries with specialist consultants available. No clear winner yet.

### Self-Evolving Architectures

**Shared mutable configuration (global DI)** where agents can propose changes to the swarm's own structure:

*Pros:*

- Adaptation to novel task distributions without human intervention
- Can discover non-obvious architectural improvements through search
- Enables meta-learning at the system level
*Cons:*

- **Stability**: A bad mutation can cascade. You need rollback mechanisms, canary deployments, and fitness evaluation—essentially building an immune system.
- **Reward hacking at the meta-level**: Agents might propose changes that make their metrics look good without improving actual outcomes. The Goodhart problem but for architecture.
- **Coordination on change**: If multiple agents propose conflicting modifications, you need governance. Who arbitrates? How do you prevent oscillation?
- **Irreversibility**: Some architectural changes are hard to undo. Deleting an agent might lose learned context; changing communication protocols might break downstream dependencies.
**Agents authoring agents** (actual code generation, not just config):

This is powerful and dangerous in interesting ways.

*Pros:*

- Maximum flexibility—the swarm can create specialists on demand for novel subtasks
- Code is more expressive than config; you can implement genuinely new behaviors
- Self-improvement potential: if agents can modify their own source (or their children's), you get something like evolution
*Cons:*

- **Security and sandboxing**: Arbitrary code execution is the oldest vulnerability. Even in containers, resource exhaustion, network abuse, and subtle data exfiltration are risks. You need proper isolation, and most frameworks don't have it.
- **Verification gap**: How do you know generated code does what it claims? You're relying on the same model that wrote the code to also validate it, or building a separate verification agent with its own failure modes.
- **Combinatorial complexity**: The space of possible agents is vast. Random search won't work; you need structured exploration, which requires understanding what makes an agent effective (which we don't, really).
- **Recursion depth**: Agents creating agents creating agents... Where do you stop? Each layer adds latency and potential for compounding errors. Most systems impose hard depth limits.
- **Semantic drift**: Over many generations of agent-authored agents, the "intent" can drift from the original goals in hard-to-detect ways. This is alignment but at the swarm level.
The most practical implementations I've seen keep the code generation tightly constrained—agents can compose from a fixed library of primitives, or propose code that's reviewed by a verification pipeline before deployment. Full self-modification remains mostly a research curiosity.

### The Meta-Question

What you're circling is whether multi-agent systems should be designed or evolved. The designed approach (explicit skills, handcrafted routing, static architecture) is more controllable but potentially suboptimal. The evolved approach (learned routing, emergent coordination, self-modification) might find better solutions but is harder to trust and debug.

My read is that production systems will remain heavily designed for the foreseeable future, with narrow applications of learning (routing, memory retrieval) where the search space is constrained. Full self-evolution is a research direction that needs better foundations in agent verification and safe meta-learning before it's practical.

The ownership-vs-skills question is worth more attention than it gets—I suspect the right answer is domain-dependent, and the field has defaulted to skills because it's easier to demo, not because it's fundamentally better.

---

## Fruitful Research Paths

**Evan:** What are the likely fruitful paths for addressing these fundamental tensions?

**Claude:** This is where it gets speculative, but here are the directions I think have the best chance of yielding real progress:

### Formal Foundations for Agent Contracts

The field is missing a rigorous way to specify what an agent *should* do, verify that it *did* do it, and compose guarantees across agents. Borrowing from programming languages and distributed systems:

**Behavioral typing for agents**: Define agent interfaces not just by input/output types but by behavioral contracts—preconditions, postconditions, invariants. An agent that claims to be a "code reviewer" would have a formal spec: given code and context, it produces feedback satisfying certain properties (covers security concerns, flags style violations, etc.). This is hard because natural language outputs resist formal specification, but partial progress is possible:

- Structured output schemas with semantic constraints
- Probabilistic contracts ("returns security feedback with p > 0.9")
- Compositional guarantees ("if agent A satisfies spec S_A and agent B satisfies S_B, their composition satisfies S_AB")
This matters for learned routing—if agents have formal capability descriptors, routing becomes constraint satisfaction rather than vibes-based pattern matching.

**Session types for multi-agent protocols**: Session types from concurrent programming specify valid sequences of interactions between parties. Applied to swarms, you could formally define legal conversation patterns.

This constrains emergent coordination—agents can develop conventions, but only within the grammar defined by session types. You get some flexibility without full chaos.

### Hierarchical Memory with Explicit Belief Management

The memory problem needs structure beyond "vector store of past interactions":

**Separation of concerns**:

- *Working memory*: Current task context, actively maintained, aggressive pruning
- *Episodic memory*: Specific interaction traces, indexed temporally, used for few-shot retrieval
- *Semantic memory*: Distilled facts and learned patterns, updated through explicit consolidation
- *Procedural memory*: Learned workflows and heuristics, potentially as executable code or structured plans
**Belief revision mechanisms**: Agents should maintain explicit confidence in stored information and have protocols for updating or retracting beliefs when contradicted. This is classical AI (truth maintenance systems, reason maintenance) that fell out of fashion but is newly relevant. The key insight is that memory isn't just storage—it's an evolving model of the world that needs consistency maintenance.

**Forgetting as a first-class operation**: Most systems only add to memory. Principled forgetting—based on relevance decay, contradiction, or capacity limits—is essential for long-running swarms. The analogy to attention mechanisms is apt: memory retrieval is a form of attention over history, and it needs similar mechanisms for focusing on what matters.

### Verification Agents as Architectural Primitives

Rather than hoping agents are correct, build verification into the architecture:

**Adversarial validation**: For any agent output that matters, route it through a critic trained or prompted to find flaws. This is inference-time compute scaling via debate. The key is making the verifier's job easier than the generator's job—verification should be cheaper than generation for the approach to scale.

**Formal methods integration**: For agents producing structured outputs (code, configs, plans), integrate lightweight formal verification:

- SMT solvers for constraint checking
- Model checking for protocol compliance
- Type checking for generated code
This doesn't verify everything but catches large classes of errors cheaply.

**Execution-based verification**: When possible, actually run the output in a sandboxed environment. Test the generated code, simulate the proposed plan, check the API call against a mock. Ground truth from execution beats LLM-based review.

### Ownership Boundaries with Capability Sharing

On the skills-vs-ownership question, I think the synthesis is:

**Domain ownership with capability injection**: Each agent owns a domain (database, API, frontend) and maintains coherent context about it. But capabilities (code generation, search, reasoning patterns) are shared resources—implemented as tools or as context that can be injected on demand.

This is like microservices with shared libraries: services own their domain logic but import common functionality.

### Constrained Self-Modification

Full self-evolution is too unconstrained, but there's a middle path:

**Typed configuration languages**: Instead of arbitrary code generation, agents propose modifications in a restricted DSL that can only express "safe" changes. The language is designed so any valid program satisfies certain invariants (no infinite loops, bounded resource usage, preserved interfaces).

**Genetic programming with strong selection pressure**: If you want evolutionary dynamics, you need harsh fitness functions. Most generated agents should die quickly. The survivors need to demonstrate value on held-out tasks before being integrated. This is expensive but more controlled than unconstrained mutation.

**Human-in-the-loop for architectural changes**: For modifications above a certain impact threshold (new agents, changed communication patterns, modified ownership boundaries), require human approval. This keeps humans as the ultimate arbiter of system structure while allowing low-risk adaptation autonomously.

**Capability scaffolding**: Rather than agents writing arbitrary agents, agents can *request* new capabilities from a fixed menu, or propose capability combinations. The meta-system instantiates these requests using verified templates. Agents can't create genuinely novel code but can compose from trusted primitives in novel ways.

### Observability and Debuggability

This is underrated. The systems that win in production will be the ones you can actually understand when they break:

**Structured traces**: Every agent interaction should produce machine-readable traces with standardized schemas. Not just logs—structured events that can be queried, visualized, and analyzed.

**Counterfactual tooling**: "What would have happened if Agent B had received this context instead?" The ability to replay interactions with modifications is essential for debugging emergent behavior.

**Anomaly detection on interaction patterns**: Learn what "normal" communication patterns look like and alert on deviations. If two agents suddenly start looping or an agent's output distribution shifts, surface it.

**Causal attribution**: When a swarm fails, automatically generate hypotheses about which agent or interaction was responsible. This is hard but tractable for structured traces—you're looking for points where the execution diverged from successful patterns.

### Where I'd Place Bets

If I were allocating research effort:

1. **Behavioral contracts and compositional verification** (30%)—this is foundational infrastructure that enables everything else
1. **Hierarchical memory with belief revision** (25%)—the current approaches are clearly inadequate for anything long-running
1. **Ownership-based architectures with shared capabilities** (20%)—underexplored and probably better for real applications than pure skill decomposition
1. **Constrained self-modification via typed DSLs** (15%)—the sweet spot between flexibility and safety
1. **Observability tooling** (10%)—less glamorous but high practical impact
The learned routing and emergent coordination directions are intellectually interesting but probably need the above foundations before they're tractable. You can't learn to route well if you can't specify what "well" means, and you can't trust emergent conventions if you can't verify they satisfy basic properties.

The meta-point is that multi-agent systems are recapitulating decades of distributed systems and programming languages research, often without realizing it. The fruitful paths are likely the ones that take those fields seriously rather than hoping LLM magic will somehow avoid their hard-won lessons.

---

## Human in the Loop and Related Points

**Evan:** For convergence, what about having human in the loop driving convergence?

Schema evolution is an interesting point. Similar to how attention is biased towards proximity, as well as beginning / end of context window if I recall correctly. Garbage accumulation seems to fall into the context compression problem.

How does RL or bandits get around gradient flow?

The point on temporal reasoning is a good one, I'd imagine for blackboard models you want metadata that tracks message insertion time as a proxy for staleness. And then for the prompt itself, perhaps you don't actually want to model a flat prompt and instead have a middleware that takes context from caller, and uses that + global knowledge to render a "request specific" meta-prompt. This is similar to ephemeral agents as well, but just in prompt space.

**Claude:** Good instincts on all of these—let me engage with each:

### Human-in-the-Loop for Convergence

This is probably the most practical near-term solution, and it's underexplored because the field is obsessed with full autonomy. The key insight is that humans are remarkably good at the things swarms struggle with:

- **Tie-breaking**: When agents are deadlocked or oscillating, a human can just decide. The cost is latency, but for high-stakes decisions it's worth it.
- **Intent clarification**: Much of convergence failure stems from ambiguous goals. A human saying "no, I meant X not Y" can collapse a large search space instantly.
- **Detecting nonsense**: Humans have strong priors on what "reasonable progress" looks like. An agent loop that looks productive by token count is obviously spinning to a human observer.
The design question is *when* to invoke the human. Options:

**Reactive**: Human monitors and intervenes when they notice problems. Low overhead but depends on attention and catch latency.

**Proactive with thresholds**: System tracks heuristics (turn count without progress, repeated similar messages, confidence drops) and escalates automatically. The thresholds need tuning per domain.

**Structured checkpoints**: Certain decision points always require human approval—architectural changes, external actions, conclusions on ambiguous problems. This is the "human as merge commit approver" model.

**Confidence-gated**: Agents report calibrated uncertainty; low-confidence outputs route to human review. This requires agents to actually be calibrated, which is... variable.

The hybrid I find compelling: mostly autonomous operation with automatic escalation on detected anomalies, plus mandatory human checkpoints for irreversible actions. You get the latency benefits of autonomy for routine work while keeping humans in the loop where it matters.

The deeper point is that "human in the loop" shouldn't be seen as a failure mode or crutch—it's a legitimate architectural component. The goal isn't to remove humans; it's to amplify them. A swarm that can do 90% of work autonomously and surfaces the right 10% for human judgment is enormously valuable even if it never achieves full autonomy.

### RL/Bandits and Gradient Flow

The issue with differentiable routing is that agent handoffs are discrete decisions—you're choosing *which* agent, not blending agent outputs. Discrete choices break gradient flow because you can't backpropagate through an argmax.

**RL gets around this by not requiring gradients through the choice**:

- The router is a policy network that outputs action probabilities (which agent to invoke)
- You sample from the distribution, execute the chosen agent, observe outcome
- Update the policy using policy gradients (REINFORCE, PPO, etc.) which only need the reward signal, not gradients through the downstream agent
The gradient flows through the *policy* (how to choose), not through the *execution* (what the chosen agent does). This is why RL can handle discrete actions generally.

**Bandits are even simpler**:

- Each agent is an "arm" with unknown reward distribution
- You pull arms, observe rewards, update estimates
- No neural network, no gradients at all—just maintaining running statistics and choosing based on UCB, Thompson sampling, etc.
**The tradeoffs**:

- **Sample efficiency**: RL and bandits need many trials to learn good routing. Each trial costs tokens and latency. If your task distribution shifts, you're re-learning.
- **Credit assignment over long horizons**: If routing happens early but reward is only observed at the end, assigning credit to the routing decision is noisy. This is the classic temporal credit assignment problem.
- **Exploration cost**: To learn, you have to try suboptimal routes sometimes. In production, exploration is expensive and potentially user-facing.
### Temporal Reasoning and Request-Specific Meta-Prompts

Your intuition about middleware that renders request-specific prompts is exactly right, and I think this is an underappreciated architectural pattern:

**The model**:

```javascript
Global Knowledge Store (blackboard, memory, learned context)
         ↓
   Context Compiler (middleware)
         ↓ takes: caller context, request specifics, temporal info
         ↓ produces: optimized prompt for this specific invocation
         ↓
     Agent Execution
```

**What the context compiler does**:

- **Relevance filtering**: Given what this request is about, what subset of global knowledge matters?
- **Temporal weighting**: Recent info about this topic gets priority; old info gets summarized or dropped
- **Perspective transformation**: The same fact might be framed differently depending on which agent is asking and why
- **Consistency checking**: Before injecting context, verify it doesn't contradict other injected context
- **Budget allocation**: Given a token budget, decide how to allocate across different context sources
**Date:** January 2026

**Participants:** Evan, Claude

---

## Opening Question

**Evan:** Give me a rundown on agent swarms. What's the SotA from the field?

**Claude:** Agent swarms are an emerging paradigm for tackling complex tasks by orchestrating multiple specialized LLM agents that collaborate, delegate, and iterate rather than relying on a single monolithic model call.

### Core Architectural Patterns

**Hierarchical orchestration** remains the most common production pattern—a "manager" agent decomposes tasks and routes subtasks to specialist agents (coder, researcher, critic, etc.). This mirrors how you might structure a Claude Code workflow with different MCP servers handling distinct capabilities.

**Peer-to-peer topologies** let agents communicate laterally without a central coordinator. More robust to single-point failures but harder to debug and can lead to coordination overhead that scales poorly.

**Blackboard architectures** use a shared state that agents read from and write to asynchronously—useful when you need loose coupling and agents operating on different timescales.

### Current State of the Art

**AutoGen (Microsoft)** is probably the most mature framework, supporting flexible multi-agent conversations with human-in-the-loop patterns. Their recent work on "GroupChat" allows dynamic agent selection based on conversation context.

**CrewAI** has gained traction for its simpler mental model—you define agents with roles, goals, and tools, then compose them into "crews" with explicit task delegation graphs.

**LangGraph** (from LangChain) offers the most control over state machines and cycles, which matters when you need agents to iterate or backtrack. The graph-based formalism maps well to complex workflows.

**OpenAI's Swarm** (released late 2024) is intentionally minimal—lightweight handoffs between agents with explicit tool-based routing. More of a reference architecture than a framework.

### Research Frontiers

**Learned routing**: Moving beyond hardcoded orchestration to having models learn when to delegate and to whom. Think of it as a mixture-of-experts but at the agent level rather than within the FFN blocks.

**Memory and state management** remains unsolved at scale. Most systems use naive context stuffing or basic RAG. The interesting work is around hierarchical memory (working/episodic/semantic) that mirrors cognitive architectures.

**Emergence vs. explicit coordination**: There's a tension between designing explicit communication protocols versus letting agents develop conventions through interaction. The latter is more elegant but currently unreliable.

**Verification and critique agents**: Using dedicated agents for output validation—essentially building inference-time compute scaling into multi-agent systems. Related to what you'd see in reward model ensembles but more flexible.

### Practical Considerations

The overhead is real. Each agent hop adds latency and token costs. For your Gemini work, you'd recognize the serving complexity—now multiply it by N agents with potentially different models, context windows, and tool configurations.

The debugging story is rough. Tracing failures through multi-agent conversations is painful, and most frameworks have immature observability. This is where explicit state machines (LangGraph style) shine over more implicit orchestration.

Context window management becomes a distributed systems problem. How do you summarize and propagate relevant context without blowing token budgets? Most production systems end up with aggressive summarization or structured handoff protocols.

---

## Deep Dive on Challenges

**Evan:** Tell me more about the challenges across everything above. In particular P2P, blackboard architectures, learned routing, memory / state management, and emergent coordination.

What is the conceptual model for the responsibilities of an agent in these models? Specialization in terms of skills? Why not have ownership boundaries instead and make each agent similarly capable?

What about architectures that are self-evolving (shared global DI that any agent can suggest writing to), or the ability for agents to author complex agents themselves (not just config, actual code, using the same library they are written in)? What are the pros / cons here?

**Claude:** These are the right questions—they get at the fundamental tensions in multi-agent system design that aren't well-resolved yet.

### Challenge Deep Dives

**Peer-to-peer coordination** struggles with the classic distributed systems problems but worse, because the "nodes" are stochastic. You get:

- **Convergence failures**: Agents can enter loops of mutual delegation or contradictory outputs without a tie-breaker. Unlike consensus protocols where nodes follow deterministic rules, LLM agents might interpret the same context differently each time.
- **Credit assignment**: When a swarm succeeds or fails, attributing responsibility for debugging or improvement is nearly intractable. This matters for any online learning or RLHF-style feedback.
- **Bandwidth explosion**: Full peer connectivity means O(n²) communication channels. Most systems cheat by imposing implicit hierarchy or limiting who can talk to whom.
**Blackboard architectures** have different failure modes:

- **Race conditions and stale reads**: Agent A reads state, deliberates for 30 seconds, writes back—but Agent B modified the relevant section in the meantime. You need either pessimistic locking (kills parallelism) or conflict resolution strategies (complex and domain-specific).
- **Schema evolution**: The shared state structure tends to calcify. Early design decisions about what to represent become load-bearing, and changing them requires coordinated updates across all agents.
- **Garbage accumulation**: Without explicit cleanup policies, blackboards accumulate stale hypotheses and intermediate work products. Attention over the blackboard becomes a retrieval problem.
**Learned routing** is appealing but hits several walls:

- **Distribution shift**: The router learns on historical task distributions, but novel tasks may need routing patterns never seen in training. Generalizing the "task → agent assignment" mapping is itself a hard meta-learning problem.
- **Exploration-exploitation**: A learned router will exploit known-good agents, potentially never discovering that a different agent would perform better on certain subtasks. You need exploration strategies, but exploration in production is expensive.
- **Gradient flow**: If you want end-to-end training, you need differentiable handoffs. Most systems punt on this and use RL or bandit approaches, which have high variance and sample complexity.
**Memory and state management** is where I think the field is most undercooked:

- **Abstraction level mismatch**: Raw conversation logs are too granular; high-level summaries lose critical details. The right intermediate representations are task-dependent and poorly understood.
- **Retrieval relevance**: Embedding similarity is a weak proxy for "what information would help this agent right now." The failure mode is retrieving semantically similar but functionally irrelevant context.
- **Temporal reasoning**: Most memory systems treat entries as a flat bag. But order matters—knowing *when* something was learned relative to other events is often crucial. Implementing proper episodic memory with temporal indexing is hard.
- **Memory interference**: In long-running swarms, outdated information can contradict newer findings. Without explicit belief revision mechanisms, agents can act on stale or inconsistent state.
**Emergent coordination** is the most intellectually interesting and least practical:

- **Reproducibility**: Emergent conventions are path-dependent. Two runs of the same swarm might develop incompatible protocols, making debugging and testing nightmarish.
- **Brittleness to perturbation**: A convention that emerged over many interactions might collapse if you swap in a slightly different model version or change a system prompt.
- **Illegibility**: Even if the swarm performs well, understanding *why* is difficult. This is the interpretability problem but at the systems level.
### Conceptual Models for Agent Responsibility

This is the core architectural question, and there are genuinely different schools of thought:

**Skill-based specialization** (the dominant paradigm) says each agent is a narrow expert—one writes code, one critiques, one searches, etc. The appeal is:

- Easier to craft targeted system prompts
- Smaller context windows per agent (only domain-relevant tools and examples)
- Clearer debugging ("the coding agent failed")
But the problems are real:

- Subtask boundaries are often fuzzy; real work doesn't decompose cleanly into "research then code then test"
- Handoff overhead dominates for tasks that require tight integration across skills
- You need the orchestrator to understand all specializations well enough to route correctly
**Ownership-based decomposition** (your alternative) would give each agent a *domain* or *artifact* rather than a skill. Agent A owns the database layer, Agent B owns the API surface, etc. Each is similarly capable but has different context and authority.

This maps better to how human teams often work and has advantages:

- Reduces coordination overhead for changes within a boundary
- Clearer accountability—if the database layer is broken, you know who to ask
- Agents can maintain richer, more coherent context about their domain over time
The challenges:

- Cross-cutting concerns become expensive (a feature touching multiple domains requires multi-agent coordination)
- Capability duplication means more total tokens and potential inconsistency in how similar problems are solved
- Boundary definition is itself hard—Conway's Law applies, and bad boundaries create friction
**Hybrid approaches** are emerging: skill-specialized agents but with domain-specific context injection, or ownership boundaries with specialist consultants available. No clear winner yet.

### Self-Evolving Architectures

**Shared mutable configuration (global DI)** where agents can propose changes to the swarm's own structure:

*Pros:*

- Adaptation to novel task distributions without human intervention
- Can discover non-obvious architectural improvements through search
- Enables meta-learning at the system level
*Cons:*

- **Stability**: A bad mutation can cascade. You need rollback mechanisms, canary deployments, and fitness evaluation—essentially building an immune system.
- **Reward hacking at the meta-level**: Agents might propose changes that make their metrics look good without improving actual outcomes. The Goodhart problem but for architecture.
- **Coordination on change**: If multiple agents propose conflicting modifications, you need governance. Who arbitrates? How do you prevent oscillation?
- **Irreversibility**: Some architectural changes are hard to undo. Deleting an agent might lose learned context; changing communication protocols might break downstream dependencies.
**Agents authoring agents** (actual code generation, not just config):

This is powerful and dangerous in interesting ways.

*Pros:*

- Maximum flexibility—the swarm can create specialists on demand for novel subtasks
- Code is more expressive than config; you can implement genuinely new behaviors
- Self-improvement potential: if agents can modify their own source (or their children's), you get something like evolution
*Cons:*

- **Security and sandboxing**: Arbitrary code execution is the oldest vulnerability. Even in containers, resource exhaustion, network abuse, and subtle data exfiltration are risks. You need proper isolation, and most frameworks don't have it.
- **Verification gap**: How do you know generated code does what it claims? You're relying on the same model that wrote the code to also validate it, or building a separate verification agent with its own failure modes.
- **Combinatorial complexity**: The space of possible agents is vast. Random search won't work; you need structured exploration, which requires understanding what makes an agent effective (which we don't, really).
- **Recursion depth**: Agents creating agents creating agents... Where do you stop? Each layer adds latency and potential for compounding errors. Most systems impose hard depth limits.
- **Semantic drift**: Over many generations of agent-authored agents, the "intent" can drift from the original goals in hard-to-detect ways. This is alignment but at the swarm level.
The most practical implementations I've seen keep the code generation tightly constrained—agents can compose from a fixed library of primitives, or propose code that's reviewed by a verification pipeline before deployment. Full self-modification remains mostly a research curiosity.

### The Meta-Question

What you're circling is whether multi-agent systems should be designed or evolved. The designed approach (explicit skills, handcrafted routing, static architecture) is more controllable but potentially suboptimal. The evolved approach (learned routing, emergent coordination, self-modification) might find better solutions but is harder to trust and debug.

My read is that production systems will remain heavily designed for the foreseeable future, with narrow applications of learning (routing, memory retrieval) where the search space is constrained. Full self-evolution is a research direction that needs better foundations in agent verification and safe meta-learning before it's practical.

The ownership-vs-skills question is worth more attention than it gets—I suspect the right answer is domain-dependent, and the field has defaulted to skills because it's easier to demo, not because it's fundamentally better.

---

## Fruitful Research Paths

**Evan:** What are the likely fruitful paths for addressing these fundamental tensions?

**Claude:** This is where it gets speculative, but here are the directions I think have the best chance of yielding real progress:

### Formal Foundations for Agent Contracts

The field is missing a rigorous way to specify what an agent *should* do, verify that it *did* do it, and compose guarantees across agents. Borrowing from programming languages and distributed systems:

**Behavioral typing for agents**: Define agent interfaces not just by input/output types but by behavioral contracts—preconditions, postconditions, invariants. An agent that claims to be a "code reviewer" would have a formal spec: given code and context, it produces feedback satisfying certain properties (covers security concerns, flags style violations, etc.). This is hard because natural language outputs resist formal specification, but partial progress is possible:

- Structured output schemas with semantic constraints
- Probabilistic contracts ("returns security feedback with p > 0.9")
- Compositional guarantees ("if agent A satisfies spec S_A and agent B satisfies S_B, their composition satisfies S_AB")
This matters for learned routing—if agents have formal capability descriptors, routing becomes constraint satisfaction rather than vibes-based pattern matching.

**Session types for multi-agent protocols**: Session types from concurrent programming specify valid sequences of interactions between parties. Applied to swarms, you could formally define legal conversation patterns.

This constrains emergent coordination—agents can develop conventions, but only within the grammar defined by session types. You get some flexibility without full chaos.

### Hierarchical Memory with Explicit Belief Management

The memory problem needs structure beyond "vector store of past interactions":

**Separation of concerns**:

- *Working memory*: Current task context, actively maintained, aggressive pruning
- *Episodic memory*: Specific interaction traces, indexed temporally, used for few-shot retrieval
- *Semantic memory*: Distilled facts and learned patterns, updated through explicit consolidation
- *Procedural memory*: Learned workflows and heuristics, potentially as executable code or structured plans
**Belief revision mechanisms**: Agents should maintain explicit confidence in stored information and have protocols for updating or retracting beliefs when contradicted. This is classical AI (truth maintenance systems, reason maintenance) that fell out of fashion but is newly relevant. The key insight is that memory isn't just storage—it's an evolving model of the world that needs consistency maintenance.

**Forgetting as a first-class operation**: Most systems only add to memory. Principled forgetting—based on relevance decay, contradiction, or capacity limits—is essential for long-running swarms. The analogy to attention mechanisms is apt: memory retrieval is a form of attention over history, and it needs similar mechanisms for focusing on what matters.

### Verification Agents as Architectural Primitives

Rather than hoping agents are correct, build verification into the architecture:

**Adversarial validation**: For any agent output that matters, route it through a critic trained or prompted to find flaws. This is inference-time compute scaling via debate. The key is making the verifier's job easier than the generator's job—verification should be cheaper than generation for the approach to scale.

**Formal methods integration**: For agents producing structured outputs (code, configs, plans), integrate lightweight formal verification:

- SMT solvers for constraint checking
- Model checking for protocol compliance
- Type checking for generated code
This doesn't verify everything but catches large classes of errors cheaply.

**Execution-based verification**: When possible, actually run the output in a sandboxed environment. Test the generated code, simulate the proposed plan, check the API call against a mock. Ground truth from execution beats LLM-based review.

### Ownership Boundaries with Capability Sharing

On the skills-vs-ownership question, I think the synthesis is:

**Domain ownership with capability injection**: Each agent owns a domain (database, API, frontend) and maintains coherent context about it. But capabilities (code generation, search, reasoning patterns) are shared resources—implemented as tools or as context that can be injected on demand.

This is like microservices with shared libraries: services own their domain logic but import common functionality.

### Constrained Self-Modification

Full self-evolution is too unconstrained, but there's a middle path:

**Typed configuration languages**: Instead of arbitrary code generation, agents propose modifications in a restricted DSL that can only express "safe" changes. The language is designed so any valid program satisfies certain invariants (no infinite loops, bounded resource usage, preserved interfaces).

**Genetic programming with strong selection pressure**: If you want evolutionary dynamics, you need harsh fitness functions. Most generated agents should die quickly. The survivors need to demonstrate value on held-out tasks before being integrated. This is expensive but more controlled than unconstrained mutation.

**Human-in-the-loop for architectural changes**: For modifications above a certain impact threshold (new agents, changed communication patterns, modified ownership boundaries), require human approval. This keeps humans as the ultimate arbiter of system structure while allowing low-risk adaptation autonomously.

**Capability scaffolding**: Rather than agents writing arbitrary agents, agents can *request* new capabilities from a fixed menu, or propose capability combinations. The meta-system instantiates these requests using verified templates. Agents can't create genuinely novel code but can compose from trusted primitives in novel ways.

### Observability and Debuggability

This is underrated. The systems that win in production will be the ones you can actually understand when they break:

**Structured traces**: Every agent interaction should produce machine-readable traces with standardized schemas. Not just logs—structured events that can be queried, visualized, and analyzed.

**Counterfactual tooling**: "What would have happened if Agent B had received this context instead?" The ability to replay interactions with modifications is essential for debugging emergent behavior.

**Anomaly detection on interaction patterns**: Learn what "normal" communication patterns look like and alert on deviations. If two agents suddenly start looping or an agent's output distribution shifts, surface it.

**Causal attribution**: When a swarm fails, automatically generate hypotheses about which agent or interaction was responsible. This is hard but tractable for structured traces—you're looking for points where the execution diverged from successful patterns.

### Where I'd Place Bets

If I were allocating research effort:

1. **Behavioral contracts and compositional verification** (30%)—this is foundational infrastructure that enables everything else
1. **Hierarchical memory with belief revision** (25%)—the current approaches are clearly inadequate for anything long-running
1. **Ownership-based architectures with shared capabilities** (20%)—underexplored and probably better for real applications than pure skill decomposition
1. **Constrained self-modification via typed DSLs** (15%)—the sweet spot between flexibility and safety
1. **Observability tooling** (10%)—less glamorous but high practical impact
The learned routing and emergent coordination directions are intellectually interesting but probably need the above foundations before they're tractable. You can't learn to route well if you can't specify what "well" means, and you can't trust emergent conventions if you can't verify they satisfy basic properties.

The meta-point is that multi-agent systems are recapitulating decades of distributed systems and programming languages research, often without realizing it. The fruitful paths are likely the ones that take those fields seriously rather than hoping LLM magic will somehow avoid their hard-won lessons.

---

## Human in the Loop and Related Points

**Evan:** For convergence, what about having human in the loop driving convergence?

Schema evolution is an interesting point. Similar to how attention is biased towards proximity, as well as beginning / end of context window if I recall correctly. Garbage accumulation seems to fall into the context compression problem.

How does RL or bandits get around gradient flow?

The point on temporal reasoning is a good one, I'd imagine for blackboard models you want metadata that tracks message insertion time as a proxy for staleness. And then for the prompt itself, perhaps you don't actually want to model a flat prompt and instead have a middleware that takes context from caller, and uses that + global knowledge to render a "request specific" meta-prompt. This is similar to ephemeral agents as well, but just in prompt space.

**Claude:** Good instincts on all of these—let me engage with each:

### Human-in-the-Loop for Convergence

This is probably the most practical near-term solution, and it's underexplored because the field is obsessed with full autonomy. The key insight is that humans are remarkably good at the things swarms struggle with:

- **Tie-breaking**: When agents are deadlocked or oscillating, a human can just decide. The cost is latency, but for high-stakes decisions it's worth it.
- **Intent clarification**: Much of convergence failure stems from ambiguous goals. A human saying "no, I meant X not Y" can collapse a large search space instantly.
- **Detecting nonsense**: Humans have strong priors on what "reasonable progress" looks like. An agent loop that looks productive by token count is obviously spinning to a human observer.
The design question is *when* to invoke the human. Options:

**Reactive**: Human monitors and intervenes when they notice problems. Low overhead but depends on attention and catch latency.

**Proactive with thresholds**: System tracks heuristics (turn count without progress, repeated similar messages, confidence drops) and escalates automatically. The thresholds need tuning per domain.

**Structured checkpoints**: Certain decision points always require human approval—architectural changes, external actions, conclusions on ambiguous problems. This is the "human as merge commit approver" model.

**Confidence-gated**: Agents report calibrated uncertainty; low-confidence outputs route to human review. This requires agents to actually be calibrated, which is... variable.

The hybrid I find compelling: mostly autonomous operation with automatic escalation on detected anomalies, plus mandatory human checkpoints for irreversible actions. You get the latency benefits of autonomy for routine work while keeping humans in the loop where it matters.

The deeper point is that "human in the loop" shouldn't be seen as a failure mode or crutch—it's a legitimate architectural component. The goal isn't to remove humans; it's to amplify them. A swarm that can do 90% of work autonomously and surfaces the right 10% for human judgment is enormously valuable even if it never achieves full autonomy.

### RL/Bandits and Gradient Flow

The issue with differentiable routing is that agent handoffs are discrete decisions—you're choosing *which* agent, not blending agent outputs. Discrete choices break gradient flow because you can't backpropagate through an argmax.

**RL gets around this by not requiring gradients through the choice**:

- The router is a policy network that outputs action probabilities (which agent to invoke)
- You sample from the distribution, execute the chosen agent, observe outcome
- Update the policy using policy gradients (REINFORCE, PPO, etc.) which only need the reward signal, not gradients through the downstream agent
The gradient flows through the *policy* (how to choose), not through the *execution* (what the chosen agent does). This is why RL can handle discrete actions generally.

**Bandits are even simpler**:

- Each agent is an "arm" with unknown reward distribution
- You pull arms, observe rewards, update estimates
- No neural network, no gradients at all—just maintaining running statistics and choosing based on UCB, Thompson sampling, etc.
**The tradeoffs**:

- **Sample efficiency**: RL and bandits need many trials to learn good routing. Each trial costs tokens and latency. If your task distribution shifts, you're re-learning.
- **Credit assignment over long horizons**: If routing happens early but reward is only observed at the end, assigning credit to the routing decision is noisy. This is the classic temporal credit assignment problem.
- **Exploration cost**: To learn, you have to try suboptimal routes sometimes. In production, exploration is expensive and potentially user-facing.
### Temporal Reasoning and Request-Specific Meta-Prompts

Your intuition about middleware that renders request-specific prompts is exactly right, and I think this is an underappreciated architectural pattern:

**The model**:

```javascript
Global Knowledge Store (blackboard, memory, learned context)
         ↓
   Context Compiler (middleware)
         ↓ takes: caller context, request specifics, temporal info
         ↓ produces: optimized prompt for this specific invocation
         ↓
     Agent Execution
```

**What the context compiler does**:

- **Relevance filtering**: Given what this request is about, what subset of global knowledge matters?
- **Temporal weighting**: Recent info about this topic gets priority; old info gets summarized or dropped
- **Perspective transformation**: The same fact might be framed differently depending on which agent is asking and why
- **Consistency checking**: Before injecting context, verify it doesn't contradict other injected context
- **Budget allocation**: Given a token budget, decide how to allocate across different context sources
**This is "ephemeral agents in prompt space"** as you say—each invocation gets a purpose-built prompt that may never exist again in exactly that form. The agent code/weights are constant, but the effective agent varies per request.

---

## State of the Art Examples

**Evan:** What are some SotA examples of this? "Hybrid approaches are emerging: skill-specialized agents but with domain-specific context injection, or ownership boundaries with specialist consultants available."

**Claude:** Honestly, the "state of the art" here is less impressive than the framing suggests. Most production systems are still fairly crude, and the academic work tends toward toy domains. Let me give you an honest landscape:

### What Actually Exists

**Devin and similar coding agents** (Cognition, Factory, etc.) are probably the closest to the hybrid model in production. The architecture, as best as anyone can tell from outside:

- Core agent with persistent context about the codebase (ownership-ish)
- Specialized capabilities invoked as needed: planning, code generation, test writing, debugging
- The "domain context" is the repository state, LSP information, test results—continuously updated
- Not really multiple agents in the swarm sense; more like one agent with mode-switching and rich tool use
This is less "agent swarm" and more "single agent with sophisticated context management and tool routing." The ownership is implicit in the codebase context; the skills are implicit in the tool/prompt selection.

**Claude Code with MCP servers** is architecturally similar—one agent, but the MCP servers provide domain-specific capabilities (filesystem, git, database, external APIs). You could squint and call each MCP server a "specialist consultant," but it's really tool use, not agent collaboration. The domain context is whatever you've loaded into the conversation plus what the servers can retrieve.

**AutoGen's GroupChat** is closer to true multi-agent with hybrid characteristics:

- You define agents with different personas and capabilities
- A "speaker selection" mechanism (can be round-robin, LLM-based, or custom) routes conversation
- Agents can maintain their own context while sharing a conversation history
- You *can* set up ownership boundaries (Agent A is the "database expert" who maintains schema context) with skill specialists available
But in practice, most AutoGen deployments I've seen are pure skill decomposition—coder, reviewer, tester—without real ownership semantics.

### The Honest Assessment

I've been somewhat charitable to the field. The reality is that most "multi-agent" systems in production are:

1. Single agent with tools (Claude Code, Cursor, Copilot)
1. Simple pipelines with fixed handoffs (generate → review → revise)
1. Research demos that work on constrained domains but don't generalize
The hybrid architectures we're discussing are more "obviously good ideas that should exist" than "state of the art implementations you can use today." The frameworks support the patterns, but the community hasn't converged on them because simpler approaches work well enough for current applications.

This is an opportunity if you're building in this space—the sophisticated architectures are underexplored precisely because everyone's still getting mileage out of simpler approaches. As tasks get more complex and long-running, the limitations of single-agent and pure-skill-decomposition will bite harder, and hybrid models will become necessary rather than optional.

---

## Detailed Research Priorities

**Evan:** [Referencing the 5 research areas] Tell me more about what you think would be compelling exploration directions for each of these, what the North Star solution might look like, and what SotA is today.

**Claude:** This is a big question—let me give each the depth it deserves.

[Extended discussion of each of the 5 areas with current state, exploration directions, and north stars - see summary document for full details]

---

## Lessons from Adjacent Fields

**Evan:** What were the biggest challenges that distributed systems and programming language research encountered and overcame, that this field might ignore?

What insights can we take from systems biology, evolutionary theory, or cognitive psychology? Any other related fields? (Complex systems / chaos theory in physics?)

**Claude:** These are the right analogies to draw from. Let me go deep on each.

### Lessons from Distributed Systems

**The impossibility results**: Distributed systems had to confront fundamental limits early. CAP theorem, FLP impossibility, Byzantine generals. These results were initially demoralizing but ultimately clarifying—they told you what tradeoffs were *necessary* rather than *incidental*.

The multi-agent field hasn't internalized its impossibility results yet. There probably are fundamental limits on what's achievable with stochastic agents communicating via natural language.

**Failure as the normal case**: Early distributed systems were designed assuming failures were exceptional. The field matured when it accepted that failures are *constant*.

Multi-agent systems still treat agent failures (hallucinations, refusals, nonsense outputs) as bugs to fix rather than constants to design around.

**The coordination cost isn't incidental**: Distributed systems discovered that coordination has irreducible costs. You can't make coordination "free" through clever design.

**The eight fallacies of multi-agent computing**:

1. The agent always understands the request
1. Context is lossless across handoffs
1. All agents share the same implicit assumptions
1. Agent outputs are consistent and reproducible
1. Coordination is cheap
1. The orchestrator knows best
1. More agents means better results
1. Agent failures are obvious
### Lessons from Programming Languages

**Type systems as proactive error prevention**: The evolution toward static type systems moved error detection earlier. The multi-agent equivalent is catching agent errors as early as possible.

**Abstraction without penalty**: Languages struggled with the "abstraction tax." Multi-agent systems have a huge abstraction tax—more agents costs tokens and latency.

**Effect systems**: Beyond types that say what *data* a function touches, effect systems say what *effects* it can have. Multi-agent equivalent: specifying what effects an agent can have (external API calls, state modifications, user-visible outputs).

### Lessons from Systems Biology

**Robustness through redundancy and degeneracy**: Biological systems achieve robustness through structurally different components that can perform similar functions.

**Feedback loops and homeostasis**: Biological systems maintain stability through constant feedback and adjustment. Multi-agent systems usually lack feedback.

**Bow-tie architectures**: Diverse inputs, constrained middle (core metabolism), diverse outputs. The constrained middle provides robustness.

### Lessons from Evolutionary Theory

**Selection requires variation and heritability**: For multi-agent self-modification you need variation, selection pressure, and heritability.

**Fitness landscapes and local optima**: Multi-agent architecture space is probably rugged. Simple hill-climbing will get stuck.

**Baldwin effect**: Learned behaviors can become instincts over evolutionary time. Multi-agent equivalent: capabilities that agents learn at runtime could be consolidated into base architecture.

### Lessons from Cognitive Psychology

**Working memory limits**: Design for bounded working memory with explicit chunking and external memory access.

**Dual-process theory**: Most agent calls should be fast and cheap (System 1). Expensive deliberation reserved for high-stakes decisions.

**Metacognition**: Agents need calibrated confidence, awareness of what additional information would help.

### Lessons from Complex Systems

**Sensitivity to initial conditions**: Two runs of the same swarm might diverge completely from minor variations.

**Attractors**: Multi-agent systems might have behavioral attractors—patterns of interaction they fall into.

**Edge of chaos**: Too ordered is brittle; too chaotic is useless. The edge is where interesting computation happens.

---

## Questions Not Asked

**Evan:** What haven't I asked? What connections to other fields haven't I drawn? What else should I know?

**Claude:** Let me think about the gaps.

### Questions You Didn't Ask

**What happens when swarms interact with other swarms?** Everything we discussed assumes a swarm operating in isolation. But the world is moving toward swarms negotiating on behalf of humans.

**What's the security model?** Swarms have attack surfaces that single agents don't: inter-agent prompt injection, coordination disruption, agent impersonation, capability escalation.

**What about the economic dynamics?** Who captures value in a multi-agent world?

**What does deployment and operations look like?** How do you version a swarm? How do you do staged rollouts? What's the incident response playbook?

**What's the regulatory picture?** If a swarm makes a decision that harms someone, who's liable?

### Fields You Didn't Draw Connections To

**Economics and Mechanism Design**: Multi-agent systems are economies. Agents have incentives, resources, and interactions.

**Organizational Theory and Management Science**: Span of control, centralization vs. decentralization, matrix organizations, Conway's Law, knowledge management.

**Ecology and Ecosystem Dynamics**: Niche differentiation, keystone species, trophic cascades, succession.

**Neuroscience and Brain Architecture**: Modularity and integration, predictive processing, attention as resource allocation.

**Control Theory**: Feedback and stability, observability and controllability, optimal control, robust control.

**Philosophy of Mind and Collective Intentionality**: When does a swarm have "intentions" as a collective?

### The Big Picture View

**Multi-agent is a hypothesis, not a solution.** The hypothesis is that decomposing intelligence into coordinated components produces better outcomes than monolithic systems. This hypothesis is plausible but unproven for LLM-based systems.

**The field is running ahead of its foundations.** People are building swarms without knowing when they help, how to evaluate them, or how to make them reliable.

**The interesting questions are architectural, not algorithmic.** What's the right decomposition? What coordination primitives matter?

**The answers will come from interdisciplinary thinking.** The problems in multi-agent systems are old problems in new clothes.

My honest prediction: multi-agent will matter for a narrower set of problems than the hype suggests, but for those problems, it will matter a lot.

---

## Capability Absorption and Ecosystem Framing

**Evan:** I was thinking about this a little bit more, you mention there's a parallel with agentic capabilities being pushed downwards into the model / LLM layer (e.g. RL on instruction following, verifiable rewards, MoE as a model layer equivalent of multi agent at the FFN layer), how does that apply here?

And your point on swarm <-> swarm communication is an interesting one, because even taking the perspective that single agent is sufficient, isn't the deployment of those systems into an environment where single agents are working with each other itself a kind of swarm? And again, that suggests that ownership-based decomposition models are relevant either way, since the common single agent approaches generally act as delegate obo their human principal.

**Claude:** You've identified something important. Let me pull on both threads.

### The Downward Pressure of Capabilities

**Design swarm primitives as if they'll be used at ecosystem scale.**

Don't build coordination assuming all agents are trusted.

Don't build information sharing assuming it's free.

Don't build contracts assuming they're internal documentation.

Don't build observability assuming it's for debugging.

---

## Items Left Off the Table

**Evan:** Looking over "Projecting Ecosystem Coordination Back into Swarm Research", what are we leaving off the table here with this revised list?

**Claude:** You're right—I dropped some threads that shouldn't be dropped.

### What I Dropped and Why

**Hierarchical Memory**: I implicitly absorbed this into "things individual agents need." But memory becomes *more* important at ecosystem scale.

- Cross-session state with external agents
- Belief revision under adversarial conditions
- Reputation as memory
**Self-Modification**: I framed it as attack surface, but it's essential for ecosystem participation.

- Adaptation to counterparty patterns
- Protocol evolution
- Learning from ecosystem experience
**Request-Specific Meta-Prompts**: Essential for ecosystem participation.

- Context compilation for cross-boundary interactions
- Dynamic capability presentation
- Information filtering at boundaries
### The Connections Between Dropped Items

The items I dropped are deeply connected:

**Memory + Context Compilation**: The context compiler draws from memory.

**Memory + Self-Modification**: Belief revision is a form of self-modification.

**Context Compilation + Self-Modification**: The compilation logic itself might adapt over time.

**All Three + Trust**: How you do memory, context compilation, and modification all depend on trust levels.

There's a coherent subsystem here: **Adaptive Context Management**

---

## The Layered Architecture

**Structure → Verification → Cognition, with Observation spanning all**

**Structure Layer**: Static architecture—how components are organized, interfaces, protocols.

**Verification Layer**: Runtime checking—verification, trust assessment, constraint enforcement.

**Cognition Layer**: Adaptive intelligence—memory, context, learning, belief revision.

**Observation Layer**: Understanding what's happening across all layers.

**For Swarm**: Emphasis on Cognition (40%).

**For Ecosystem**: Emphasis on Structure (40%) and Verification (35%).

**The insight**: Swarm research is primarily about building intelligent systems. Ecosystem research is primarily about building trustworthy systems.

---

## Moonshots

### What's Robust Across Moonshots

**Highly robust:**

- Principal-agent authority and constraints
- Observability and audit
- Security fundamentals
- The *problem* of ecosystem coordination
**Fragile:**

- Specific memory architectures
- External multi-agent coordination
- Complex verification scaffolding
- Protocol design
### The Meta-Strategy

Build things useful *now* whose lessons transfer even if scaffolding becomes unnecessary.

The worst outcome isn't research becoming unnecessary—it's continuing on problems that stopped mattering while ignoring problems that emerged.

---

**[End of Transcript]**
