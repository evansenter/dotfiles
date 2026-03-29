---
argument-hint: [--no-watch]
description: Commit changes and create/update a PR
---

# PR Create

Commit outstanding changes and create or update a pull request.

## Usage

```
/pr-create [--no-watch]
```

- `--no-watch`: Skip automatic CI monitoring after PR creation

## Instructions

### 1. Check for Changes

```bash
git status --short
```

**Handle edge cases:**
- **Nothing to commit**: If working tree is clean, inform user: "No changes to commit. Make changes first or run `/pr-review local` to review existing code."

### 2. Check for Main Drift

Long-running sessions may drift from main. Before pushing, check if main has advanced:

```bash
git fetch origin main
git log HEAD..origin/main --oneline
```

If main has new commits:
- Inform user: "Main has advanced by N commits since your branch diverged."
- Ask via AskUserQuestion: **Rebase onto main (Recommended)** / Continue without rebase
- If rebase: `git rebase origin/main`, resolve conflicts if needed

### 3. Verify Before Pushing

Use `superpowers:verification-before-completion` to confirm quality gates pass (linter, formatter, tests) before committing. Evidence before assertions — don't assume they pass.

### 4. Create PR

Invoke the commit-push-pr skill:

```
Skill(commit-commands:commit-push-pr)
```

**Handle failures:**
- Report the error and suggest manual steps

### 5. Monitor CI (unless --no-watch)

Unless `--no-watch` was passed, invoke `/watch-ci` to monitor CI status in background. It will automatically run `/pr-review remote` when CI completes.
