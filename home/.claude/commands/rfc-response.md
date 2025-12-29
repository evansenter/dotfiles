---
argument-hint: [issue-number or URL] [--post]
description: Generate structured RFC response with assumptions and requirements
---

# RFC Response

Generate a structured response to an RFC-style issue.

## Usage

```
/rfc-response [ISSUE_NUMBER or URL] [--post]
```

- If no issue argument provided, uses the current context (e.g., issue being discussed)
- `--post`: Automatically post the response to the issue after generating (skips review)

## Instructions

1. **Read the issue** carefully, including any linked PRs or related issues

2. **Generate response** with this structure:

### Context/Learnings
What we learned that's relevant to this RFC.

### Assumptions
| Assumption | Confidence | Impact if Wrong |
|------------|------------|-----------------|
| ... | High/Medium/Low | ... |

### Questions
For each question:
- Why it matters
- Proposed solutions (in preference order)
- What we need confirmed

### Blocking Decisions
Decisions that block progress - be explicit about what's needed and why.

### Actionable Requirements
| # | Requirement | Owner | Blocked By |
|---|-------------|-------|------------|
| 1 | ... | Claude/Human | #N or None |

3. **Key principles**:
   - Reference specific code/PRs where relevant
   - Propose solutions, don't just ask open-ended questions
   - Identify blockers explicitly
   - Separate "needs human decision" from "Claude can proceed"

4. **Argument handling**:

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
gh issue view $ISSUE_NUM --json title,body,number
```

5. **Posting behavior**:
   - If `--post` flag is present: Post the response to the issue immediately after generating
   - If `--post` is used but no issue context exists: Prompt user for issue number before posting
   - Otherwise: Show the response and wait for user review before posting
