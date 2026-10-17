---
argument-hint: <topic> [--post] [-R owner/repo]
description: Create an RFC-style issue — problem, proposed solution, alternatives, and implementation plan. Use when a design decision needs discussion before implementation, or the user asks for an RFC.
---

# RFC Create

Write an RFC issue for a design decision that needs discussion, resolving blocking questions with the user before it's filed.

## Usage

```
/rfc-create <topic> [--post] [-R owner/repo]
```

- `--post`: create the issue as soon as blocking questions are resolved, without a final "Create this RFC?" confirmation
- `-R owner/repo`: file it in another repo

## Process

### 1. Gather Context

Start from the topic and what this conversation already established: the problem, relevant files, decisions already made, and where it came up (audit, feature work, bug fix). If references are vague, read the code until you can point at specific files and lines.

### 2. Draft the RFC

ultrathink: Draft the body. Propose a solution and real alternatives, not just questions:

```markdown
## Summary
[One paragraph]

## Problem / Motivation
[What friction was encountered]

## Context
- **Discovered during**: [context]
- **Relevant files**: [files]
- **Related issues/PRs**: [refs]

## Proposed Solution
[High-level approach]

## Alternatives Considered
[Each with why it lost]

## Assumptions
| Assumption | Confidence | Impact if Wrong |
|------------|------------|-----------------|

## Open Questions
1. [Needs human decision]

## Actionable Requirements
| # | Requirement | Owner (Claude/Human) | Blocked By |
|---|-------------|----------------------|------------|

## Test Requirements
- [Behaviors to test, integration scenarios, edge cases]

## Implementation Checklist
- [ ] [Step]
```

### 3. Resolve Blocking Questions

Use AskUserQuestion (up to 4 per call) to confirm the problem statement, the solution direction, and any open question that blocks implementation, and to choose between 2-3 title options starting with "RFC: ". Fold the answers into the body; leave non-blocking questions in Open Questions.

### 4. Label and File

Run `gh label list --json name`. Use exactly one `priority:high|medium|low` label plus relevant type labels.

With `--post`, create it right away; otherwise show the final draft and ask "Create this RFC?". Pass the body via `--body-file -` and a single-quoted heredoc so markdown tables, `[refs]`, and parens aren't shell-evaluated. Add `-R` for a cross-repo target.

Then publish `rfc_created` (payload: `RFC created: #N in <repo> - <title>`) to `repo:<target>` with your session_id.

Report the title, issue URL, key decisions, and any deferred questions.
