Audit test coverage across the codebase.

Identify:
- Redundant tests (testing same behavior multiple ways)
- Tests that no longer match implementation
- Flaky or brittle test patterns
- Missing coverage for: public API surface, error paths, edge cases, integration points

$ARGUMENTS

Output: A cleanup plan with deletions, consolidations, and a prioritized list of tests to add. Include rough effort estimates.
