# dotfiles-claude

Custom commands, agents, and skills for [Claude Code](https://claude.ai/claude-code).

## Setup

Clone this repository and run the setup script:

```bash
git clone https://github.com/silveiralsv/dotfiles-claude.git
cd dotfiles-claude
./setup.sh
```

This symlinks each item into `~/.claude/`:
- `commands/*.md` → `~/.claude/commands/`
- `agents/*.md` → `~/.claude/agents/`
- `skills/<skill>/` → `~/.claude/skills/` (each skill is a directory containing a `SKILL.md`)

Existing files/symlinks are left untouched (re-running is safe).

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

### `/resolve-comments`

Extension of `/address-comments`. Run this after reviewing the comment verdicts to automatically:
- Apply all SHOULD ADDRESS changes
- Commit and push in a single commit
- Reply to each PR comment on GitHub explaining what was changed or why it was skipped
- List NEEDS DISCUSSION comments for manual review

### `/monthly-summary`

Generates a summary of your git activity for the current month across all repositories.

## Skills

### `scaffold-project`

Scaffolds a project tracking folder in the Obsidian Vault from a project-management source (a **Linear project** or a **Shortcut epic**).

- Resolves the **canonical name** from the source and slugifies it into the folder name, so `<Vault>/<repo>/Projects/<slug>/` always matches the source's project/epic name (Linear → Linear project name; Shortcut → Shortcut epic name).
- Creates a `PI-Index.md` (metadata + a topologically-ordered ticket table with status, dependencies, and PR links) plus a `specs/` folder.
- **Idempotent & conflict-safe:** if the slug already exists it does **not** overwrite — it reports that the project already exists and diffs the live source against the existing index, so drift is visible before any change.
- Commits and pushes the vault on create / approved update.

Invoke it by asking Claude to "scaffold a project" / "create the PI-Index for &lt;project&gt;" and pointing at a Linear project URL or Shortcut epic (optionally `into <repo-folder>`).

### `ship-ticket`

Drives a single tracker ticket end-to-end to a **merged PR**, hands-off, by orchestrating subagents that each own their own context window:

1. Resolves the ticket — from a **ticket id/URL** (`ship-ticket APO-1784`), or from a **project + `--next`** (`ship-ticket tiered-user-billing --next`) to auto-pick the next unblocked item in the vault PI-Index sequence.
2. Grounds it (repo-knowledge-planner + Explore) and reads the project `specs/`.
3. An **executor** subagent implements + tests + commits + pushes the branch, then reports back.
4. Runs the mandatory **feature-docs-curator** + **codebase-memory-curator** (before the PR).
5. Opens the PR to the repo's base branch.
6. A **pr-shepherd** subagent keeps CI green, works review comments, and merges on green + a human approval.
7. Updates the PI-Index tracker (In Review → Done + PR link) and cleans up the worktree.

Pairs with `scaffold-project`: that skill creates the PI-Index; `ship-ticket --next` consumes it to pick and ship the next ticket.

### `release-note`

Generates a release note for a shipped (or shipping) feature and saves it to the Obsidian Vault under `<repo>/Releases/`, in one of two proven flavors:

- **Engineering release note** — precise and technical: rule/eligibility tables, an ASCII pipeline diagram of how it works, the launch switch (DevCycle flag or "None"), and a "what the customer sees" walkthrough.
- **Product / customer-facing launch note** — benefit-led, with emoji sections ("What's new / What it looks like / Example use cases / Rollout plan") and inline screenshots, written to be pasted into **#product-releases**.

It grounds every claim in real material — the Linear project/tickets, git history, the vault's own `Docs/` / `Plans/` / `Projects/` specs / `Memories/`, the DevCycle feature flag, and screenshots reused from existing staging test evidence — never inventing behavior. It writes everything in English and commits + pushes the vault.

Invoke it by asking Claude to "generate a release note" / "write the launch notes" and pointing at a feature, a Linear project, or a set of merged tickets (optionally `--technical` or `--product`).
