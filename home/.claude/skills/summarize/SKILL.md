---
name: summarize
description: Use when asked to summarize URLs, documents, PDFs, code files, git history, or any large body of text into concise output
---

# Summarize

Produce concise, structured summaries of any content.

## Supported Inputs

| Input | How to Access |
|-------|---------------|
| URL/webpage | `WebFetch(url, prompt="Summarize...")` |
| PDF file | `Read(file_path, pages="1-20")` |
| Code file | `Read(file_path)` |
| Git history | `git log --oneline -N` or `gh pr view` |
| GitHub issue/PR | `gh issue view N` or `gh pr view N` |
| Directory | `find` + selective `Read` of key files |

## Output Format

Use this structure unless the user specifies otherwise:

```markdown
## Summary

[2-3 sentence overview]

## Key Points

- [Most important takeaway]
- [Second most important]
- [Third most important]
- ...

## Details

[Optional: deeper context if the content warrants it]
```

## Guidelines

- Lead with the most important information
- Use bullet points over paragraphs
- Include specific numbers, names, and dates when relevant
- For code: focus on what it does, not how (unless asked)
- For PRs/issues: include status, key decisions, blockers
- For long documents: summarize by section, then provide overall summary
- Default to ~200 words unless asked for more/less detail
- Preserve technical accuracy — don't simplify to the point of being wrong
