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

### 3. Run Quality Gates

Run the repo's linter, formatter, and tests (see its CLAUDE.md) and confirm they pass before committing. Report failures with their output rather than pushing past them.

### 4. Live-validate runtime behavior (if applicable)

If this returns a match, propose a live-validation step via AskUserQuestion before creating the PR:

```bash
git diff --name-only main...HEAD | grep -qE '^home/\.claude/(hooks/|settings\.json$)'
```

CI tests static fixtures, not actual behavior in a real Claude session. For **behavioral guards** (hooks/lints/policies that BLOCK or enforce something), acceptance requires performing the violation in a fresh session and observing the guard fires.

### 5. Commit, Push, and Open the PR

- If on the default branch, create a feature branch first — never commit to main.
- Stage the intended files by name (not `git add -A` when unrelated changes are present) and commit with a message that explains why, ending with the attribution lines the session specifies.
- Push with `git push -u origin <branch>`.
- If the branch already has a PR (`gh pr view`), the push updates it; otherwise `gh pr create` with a title and a body passed via `--body-file -` and a single-quoted heredoc. Link the issue with `Fixes #N` when there is one.

On failure, report the error with its output and the manual step that would fix it.

### 6. Monitor CI (unless --no-watch)

Unless `--no-watch` was passed, invoke `/watch-ci` to monitor CI status in background. It will automatically run `/pr-review remote` when CI completes.
