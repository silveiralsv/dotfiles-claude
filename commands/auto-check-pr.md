Monitor the current branch's PR in a loop, automatically addressing review comments and fixing CI failures until everything is green.

Arguments: $ARGUMENTS (optional, space-separated)
- A GitHub PR URL (e.g., `https://github.com/owner/repo/pull/123`) — monitors that specific PR
- A GitHub username — filters comments to only that reviewer
- Both can be provided in any order

---

## Setup

1. Parse `$ARGUMENTS`:
   - If any argument matches a GitHub PR URL pattern (`https://github.com/.+/pull/\d+`), extract the owner, repo, and PR number from it
   - Any remaining argument that is not a URL is treated as a GitHub username for filtering comments

2. Resolve the PR:
   - **If a PR URL was provided**: use the extracted owner, repo, and PR number directly. Checkout the PR branch locally: `gh pr checkout <number>` (from the correct repo)
   - **If no PR URL was provided**: get the current branch's PR using `gh pr view --json number,url`. If no PR exists for the current branch, inform the user and exit

3. Get repo owner/name: `gh repo view --json owner,name` (skip if already extracted from URL)

4. Get the authenticated user: `gh api user --jq '.login'`

5. Display: **"Monitoring PR #N. Checking review comments and CI status every 3 minutes."**

Safety limit: maximum 20 loop iterations. If reached, report current status and exit.

---

## Each iteration:

### Step A: Check Review Comments

1. Fetch all review comments:
   `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --paginate`

2. If $ARGUMENTS is provided (GitHub username), filter comments to only those where `user.login` matches the provided username.

3. Identify **unaddressed** comments:
   - A comment is unaddressed if no reply exists from the authenticated user
   - Check the `in_reply_to_id` field on all comments to find which top-level comments have replies from the current user
   - Only process comments that have no such reply

4. If there are no unaddressed comments, skip to Step B.

5. For each unaddressed comment, read the affected file and surrounding code context, then analyze:

   ---
   ### [ID] Comment Summary

   **Reviewer**: @username
   **File**: `path/to/file.ts:line`

   > Original comment text

   **Suggested Change**: [concrete code modifications needed]

   **Side Effects Analysis**:
   - Impact on other parts of the codebase
   - Potential breaking changes or risks
   - **Risk Level**: LOW / MEDIUM / HIGH

   **Verdict**: **[SHOULD ADDRESS / SKIP / NEEDS DISCUSSION] (confidence%)**
   Explanation of the reasoning.

   ---

6. Handle each verdict:

   **SHOULD ADDRESS** comments:
   - Apply all changes (read files, make modifications)
   - Create a single commit with a descriptive message summarizing all addressed comments
   - Push to remote
   - Reply to each comment on GitHub:
     `gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies -f body="<reply>"`
   - The reply must: tag the reviewer with `@{username}`, explain what was changed and where

   **SKIP** comments:
   - Reply to each comment on GitHub with a respectful explanation of why it was not addressed
   - Tag the reviewer with `@{username}`

   **NEEDS DISCUSSION** comments:
   - **Pause the loop immediately**
   - Display the full comment with context to the user
   - Reply to the reviewer on GitHub asking for clarification on the requested change, tag them with `@{username}`
   - Wait for the user's input on how to proceed
   - After the user responds, resume the loop

### Step B: Check GitHub Actions

1. Get CI run status:
   `gh run list --branch <current-branch> --limit 10 --json databaseId,status,conclusion,name,headSha`

2. Get the current HEAD: `git rev-parse HEAD`

3. Filter runs to only those matching the current HEAD sha.

4. Evaluate:
   - If there are NO runs yet for the current HEAD (e.g., push just happened and workflows haven't started): CI is **pending**, treat as not ready
   - If any runs are `in_progress` or `queued`: CI is **pending**, do NOT evaluate pass/fail yet
   - If ALL runs have completed AND every run has `conclusion` = `success`: CI is **green**
   - If ALL runs have completed AND any run has `conclusion` = `failure`:
     a. Get failure details: `gh run view <run-id> --log-failed`
     b. Analyze the failure root cause
     c. If fixable (test failure, lint error, type error, build error):
        - Make the fix in the relevant files
        - Create a commit describing the CI fix
        - Push to remote
     d. If NOT fixable (infrastructure issue, flaky test, external dependency):
        - Report the issue to the user and continue

   **CRITICAL**: Never treat CI as passing unless ALL workflow runs for the current HEAD have completed with `success`. Pending, queued, or in-progress runs mean CI status is unknown — the loop MUST wait.

### Step C: Evaluate Loop Continuation

1. **Exit the loop** ONLY if ALL of these are true:
   - No unaddressed SHOULD ADDRESS comments were found in this iteration
   - ALL CI workflow runs for the current HEAD have **completed** (no `in_progress`, `queued`, or missing runs)
   - ALL completed CI runs have `conclusion` = `success`

2. **Continue looping** if ANY of:
   - Changes were pushed in this iteration (new CI runs will trigger, must wait for them to complete)
   - Any CI runs are still `in_progress` or `queued`
   - No CI runs exist yet for the current HEAD (workflows haven't started)
   - There are still unaddressed SHOULD ADDRESS comments

3. **Wait**: `sleep 180` (3 minutes) before the next iteration

## Final Report

When the loop exits, display:

```
## PR Check Summary
- **PR**: [url]
- **CI**: All passing / N failing
- **Comments Resolved**: N
- **Comments Skipped**: N (with brief reasons)
- **Needs Discussion**: N (list any remaining)
```
