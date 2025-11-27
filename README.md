# dotfiles-claude

Custom commands for [Claude Code](https://claude.ai/claude-code).

## Setup

Clone this repository and run the setup script:

```bash
git clone https://github.com/silveiralsv/dotfiles-claude.git
cd dotfiles-claude
./setup.sh
```

This creates symlinks from `~/.claude/commands/` to the commands in this repo.

## Commands

### `/create-pr <base-branch>`

Creates a PR from the current branch to the specified base branch. Automatically:
- Extracts ticket number from branch name
- Determines conventional commit type from commits
- Generates title and description

### `/address-comments [username]`

Addresses PR review comments for the current branch's pull request. Optionally filter by reviewer username.

Features:
- Fetches all review comments from the PR
- Analyzes each comment with file context and side effects
- Provides risk assessment (LOW/MEDIUM/HIGH) for each change
- Allows selective execution of changes by ID

### `/monthly-summary`

Generates a summary of your git activity for the current month across all repositories.
