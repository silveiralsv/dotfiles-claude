Address PR review comments for the current branch's pull request.

Arguments: $ARGUMENTS (optional GitHub username to filter comments by reviewer)

Instructions:
1. Get the current branch's PR using: `gh pr view --json number,url`
   - If no PR exists for the current branch, inform the user and exit

2. Get the repository owner and name using: `gh repo view --json owner,name`

3. Fetch all review comments using:
   `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --paginate`

4. If $ARGUMENTS is provided (GitHub username):
   - Filter comments to only those where `user.login` matches the provided username
   - If no comments match, inform the user that no comments were found from that reviewer

5. For each comment, extract:
   - `user.login` - who made the comment
   - `body` - the comment text
   - `path` - file path
   - `line` or `original_line` - line number
   - `diff_hunk` - code context

6. For each comment, read the relevant file and analyze the surrounding code context to understand the full impact of the requested change.

7. Display each comment with an auto-incremental ID (starting at 1):

   ---
   ## [ID] Comment Title (brief summary of what's requested)

   **Reviewer**: @username
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

   ---

8. After listing all comments, display:
   "To apply changes, specify which comments to address by their ID (e.g., 'execute changes 1, 3, 5')"

9. When the user specifies which changes to execute (e.g., "execute changes 1, 2, 4"):
   - Apply ONLY the changes for the specified comment IDs
   - Read the relevant files and make the suggested modifications
   - Report what was changed for each addressed comment
   - Do NOT apply changes for comment IDs that were not specified
