Resolve all SHOULD ADDRESS PR review comments from a previous `/address-comments` run, push changes, and reply to reviewers.

Prerequisites: This command is meant to be run AFTER `/address-comments` has already been executed in the same conversation. It relies on the comments and verdicts already displayed.

Instructions:
1. Verify that `/address-comments` has already been run in this conversation and that comments with verdicts are visible.
   - If not, inform the user to run `/address-comments` first and exit.

2. Get the current branch's PR using: `gh pr view --json number,url`

3. Get the repository owner and name using: `gh repo view --json owner,name`

4. Fetch all review comments using:
   `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --paginate`
   Match these against the previously displayed comments to obtain the `id` for each comment (needed for replying via the API).

5. Apply changes for ALL comments previously marked as **SHOULD ADDRESS**:
   - Read the relevant file for each comment
   - Make the suggested modification as described in the "Suggested Change" section from the `/address-comments` output
   - Track what was changed and why for each comment

6. After all SHOULD ADDRESS changes are applied:
   - Create a single commit with a descriptive message summarizing all changes
   - Push the changes to the remote branch

7. Reply to EVERY comment (SHOULD ADDRESS and SKIP) on the PR using the GitHub API:
   - For **SHOULD ADDRESS** comments that were resolved:
     `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies -f body="<reply>"`
     Reply must include: what was changed, which file/line was modified, and a brief explanation of the fix.
     Tag the reviewer: start the reply with `@{reviewer_username}`.

   - For **SKIP** comments:
     `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies -f body="<reply>"`
     Reply must include: a respectful explanation of why the comment was not addressed, referencing codebase patterns, tradeoffs, or other concrete reasoning.
     Tag the reviewer: start the reply with `@{reviewer_username}`.

   - For **NEEDS DISCUSSION** comments:
     Do NOT reply automatically. Instead, list these at the end of the output and ask the user to decide how to handle each one.

8. After all replies are posted, display a final summary:
   - Number of comments resolved (SHOULD ADDRESS)
   - Number of comments skipped (SKIP) with brief reasons
   - Number of comments pending discussion (NEEDS DISCUSSION)
   - Link to the PR
