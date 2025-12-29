# Cross-Repo Context

Gather context from a related repository.

## Usage

```
/cross-repo <owner/repo> [focus-area]
```

Examples:
- `/cross-repo evansenter/gemicro` - General overview
- `/cross-repo evansenter/gemicro tools` - Focus on tool-related code

## Instructions

1. **Parse arguments:**
   ```bash
   REPO="$1"
   FOCUS="${2:-}"

   if [[ -z "$REPO" ]]; then
     echo "Error: Repository required (e.g., owner/repo)"
     exit 1
   fi
   ```

2. **Fetch repo guidance:**
   ```bash
   # Try CLAUDE.md first, fall back to README (use raw content API for cross-platform compatibility)
   gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/CLAUDE.md" 2>/dev/null || \
   gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/README.md" 2>/dev/null || \
   echo "No CLAUDE.md or README found"
   ```

3. **Fetch open PRs:**
   ```bash
   gh pr list --repo "$REPO" --state open --json number,title,body --limit 10
   ```

4. **Fetch open issues:**
   ```bash
   gh issue list --repo "$REPO" --state open --json number,title,body,labels --limit 15
   ```

5. **If focus-area provided**, search for relevant files:
   ```bash
   if [[ -n "$FOCUS" ]]; then
     # Detect default branch (don't assume main)
     DEFAULT_BRANCH=$(gh api "repos/$REPO" --jq '.default_branch')
     gh api "repos/$REPO/git/trees/$DEFAULT_BRANCH?recursive=1" --jq '.tree[].path' | grep -i "$FOCUS" | head -10
   fi
   ```
   Then fetch key files for context using `gh api -H "Accept: application/vnd.github.raw" "repos/$REPO/contents/<path>"`.

6. **Present summary:**

```markdown
## Cross-Repo Context: <repo>

### Project Overview
[Summary from CLAUDE.md or README - focus on architecture and key patterns]

### Relationship to Current Repo
[If guidance mentions current repo, highlight the connection. Otherwise note "No explicit relationship documented"]

### Open PRs (N total)
| PR | Summary |
|----|---------|
| #N | One-line summary |

### Open Issues (N total)
| Issue | Summary | Labels |
|-------|---------|--------|
| #N | One-line summary | labels |

### Relevant Files [if focus-area provided]
- `path/to/file` - Brief description of what this file does
```

$ARGUMENTS
