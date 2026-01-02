---
argument-hint: <issue-number | URL> [--post]
description: Respond to RFC-style issues with structured analysis
---

# RFC Respond

Respond to existing RFC-style issues with structured analysis, blocking question resolution, and optional auto-posting.

## Usage

```
/rfc-respond <issue-number | URL> [--post]
```

- `<issue-number>` or `<URL>`: The RFC issue to respond to
- `--post`: Automatically post after generating (skips review)
- If no arguments: Infer issue from (in order): PR body on current branch, active [work:N] todo, recent conversation. Prompt if none found.

## Instructions

### 1. Parse Arguments

From `$ARGUMENTS`, extract:
- `<issue-number>` or `<URL>`: The RFC issue to respond to
- `--post`: Auto-post without confirmation

If no issue specified, try to infer from context (PR body, active work todo, recent conversation).

### 2. Fetch the Issue

Determine the issue number from the argument (extract from URL if needed) or current context:

```bash
gh issue view "${ISSUE_NUM}" --json title,body,number,comments
```

Read the issue carefully, including any linked PRs, related issues, and existing comments.

### 3. Analyze and Draft Response

ultrathink: Generate a draft response with this structure:

#### Context/Learnings
What we learned that's relevant to this RFC.

#### Assumptions
| Assumption | Confidence | Impact if Wrong |
|------------|------------|-----------------|
| ... | High/Medium/Low | ... |

#### Questions
For each question:
- Why it matters
- Proposed solutions (in preference order)
- What we need confirmed

#### Blocking Decisions
Decisions that block progress - be explicit about what's needed and why.

#### Actionable Requirements
| # | Requirement | Owner | Blocked By |
|---|-------------|-------|------------|
| 1 | ... | Claude/Human | #N or None |

### 4. Resolve Blocking Questions with User

**Before posting**, use `AskUserQuestion` to resolve any blocking decisions that require human input.

For each blocking decision identified in step 3:
- Convert to an AskUserQuestion with concrete options
- Include your recommended option first (with "(Recommended)" suffix)
- Provide brief descriptions explaining trade-offs

Example:
```json
{
  "questions": [
    {
      "question": "Where should the server be hosted?",
      "header": "Hosting",
      "options": [
        {"label": "Self-hosted (Recommended)", "description": "Run locally, lower cost"},
        {"label": "Cloud VM", "description": "Always-on, ~$5/mo"}
      ],
      "multiSelect": false
    }
  ]
}
```

**Important**:
- Only ask questions that are truly blocking (can't proceed without answer)
- Limit to 1-4 questions per AskUserQuestion call
- If more than 4 blocking questions, prioritize the most critical ones

### 5. Update Response with Decisions

After receiving user answers:
- Incorporate decisions into the response
- Update the "Blocking Decisions" section to show resolved decisions
- Update "Actionable Requirements" to reflect unblocked items

### 6. Post or Present

**If `--post` flag is present:**
```bash
gh issue comment "${ISSUE_NUM}" --body "<response>"
```

Then broadcast to the event bus:
```
mcp__event-bus__publish_event(
  event_type: "rfc_responded",
  payload: "RFC response posted: #<issue_number>",
  channel: "repo:<repo_name>"
)
```

**Otherwise:**
Display the response and ask if user wants to post:
```json
{
  "questions": [
    {
      "question": "Post this response to issue #N?",
      "header": "Post",
      "options": [
        {"label": "Yes, post it", "description": "Add as comment to the issue"},
        {"label": "No, just show me", "description": "Review only, don't post"}
      ],
      "multiSelect": false
    }
  ]
}
```

If user chooses to post, after posting broadcast the event as shown above.

## Key Principles

- Reference specific code/PRs where relevant
- Propose solutions, don't just ask open-ended questions
- Identify blockers explicitly and resolve them interactively
- Separate "needs human decision" from "Claude can proceed"
- Use AskUserQuestion to get decisions before posting, not after
