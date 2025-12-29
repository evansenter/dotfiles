# RFC Response

Generate a structured response to an RFC-style issue.

## Usage

```
/rfc-response [ISSUE_NUMBER or URL]
```

If no argument provided, uses the current context (e.g., issue being discussed).

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
# Get issue number from argument or current context
ISSUE_NUM="${1:-$(gh issue view --json number -q .number 2>/dev/null)}"

# If URL provided, extract issue number
if [[ "$1" =~ github.com/.*/issues/([0-9]+) ]]; then
  ISSUE_NUM="${BASH_REMATCH[1]}"
fi

# Fetch issue details
gh issue view $ISSUE_NUM --json title,body,number
```

$ARGUMENTS
