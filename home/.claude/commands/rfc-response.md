---
argument-hint: [issue-number or URL] [--post]
description: Generate structured RFC response with assumptions and requirements
---

# RFC Response

Generate a structured response to an RFC-style issue, resolve blocking questions interactively, then optionally post to the issue.

## Usage

```
/rfc-response [ISSUE_NUMBER or URL] [--post]
```

- If no issue argument provided, uses the current context (e.g., issue being discussed)
- `--post`: Automatically post the response to the issue after generating (skips review)

## Instructions

### 1. Fetch the Issue

```bash
# Parse arguments: extract --post flag and issue identifier separately
POST_FLAG=false
ISSUE_ARG=""
for arg in $ARGUMENTS; do
  if [[ "$arg" == "--post" ]]; then
    POST_FLAG=true
  elif [[ -z "$ISSUE_ARG" ]]; then
    ISSUE_ARG="$arg"
  fi
done

# Get issue number from argument or current context
if [[ -n "$ISSUE_ARG" ]]; then
  # If URL provided, extract issue number
  if [[ "$ISSUE_ARG" =~ github.com/.*/issues/([0-9]+) ]]; then
    ISSUE_NUM="${BASH_REMATCH[1]}"
  else
    ISSUE_NUM="$ISSUE_ARG"
  fi
else
  # No argument - try to get from current context
  ISSUE_NUM=$(gh issue view --json number -q .number 2>/dev/null)
fi

# Fetch issue details
gh issue view $ISSUE_NUM --json title,body,number,comments
```

Read the issue carefully, including any linked PRs, related issues, and existing comments.

### 2. Analyze and Draft Response

Generate a draft response with this structure:

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

### 3. Resolve Blocking Questions with User

**Before posting**, use `AskUserQuestion` to resolve any blocking decisions that require human input.

For each blocking decision identified in step 2:
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

### 4. Update Response with Decisions

After receiving user answers:
- Incorporate decisions into the response
- Update the "Blocking Decisions" section to show resolved decisions
- Update "Actionable Requirements" to reflect unblocked items

### 5. Post or Present

**If `--post` flag is present:**
```bash
gh issue comment $ISSUE_NUM --body "<response>"
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

### Key Principles

- Reference specific code/PRs where relevant
- Propose solutions, don't just ask open-ended questions
- Identify blockers explicitly and resolve them interactively
- Separate "needs human decision" from "Claude can proceed"
- Use AskUserQuestion to get decisions before posting, not after
