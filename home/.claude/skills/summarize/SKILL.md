---
name: summarize
description: "Summarize URLs, articles, PDFs, YouTube videos, and audio with the `summarize` CLI when it's installed. Use when the user asks for a summary, TLDR, or the gist of a link or media file."
---

# Summarize

## Summarize CLI (Preferred for URLs/Media)

If the `summarize` CLI is installed, use it for URLs, YouTube, PDFs, and audio:

```bash
# Install
brew install steipete/tap/summarize

# Summarize a URL (recommended model: anthropic/claude-sonnet-5-5)
summarize "https://example.com/article" --model anthropic/claude-sonnet-5-5

# Summarize a PDF
summarize "/path/to/file.pdf" --model anthropic/claude-sonnet-5-5

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

**Recommended model:** `anthropic/claude-sonnet-5-5` (requires ANTHROPIC_API_KEY). Also supports GEMINI_API_KEY, OPENAI_API_KEY, or XAI_API_KEY.

**Set default model:** Add to `~/.summarize/config.json`:
```json
{"model": "anthropic/claude-sonnet-5-5"}
```

## Without the CLI

For code, git history, issues, PRs, and anything the CLI can't reach, read the content directly and summarize it yourself. Lead with what matters most to the reader, keep specific names, numbers, and dates, and size the summary to the material and the question — a PR summary should cover status, key decisions, and blockers.
