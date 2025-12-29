---
argument-hint: [focus-area]
description: Audit codebase for anti-patterns and Evergreen violations
---

Audit this codebase for common code anti-patterns and Evergreen principle violations (ref: https://github.com/google-deepmind/evergreen-spec).

Look for:
- Inconsistent naming conventions (especially helpers/utilities)
- Unnecessary complexity or over-abstraction
- Files that have grown too large and should be split
- Public API surface exposing internal implementation details
- Poor separation of concerns
- Dead code or unused exports
- Duplicated logic that should be consolidated

Review: README, recent commits, open issues, and PRs on GitHub for additional context.

$ARGUMENTS

Output: A comprehensive refactoring plan. Breaking changes are acceptable. Organize by priority and effort.
