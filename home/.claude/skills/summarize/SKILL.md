---
name: summarize
description: "Use when asked to summarize, condense, or get the gist of anything — URLs, documents, PDFs, YouTube videos, audio, code files, git history, PRs, issues, articles, or any large body of text. Also use when the user says 'what is this', 'TLDR', 'explain this link', 'what happened in this PR', or shares a URL and wants to understand it. If the summarize CLI is installed, prefer it for URLs and media."
---

# Summarize

Produce concise, structured summaries of any content.

## Summarize CLI (Preferred for URLs/Media)

If the `summarize` CLI is installed, use it for URLs, YouTube, PDFs, and audio:

```bash
# Install
brew install steipete/tap/summarize

# Summarize a URL (default model: anthropic/claude-sonnet-4-6)
summarize "https://example.com/article" --model anthropic/claude-sonnet-4-6

# Summarize a PDF
summarize "/path/to/file.pdf" --model anthropic/claude-sonnet-4-6

# Summarize a YouTube video
summarize "https://youtu.be/dQw4w9WgXcQ" --youtube auto

# Control output length
summarize "https://example.com" --length short    # short/medium/long/xl/xxl
summarize "https://example.com" --length 500      # character count

# Extract content without summarizing
summarize "https://example.com" --extract-only

# JSON output
summarize "https://example.com" --json
```

**Configuration:** `~/.summarize/config.json` for default model/preferences.

**Recommended model:** `anthropic/claude-sonnet-4-6` (requires ANTHROPIC_API_KEY). Also supports GEMINI_API_KEY, OPENAI_API_KEY, or XAI_API_KEY.

**Set default model:** Add to `~/.summarize/config.json`:
```json
{"model": "anthropic/claude-sonnet-4-6"}
```

## Built-in Summarization (No CLI Needed)

For content accessible via tools, summarize directly:

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

## Details

[Optional: deeper context if warranted]
```

## Guidelines

- Lead with the most important information
- Use bullet points over paragraphs
- Include specific numbers, names, and dates when relevant
- For code: focus on what it does, not how (unless asked)
- For PRs/issues: include status, key decisions, blockers
- Default to ~200 words unless asked for more/less detail
- Preserve technical accuracy — don't simplify to the point of being wrong
