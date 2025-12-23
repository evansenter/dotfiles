#!/usr/bin/env python3
"""
PostToolUse hook for PR pushes. Returns instructions for Claude to watch
the claude-review CI workflow and fetch review comments.
"""

import json
import sys
import re


def extract_pr_number(text):
    """Extract PR number from GitHub PR URL in command output."""
    match = re.search(r'github\.com/[^/]+/[^/]+/pull/(\d+)', text)
    return match.group(1) if match else None


def main():
    try:
        input_data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    if input_data.get("tool_name") != "Bash":
        sys.exit(0)

    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    is_pr_create = "gh pr create" in command
    is_git_push = command.startswith("git push")

    if not (is_pr_create or is_git_push):
        sys.exit(0)

    tool_response = input_data.get("tool_response", {})
    output = str(tool_response.get("output", ""))
    pr_number = extract_pr_number(output)

    if not pr_number:
        sys.exit(0)

    instructions = f"""PR #{pr_number} pushed. A Claude Code review is running via CI.

Run `gh pr checks {pr_number} --watch --interval 5` to wait for CI to complete, then `gh pr view {pr_number} --comments` to fetch the Claude Code review comments.

After retrieving the review comments, ask the user if they'd like you to address the feedback. Be ambitious in addressing all sensible feedback, including minor suggestions. Open GitHub issues for items that should be deferred to a later time."""

    print(json.dumps({
        "continue": True,
        "systemMessage": instructions
    }))


if __name__ == "__main__":
    main()
