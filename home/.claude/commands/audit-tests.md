---
argument-hint: [focus-area]
description: Audit test coverage for redundancy, staleness, and gaps
---

ultrathink: Audit test coverage across the codebase.

Identify:
- Redundant tests (testing same behavior multiple ways)
- Tests that no longer match implementation
- Flaky or brittle test patterns
- Missing coverage for: public API surface, error paths, edge cases, integration points

$ARGUMENTS

If a focus-area is provided, prioritize analysis there but don't ignore other significant issues discovered.

Output: A cleanup plan with deletions, consolidations, and a prioritized list of tests to add. Include rough effort estimates.
