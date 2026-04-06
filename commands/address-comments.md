Address PR review comments for the current branch's pull request.

Arguments: $ARGUMENTS (optional, space-separated)
- `--auto` flag: automatically resolve all comments, push, and reply to reviewers (see step 10)
- A GitHub username: filter comments to only that reviewer
- Both can be provided in any order

Instructions:
1. Parse `$ARGUMENTS`:
   - If any argument is `--auto`, set auto mode to true and remove it from the arguments
   - Any remaining argument is treated as a GitHub username for filtering comments

2. Get the current branch's PR using: `gh pr view --json number,url`
   - If no PR exists for the current branch, inform the user and exit

3. Get the repository owner and name using: `gh repo view --json owner,name`

4. Fetch all review comments using:
   `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --paginate`

5. If a GitHub username was provided:
   - Filter comments to only those where `user.login` matches the provided username
   - If no comments match, inform the user that no comments were found from that reviewer

6. For each comment, extract:
   - `user.login` - who made the comment
   - `body` - the comment text
   - `path` - file path
   - `line` or `original_line` - line number
   - `diff_hunk` - code context
   - `created_at` - when the review comment was posted

7. For each comment, read the relevant file and analyze the surrounding code context to understand the full impact of the requested change.

8. Display each comment with an auto-incremental ID (starting at 1):

   ---
   ## [ID] Comment Title (brief summary of what's requested)

   **Reviewer**: @username
   **Date**: YYYY-MM-DD HH:MM (formatted from `created_at`)
   **File**: `path/to/file.ts:123`

   **Comment**:
   > Original comment text quoted here

   **Suggested Change**:
   Describe the specific code changes needed to address this comment. Be concrete about what to add, modify, or remove.

   **Side Effects Analysis**:
   - Analyze how this change impacts other parts of the codebase
   - Check for usages of the affected code (functions, variables, types, exports)
   - Identify potential breaking changes (API contracts, type signatures, behavior changes)
   - Note any dependencies or downstream effects the reviewer may not have considered
   - Flag any risks: test failures, runtime errors, edge cases, performance implications
   - **Risk Level**: LOW / MEDIUM / HIGH

   **Claude's Judgment**:
   Evaluate whether this comment should be addressed. Use Explore agents to investigate the codebase for tradeoffs, patterns, and broader context before forming your opinion. Consider:
   - Does the suggestion genuinely improve code quality, correctness, or maintainability?
   - Does the cost of the change (complexity, risk, effort) outweigh the benefit?
   - Is this a matter of personal style/preference vs an objective improvement?
   - Are there existing patterns in the codebase that support or contradict the suggestion?

   Assign a confidence level (0-100%) for your recommendation:
   - **>=80% confidence**: State a clear verdict — **SHOULD ADDRESS** or **SKIP** — in bold, followed by a concise explanation.
   - **<80% confidence**: State **NEEDS DISCUSSION** in bold, explain the tradeoffs from both sides, and let the user decide.

   Format: **[VERDICT] (confidence%)**: explanation

   ---

9. **If `--auto` is NOT set** (manual mode):
   - Display: "To apply changes, specify which comments to address by their ID (e.g., 'execute changes 1, 3, 5')"
   - When the user specifies which changes to execute (e.g., "execute changes 1, 2, 4"):
     - Apply ONLY the changes for the specified comment IDs
     - Read the relevant files and make the suggested modifications
     - Report what was changed for each addressed comment
     - Do NOT apply changes for comment IDs that were not specified

10. **If `--auto` is set** (automatic mode):
    Skip the interactive prompt and proceed with automatic resolution:

    a. **Apply changes** for ALL comments marked **SHOULD ADDRESS**:
       - Read the relevant file for each comment
       - Make the suggested modification as described in the "Suggested Change" section
       - Track what was changed and why for each comment

    b. **Commit and push**:
       - Create a single commit with a descriptive message summarizing all changes made
       - Push the changes to the remote branch

    c. **Reply to EVERY comment** on the PR using the GitHub API:
       `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies -f body="<reply>"`

       - For **SHOULD ADDRESS** comments:
         Tag the reviewer with `@{username}`. Explain what was changed, which file/line was modified, and a brief explanation of the fix.

       - For **SKIP** comments:
         Tag the reviewer with `@{username}`. Provide a respectful explanation of why the comment was not addressed, referencing the reasoning from Claude's Judgment (codebase patterns, tradeoffs, or other concrete reasoning).

       - For **NEEDS DISCUSSION** comments:
         Tag the reviewer with `@{username}`. Present Claude's perspective from the Judgment section — share the tradeoffs analyzed and Claude's leaning, framed as a discussion point (not a dismissal). Invite the reviewer to share their thoughts.

    d. **Display a final summary**:
       - Number of comments resolved (SHOULD ADDRESS)
       - Number of comments skipped (SKIP) with brief reasons
       - Number of comments opened for discussion (NEEDS DISCUSSION)
       - Link to the PR
