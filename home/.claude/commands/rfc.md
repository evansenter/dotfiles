---
argument-hint: [issue-number or --create "Title"] [--post]
description: Create or respond to RFC-style issues with structured analysis
---

# RFC

Create new RFC-style issues or respond to existing ones with structured analysis, blocking question resolution, and optional auto-posting.

## Usage

```
/rfc [ISSUE_NUMBER or URL] [--post]    # Respond to existing issue
/rfc --create "Title" [--post]          # Create new RFC issue
```

- `--post`: Automatically post/create after generating (skips review)
- If no arguments: uses current context (issue being discussed)

## Instructions

### 0. Parse Arguments

```bash
# Parse arguments: extract flags and content
POST_FLAG=false
CREATE_FLAG=false
TITLE=""
ISSUE_ARG=""

# Check for --create flag and extract title
if [[ "$ARGUMENTS" =~ --create[[:space:]]+\"([^\"]+)\" ]]; then
  CREATE_FLAG=true
  TITLE="${BASH_REMATCH[1]}"
elif [[ "$ARGUMENTS" =~ --create[[:space:]]+\'([^\']+)\' ]]; then
  CREATE_FLAG=true
  TITLE="${BASH_REMATCH[1]}"
elif [[ "$ARGUMENTS" =~ --create ]]; then
  CREATE_FLAG=true
  # Title might be unquoted - extract next word
fi

# Check for --post flag
if [[ "$ARGUMENTS" =~ --post ]]; then
  POST_FLAG=true
fi

# Extract issue number if not creating
if [[ "$CREATE_FLAG" == false ]]; then
  for arg in $ARGUMENTS; do
    if [[ "$arg" != "--post" && -z "$ISSUE_ARG" ]]; then
      ISSUE_ARG="$arg"
    fi
  done
fi
```

**If `--create` flag is present:** Jump to [Create New RFC](#create-new-rfc)
**Otherwise:** Continue to [Respond to Existing RFC](#respond-to-existing-rfc)

---

## Respond to Existing RFC

### 1. Fetch the Issue

```bash
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

---

## Create New RFC

### 1. Gather Context

If `TITLE` is empty, use AskUserQuestion to get it:
```json
{
  "questions": [
    {
      "question": "What's the title for this RFC?",
      "header": "Title",
      "options": [
        {"label": "Enter title", "description": "I'll provide the RFC title"}
      ],
      "multiSelect": false
    }
  ]
}
```

Analyze the current conversation for:
- **Problem identified**: What issue or improvement was discovered
- **Relevant code**: Files, functions, patterns discussed
- **Decisions made**: Any choices or constraints already established
- **Context**: How was this discovered (audit, feature work, bug fix)

### 2. Generate RFC Issue Body

Create an RFC-style issue body:

```markdown
## Summary

[One-paragraph description of the problem/improvement]

## Problem / Motivation

[What friction or issue was encountered that motivates this RFC]

## Context

- **Discovered during**: [audit/feature work/bug fix/etc.]
- **Relevant files**: [list key files]
- **Related issues/PRs**: [references if any]

## Proposed Solution

[High-level approach]

## Assumptions

| Assumption | Confidence | Impact if Wrong |
|------------|------------|-----------------|
| ... | High/Medium/Low | ... |

## Open Questions

1. [Question that needs human decision]
2. [Another question]

## Actionable Requirements

| # | Requirement | Owner | Blocked By |
|---|-------------|-------|------------|
| 1 | ... | Claude/Human | None |

## Implementation Checklist

- [ ] [First step]
- [ ] [Next step]
- [ ] ...
```

### 3. Resolve Blocking Questions

Use `AskUserQuestion` to resolve any blocking decisions before creating:
- Confirm the problem statement is accurate
- Validate the proposed solution direction
- Get input on open questions

### 4. Create or Present

**If `--post` flag is present:**
```bash
gh issue create --title "$TITLE" --body "<generated body>"
```

**Otherwise:**
Display the draft and ask:
```json
{
  "questions": [
    {
      "question": "Create this RFC issue?",
      "header": "Create",
      "options": [
        {"label": "Yes, create it", "description": "Create the issue on GitHub"},
        {"label": "No, just show me", "description": "Review only, don't create"}
      ],
      "multiSelect": false
    }
  ]
}
```

After creating, output the issue URL.

---

## Key Principles

- Reference specific code/PRs where relevant
- Propose solutions, don't just ask open-ended questions
- Identify blockers explicitly and resolve them interactively
- Separate "needs human decision" from "Claude can proceed"
- Use AskUserQuestion to get decisions before posting/creating, not after
