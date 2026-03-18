---
name: systematic-debugging
description: Use when encountering any bug, test failure, unexpected behavior, error message, or confusing output — before proposing fixes. Also use when a fix attempt fails, when the same error appears twice, when you're tempted to say "let me just try this", or when debugging feels like guessing. This skill MUST be consulted before any fix attempt — even quick ones.
---

# Systematic Debugging

## Core Principle

NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.

Symptom fixes are failure. Systematic debugging is FASTER than guess-and-check thrashing.

## The Four Phases

### Phase 1: Root Cause Investigation

1. Read error messages CAREFULLY and COMPLETELY
2. Reproduce the issue reliably
3. Review recent changes that could cause this
4. Gather diagnostic evidence across system boundaries
5. For multi-layer systems, log data at each boundary to find exactly where failure occurs
6. Trace data flow backward from the error to find the source

### Phase 2: Pattern Analysis

1. Find comparable working code in the codebase
2. Consult reference implementations completely
3. Identify ALL differences between working and broken implementations
4. Understand the dependency chain

### Phase 3: Hypothesis and Testing

1. Form a SPECIFIC hypothesis about the cause
2. Test with MINIMAL changes (one variable at a time)
3. Verify the hypothesis before proceeding
4. If disproved, return to Phase 1 with new information

### Phase 4: Implementation

1. Create a failing test case FIRST
2. Implement targeted fix addressing root cause (not symptoms)
3. Verify the fix resolves the original issue
4. Check for regressions

**CRITICAL**: After 3 failed fix attempts, STOP. Question whether the underlying architecture is sound rather than continuing with patches.

## Red Flags — Return to Phase 1

Stop and restart investigation if you catch yourself:
- Thinking "quick fix for now, investigate later"
- Attempting multiple changes at once
- Proposing solutions without understanding data flow
- Saying "this should work" without evidence
- Skipping phases under time pressure
- Making the same category of fix attempt twice

## Common Rationalizations (All False)

| Excuse | Reality |
|--------|---------|
| "Emergency means skip investigation" | Emergencies need MORE rigor, not less |
| "It's probably just X" | "Probably" means you don't know |
| "Let me just try this real quick" | Quick tries compound into slow debugging |
| "I've seen this before" | Confirm it's actually the same issue |
