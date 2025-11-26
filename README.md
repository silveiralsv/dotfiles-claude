# dotfiles-claude

Custom commands for [Claude Code](https://claude.ai/claude-code).

## Setup

Clone this repository and run the setup script:

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles-claude.git
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
