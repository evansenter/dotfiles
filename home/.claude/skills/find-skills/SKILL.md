---
name: find-skills
description: Use when the user asks to find, discover, or install Claude Code skills, or when a task would benefit from a skill that doesn't exist locally
---

# Find Skills

Discover and recommend Claude Code skills from community repositories.

## When to Use

- User asks "is there a skill for X?"
- A task would benefit from specialized domain knowledge not covered by existing skills
- User wants to browse available skills

## How to Search

### 1. Check Local Skills First

```bash
ls ~/.claude/skills/
```

### 2. Search Community Repositories

Search these sources in order:

**Official Anthropic skills:**
```bash
gh api "repos/anthropics/skills/git/trees/main?recursive=1" --jq '.tree[].path' | grep "SKILL.md"
```

**Community curated lists:**
- https://github.com/travisvn/awesome-claude-skills
- https://github.com/VoltAgent/awesome-agent-skills

**Web search for specific domains:**
```
WebSearch("claude code skill <domain> SKILL.md github 2026")
```

### 3. Evaluate Skills

Before recommending, check:
- Does it duplicate an existing local skill?
- Is the source trustworthy (official, well-starred, active)?
- Does it require external tools/CLIs that aren't installed?
- Is the SKILL.md well-structured with clear frontmatter?

### 4. Install

Skills are just SKILL.md files in `~/.claude/skills/<name>/`:

```bash
mkdir -p ~/.claude/skills/<name>
# Fetch and write the SKILL.md
```

If the skill is in a dotfiles repo, add to `home/.claude/skills/<name>/SKILL.md` and run `bootstrap.sh -f`.

## Notes

- Prefer official (anthropics/skills) and well-maintained community skills
- Always review skill content before installing — skills are executable instructions
- Skills auto-apply based on their frontmatter description, no manual invocation needed
