Generate a monthly git activity summary for the current month.

Instructions:
1. Get the current month's date range:
   - First day: YYYY-MM-01
   - Last day: Last day of current month at 23:59:59
2. Get the git author name using: git config user.name
3. Run git log to get all commits for the current month:
   git log --all --since="YYYY-MM-01" --until="YYYY-MM-DD 23:59:59" --author="<author>" --pretty=format:"%h %ad | %s" --date=short
4. For each unique day with commits:
   - Use git show or git diff to read the actual changes in each commit
   - Analyze the code changes to understand what was done
   - Write a concise summary (max 500 characters) describing the work done that day
5. Create a markdown file named `monthly-summary-YYYY-MM.md` in the current directory with:
   - Header: "# Git Activity Summary - Month YYYY"
   - For each day with activity:
     - ## YYYY-MM-DD
     - Summary paragraph (max 500 chars)
     - List of commit hashes for reference
6. Output the path to the created file when done
