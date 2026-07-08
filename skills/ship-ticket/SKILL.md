---
name: ship-ticket
description: Drive a single tracker ticket end-to-end to a merged PR by orchestrating subagents, each in its own context window. It (1) resolves the ticket — from a ticket id/URL, or from a project + `--next` to auto-pick the next item in the vault PI-Index sequence; (2) grounds it (repo-knowledge-planner + Explore); (3) hands an EXECUTOR subagent the plan to implement + test + commit + push a branch; (4) runs the mandatory feature-docs-curator + codebase-memory-curator; (5) opens the PR; (6) hands a pr-shepherd subagent the PR to keep green and merge on green + human approval; (7) updates the PI-Index tracker and cleans up. Use when the user says "run/ship this ticket", "rodar o ticket", "execute APO-1234", "faz a próxima do projeto", "<project> --next", or hands a ticket number/URL to implement autonomously.
metadata:
  author: lucas
  version: "1.0.0"
  argument-hint: '<TICKET-ID | ticket-URL>  |  <project> --next'
---

# Ship a ticket end-to-end (orchestrated subagents)

Take ONE tracker ticket from "to do" to a **merged PR**, hands-off, by orchestrating subagents that each own their own context window. This is the exact pipeline proven on APO-1781 and APO-1783.

**The two headline subagents the flow revolves around:**
1. **Executor** — implements the ticket, tests it, commits + pushes the branch, and reports back a structured result. (It does NOT open the PR — see the sequencing rule below.)
2. **pr-shepherd** — takes the opened PR and drives it to merge (keeps CI green, works review comments, merges on green + a human approval).

**Plus the mandatory supporting agents (required by the global rules — do not skip):**
- **repo-knowledge-planner** + **Explore** — grounding, BEFORE any code changes.
- **feature-docs-curator** + **codebase-memory-curator** — BEFORE the PR is opened.

You (the invoking agent) are the **orchestrator**: you run in the main context, spawn each subagent via the Agent tool, and continue across turns as their background completions notify you. Relay only what matters between them — each subagent's final report is the hand-off.

---

## Inputs & ticket resolution

Parse the argument:

- **A ticket id or URL** (`APO-1784`, `BEK-106`, a Linear URL) → resolve it directly.
- **`<project> --next`** (or `--next <project>`) → open that project's PI-Index in the vault and pick the next ticket to execute.
- **Nothing / current branch** → resolve the ticket from the current branch's Linear id if present; else ask which ticket.

### Resolving from a ticket id (Linear)
Use the connected Linear MCP: `mcp__edvisor-linear__get_issue` with `includeRelations: true` → capture `title`, `description`, `status`, `gitBranchName`, `relations.blockedBy`/`blocks`, and any `attachments` (PR links). If the ticket is already `Done`/has a merged PR, STOP and report — nothing to ship.

### Resolving with `--next` (from the vault PI-Index)
1. Determine the vault project folder: `<Vault>/<repo>/Projects/<project-slug>/PI-Index.md`, where `<Vault>` = `/Users/lucas/www/Obsidian-Vault`, `<repo>` = basename of the current git origin remote (fallback: search all `*/Projects/<project-slug>/` under the vault). `<project-slug>` matches what `scaffold-project` created.
2. Parse the **Execution sequence** table. Pick the **first row** whose Status is **⬜ Todo** (not started) AND every ticket in its **Depends on** column is code-complete (**✅ Done** or **🧪 Ready to Test**). (Legend: `⬜ Todo · 🟠 In Progress · 🟣 In Review · 🧪 Ready to Test · ✅ Done`.) If the first candidate is 🟠/🟣 it's already in flight — surface it and ask whether to resume or skip.
3. Extract the ticket id from that row's `[APO-####](url)` link, then resolve it from Linear as above.

**Always read the project's specs first.** The PI-Index carries an "AGENT INSTRUCTION — READ THE SPECS" callout pointing at `specs/`. Read every file in `<project>/specs/` before doing anything — the implementation must not diverge from them (this is what `scaffold-project` set up for exactly this moment).

Echo the resolved plan before proceeding: **source · ticket id + title · branch name · base branch · target vault project · which specs you read**.

---

## The pipeline

### 1. Ground it (mandatory — before any code change)
Spawn **in parallel**, in the background:
- `repo-knowledge-planner` — scoped to this ticket + repo; pulls the vault Docs/Memories (patterns, prior related tickets, gotchas) and returns a grounded plan + key decisions + open questions.
- `Explore` (very thorough) — maps the exact code touchpoints, precedents, and current behavior of the surfaces the ticket touches.

Wait for both. Synthesize their findings into the executor's brief. (This is required by the global "knowledge-grounded planning" rule and repeatedly catches real issues — id collisions, missing sites, scope gaps.)

If the ticket touches a third-party provider API/SDK, also run `provider-api-analyst` first (global hard rule).

### 2. Scope-decision gate (only when genuinely ambiguous)
If grounding surfaces a real decision the **user owns** — one not resolvable from the ticket, specs, code, or a safe default (e.g. "include Tasks?", "enforce now or scaffold-only?", "will this surface in prod?") — ask it with `AskUserQuestion`, with a recommendation, BEFORE the executor writes anything. Otherwise proceed on the safe reading and state the decisions you made.

### 3. Set up the worktree
`git fetch origin <base>` (base = the repo's PR target: olympus → `develop`; check the PI-Index "PRs target" line / repo CLAUDE.md). Create an isolated worktree off the fresh base using the Linear-pinned branch name:
`git -C <repo-root> worktree add -b <gitBranchName> <repo-root>/.claude/worktrees/<ticket-id> origin/<base>`
(Do NOT reuse the current worktree if grounding agents are still reading it.)

### 4. Executor subagent (its own context)
Spawn a `general-purpose` executor (background) with a COMPLETE brief:
- The worktree path + branch (all commands `cd` into it; shell cwd resets between calls; honor `.nvmrc` / `nvm use`).
- The ticket scope + the grounded plan + the specs' relevant rules + the decisions from step 2.
- Repo gotchas surfaced by grounding (e.g. olympus: api-v2/api-v3 double-quote-vs-prettier trap → `--no-verify`; `packages/database` single-quote + `npm run format`; worktree needs `npm install` + `prisma generate`; MariaDB; don't touch `latest-schema.sql`).
- Instruction to implement + add tests + typecheck the touched workspaces + commit (conventional, `[TICKET]`, **no AI attribution**) + push. **Do NOT open a PR.**
- A structured report back: files changed, decisions/deviations, test results, commit SHAs, anything a reviewer should know.

When it returns, **verify the diff yourself** (`git diff --stat` + a guard grep for anything out of scope) before continuing.

> **Why the executor stops before the PR:** the global rule requires feature-docs-curator + codebase-memory-curator to run *before any PR exists*. So the executor prepares the branch; the orchestrator runs docs/memory (step 5) and then opens the PR (step 6). This is the one place the flow deviates from "the executor creates the PR" — deliberately, to honor the hard rule.

### 5. Docs + memory (mandatory — before the PR)
Spawn **sequentially** (not parallel — they both commit to the vault git repo and would race):
1. `feature-docs-curator` scoped to the branch → updates `<repo>/Docs/` + commits/pushes the vault.
2. `codebase-memory-curator` scoped to the branch → updates `<repo>/Memories/` + commits/pushes the vault.
Either may report "nothing durable" — that still counts as run.

### 6. Open the PR
Write a rich PR body (what + why, scope decisions, the grant/behavior summary, testing, explicit caveats like "migration not DB-exercised — verify at staging", reviewer decision points, follow-up tickets, Linear link). Then `gh pr create --base <base> --head <branch> --title "<type>: [TICKET] …"`. Capture the PR number/URL.

### 7. pr-shepherd subagent (its own context, background)
Spawn `pr-shepherd` (background) on the PR: keep CI green, work every bot + human review comment (fix → commit → push → reply → resolve → re-review), and **merge on green + a human (non-bot) approval** via the repo's merge mechanism (olympus = Trunk queue, `/trunk merge`). Give it the worktree path (for fixes) + the repo gotchas + the known caveats to explain in review.

**Auto-merge, hands-off (standing preference — see the memory note):** keep pr-shepherd driving to MERGED; do NOT pause to ask the user "should I merge?". On olympus the `develop` ruleset requires a **human** approving review and the author can't self-approve — that gate is real (not a pr-shepherd bug), so "automatic" means: request a human reviewer and merge the instant their approval lands. If pr-shepherd returns STILL_MONITORING (blocked on human approval) after a bounded watch, resume it when the approval lands rather than polling for hours; surface the blocker plainly.

### 8. Update the tracker
Keep the PI-Index the easy-to-verify source of truth:
- On PR open: set the ticket's row Status → 🟣 In Review and fill the PR cell with `[#N](url) 🟣 open`; refresh "Next up".
- On merge: Status → ✅ Done, PR cell → `[#N](url) ✅ merged (\`<sha>\`)`; refresh "Next up" to the next unblocked ticket(s).
- Commit + push the vault after each change (the vault has an auto-backup, so use `git add -A ; git commit … ; git push` so the push runs even if the backup already committed).

### 9. Cleanup
After merge: remove the worktree and delete the local branch:
`git -C <repo-root> worktree remove <path> --force && git -C <repo-root> branch -D <branch> && git -C <repo-root> worktree prune`.

---

## Guardrails

- **English only** for everything on GitHub / in the repo / in the vault (code, commits, PR text, replies, docs, memories) — regardless of chat language. **No AI attribution** anywhere on GitHub.
- **Honor the mandatory agents** — repo-knowledge-planner before changes; feature-docs-curator + codebase-memory-curator before the PR. Skipping them is never acceptable (they may report "nothing durable" and that counts).
- **Never merge on a bot approval alone.** A human approval is required (and on olympus's `develop` it's enforced by the branch ruleset).
- **Read the specs before implementing** — the PI-Index callout is there for this; flag any ticket that contradicts a spec instead of "improving" it.
- **One ticket per invocation.** For "do the next N", run this skill once per ticket in sequence (respecting `Depends on`).
- **Surface, don't bury, real risks** — if a caveat can't be verified in-sandbox (e.g. a migration with no DB harness), say so in the PR and the report; let the human review catch what CI can't.
- **Scale grounding to complexity** — a trivial/mechanical ticket may need only a light Explore; a cross-service change deserves the full planner + thorough Explore.
