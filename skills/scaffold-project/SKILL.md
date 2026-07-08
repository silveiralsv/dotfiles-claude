---
name: scaffold-project
description: Scaffold a project tracking folder in the Obsidian Vault from a project-management source (a Linear project or a Shortcut epic). It resolves the CANONICAL name from the source, slugifies it into the folder name (so the vault folder always matches the source's project/epic name), and creates `<Vault>/<repo>/Projects/<slug>/` with a PI-Index.md (sequence table of tickets → status, dependencies, PR links) and a `specs/` folder. It is IDEMPOTENT and conflict-safe: if the slug already exists it does NOT overwrite — it clearly reports that the project already exists and diffs the live source against the existing index so drift is visible. Use when the user says "scaffold a project", "create the project folder", "create the PI-Index for <project>", "criar a pasta de projeto", "cria o projeto no vault", or points at a Linear project / Shortcut epic and asks to track it in the vault.
metadata:
  author: lucas
  version: "1.0.0"
  argument-hint: '<linear-project-url|shortcut-epic-url-or-id|"Project Name"> [into <repo-folder>]'
---

# Scaffold Vault Project (PI-Index) — from Linear / Shortcut

This skill creates (or safely reconciles) a **project tracking folder** in the Obsidian Vault, sourced from a project-management tool. The vault folder name is always **derived from the source's canonical name** — the Linear **project** name, or the Shortcut **epic** name — so the vault and the source never drift apart in naming.

It produces the same structure used by existing projects (e.g. `olympus/Projects/Tiered-User-Billing/`, `olympus/Projects/Segments-and-Auto-Assignment/`):

```
<Vault>/<repo>/Projects/<slug>/
├── PI-Index.md      # source of truth: metadata + ticket sequence table (status, deps, PR links)
└── specs/           # behavioral specs (user flows, decisions) — read before any ticket
    └── README.md
```

**Two guarantees the user cares about most:**

1. **Name fidelity** — the folder slug is deterministically derived from the source's canonical project/epic name, so "if I ask from Linear, it matches the Linear project name; if I ask from Shortcut, it matches the Shortcut epic name."
2. **No accidental clobber** — if the slug already exists, the skill STOPS, states plainly that the project already exists, and reports whether the live source differs from what's in the vault. It never silently overwrites.

---

## Constants

- **Obsidian Vault root:** `/Users/lucas/www/Obsidian-Vault`
- **Projects subpath:** `<Vault>/<repo>/Projects/<slug>/`
- **`<repo>`** = the vault folder for the repository (e.g. `olympus`, `meridian-app`). Resolution order:
  1. explicit `into <repo-folder>` argument, else
  2. basename of the git origin remote of the current working directory, stripped of `.git`
     (`basename -s .git "$(git -C . remote get-url origin 2>/dev/null)"`), else
  3. last path segment of the git repo root.
  If the result is ambiguous or the `<Vault>/<repo>` folder does not exist yet, **ask the user** (via `AskUserQuestion`) which vault repo folder to use before writing anything.

---

## Procedure

### Step 1 — Parse the request & pick the source adapter

From the argument, determine the **source** and the **reference**:

| If the reference looks like…                          | Source     | Adapter (below) |
| ----------------------------------------------------- | ---------- | --------------- |
| `linear.app/.../project/...` or "linear" + a name     | **Linear** | Linear adapter  |
| `app.shortcut.com/.../epic/...`, `sc-<id>`, "shortcut"+ epic | **Shortcut** | Shortcut adapter |
| a bare `"Project Name"` with no host                  | ask which source, or default to **Linear** if only Linear is connected |

If the source is ambiguous, ask with `AskUserQuestion`. The design is provider-agnostic — adding a new source later means adding one adapter section; the rest of the flow is unchanged.

### Step 2 — Resolve the CANONICAL name + the ticket set (via the adapter)

Call the adapter (see **Source adapters** below). It must return:

- `canonicalName` — the exact project/epic name from the source (this is the naming authority).
- `sourceUrl` — the project/epic URL.
- `meta` — owner/lead, status, feature flag if discoverable, milestones/phases if any.
- `tickets[]` — each with: `id`, `title`, `status`, `url`, `pr` (link if any), `blockedBy[]`, `blocks[]`, `milestone`, `branch` (if pre-generated).

### Step 3 — Compute the slug (deterministic — do NOT freelance this)

Apply this algorithm to `canonicalName`, in order:

1. Trim leading/trailing whitespace.
2. Replace every run of whitespace with a single `-`.
3. Delete every character that is not `[A-Za-z0-9-]` (drops `&`, `:`, `/`, `.`, `,`, `()`, etc.).
4. Collapse runs of `-` into one, and strip leading/trailing `-`.
5. **Preserve original casing.**

Examples: `Tiered User Billing → Tiered-User-Billing` · `Segments and Auto-Assignment → Segments-and-Auto-Assignment` · `Q3: Growth (v2) → Q3-Growth-v2`.

Determinism is what makes the existence check in Step 4 reliable, so keep this exact.

### Step 4 — Existence check (the conflict gate — ALWAYS run before any write)

Set `TARGET = <Vault>/<repo>/Projects/<slug>`.

- **If `TARGET` already exists → STOP the create path. Do NOT write or overwrite anything.** Instead:
  1. State clearly: **"Project `<canonicalName>` already exists at `<TARGET>`."**
  2. Run the **Drift report** (below) comparing the live source to the existing `PI-Index.md`.
  3. Present the diff and, only if the user explicitly confirms, apply an **update** (Step 6). Never auto-apply.
- **If `TARGET` does not exist → proceed to Step 5 (create).**

Echo the resolved plan either way: source, `canonicalName`, `slug`, `TARGET`, ticket count.

### Step 5 — Create (only when TARGET did not exist)

1. `mkdir -p <TARGET>/specs`.
2. Sort tickets into an execution sequence: topological order over `blockedBy` (foundation/unblocked first), grouping by milestone/phase when the source has them. Non-code / launch chores (milestones like Internal Review, Soft Launch, Public Launch) go in a separate table without a PR column.
3. Map each ticket's source status to the **Status legend** (below).
4. Write `<TARGET>/PI-Index.md` from the **PI-Index template**, filling every placeholder. Put the real ticket link and PR link in each row.
5. Write `<TARGET>/specs/README.md` from the **specs README template**.
6. Commit + push the vault (**Step 7**).

### Step 6 — Update (only when TARGET existed AND the user confirmed)

Apply the minimal reconciliation the user approved:

- Update changed **Status** and **PR** cells; append **new** ticket rows in sequence; mark rows for tickets no longer in the source as `⚠️ not in source` (do not delete silently).
- If `canonicalName` changed, surface it — a renamed source may imply a new slug; ask before renaming the folder (renaming loses the folder's history/links).
- **Never touch `specs/` or hand-written prose** — only the generated metadata block and the tables. Preserve the user's manual notes.
- Commit + push the vault (**Step 7**).

### Step 7 — Commit & push the vault (MANDATORY, per global rules)

```bash
cd /Users/lucas/www/Obsidian-Vault && git add -A \
  && git commit -m "Scaffold project: <slug> (<repo>)" \
  && git push
```

Use `Update project: <slug> (<repo>)` for the update path. Never skip the push.

---

## Source adapters

### Linear adapter

- Resolve the project: `mcp__edvisor-linear__get_project` with the URL/slug/name (`includeMilestones: true`, `includeResources: true`). `name` → `canonicalName`; `lead`, `status`, `startDate`, `milestones[]` → `meta`. Scan `description` for a feature-flag mention.
- List tickets: `mcp__edvisor-linear__list_issues` with `project: <project id>` (`limit: 100+`). Capture `id`, `title`, `status`, `url`, `projectMilestone`, `gitBranchName`.
- Per ticket, for dependencies + PR: `mcp__edvisor-linear__get_issue` with `includeRelations: true`. `relations.blockedBy[]`/`blocks[]` → deps; `attachments[]` whose URL contains `/pull/` → `pr`. (Fetch these in parallel.)

### Shortcut adapter

- Resolve the epic: `mcp__shortcut-remote__epics-get-by-id` (or `epics-search` by name). `name` → `canonicalName`; `url`, `owner_ids`, `state`, `milestone_id` → `meta`.
- List tickets (stories): `mcp__shortcut-remote__epics-get-by-id` → story ids, then `mcp__shortcut-remote__stories-get-by-id` per story (parallel). Capture `id` (`sc-<id>`), `name`→title, `workflow_state`→status, `app_url`→url, `branches`/`stories-get-branch-name`.
- Dependencies: story relationships (`story_links` — `blocks` / `blocked by`). PR: an external link containing `/pull/`, or a linked VCS PR on the story.

> Adding a new source? Implement the same contract (Step 2 return shape) as a new adapter section; Steps 3–7 need no changes.

---

## Status legend & mapping

Legend used in the PI-Index (keep exactly): `⬜ Todo · 🟠 In Progress · 🟣 In Review (PR open) · 🧪 Ready to Test (merged, verifying) · ✅ Done`

Map source states to it (case-insensitive, best fit):

| Source state (Linear / Shortcut)                    | Legend            |
| --------------------------------------------------- | ----------------- |
| Backlog, Todo, Unstarted, "To Do", Ready            | ⬜ Todo           |
| In Progress, Started, Doing                         | 🟠 In Progress    |
| In Review, Code Review, PR open                      | 🟣 In Review      |
| Ready to Test, QA, Ready for QA, Ready To Test In Prod | 🧪 Ready to Test |
| Done, Completed, Merged, Shipped, Closed            | ✅ Done           |

When a ticket is 🧪/✅ and its PR is merged, annotate the PR cell `[#NNN](url) ✅ merged`.

---

## PI-Index template

Fill every `{{placeholder}}`. Omit the "Rollout & launch" and "Git branches" tables if the source has no such data. Write everything in **English** (per global rules), regardless of chat language.

~~~markdown
# {{canonicalName}} — Project Index (source of truth)

> [!IMPORTANT] AGENT INSTRUCTION — READ THE SPECS BEFORE ANY WORK
> Before starting **any** ticket in this project — or making **any** change to {{canonicalName}} code — you **MUST** read every spec in [`specs/`](specs/) first. The specs are the source of truth for how this feature must behave; the implementation must **never diverge** from them. If a ticket, PR, or your own plan seems to contradict a spec, **STOP and flag it** rather than guessing or "improving" the behavior. Keep this list current as specs are added.
>
> **Current specs:**
> - _(none yet — add behavioral specs to [`specs/`](specs/) as they are produced, then list them here.)_

> Working checklist for this project. Update the **Status** and **PR** columns as each ticket lands.
> To pick work: do the **first ticket in the sequence below that is not yet done**, respecting `Depends on`. Read the [specs](specs/) before touching it.

- **Repo:** {{repo}}{{ · PRs target `<base-branch>` if known}}
- **Source ({{sourceKind}}):** [{{canonicalName}}]({{sourceUrl}})
- **Slug:** `{{slug}}`
{{- **Feature flag:** `<flag>` if any}}
- **Owner:** {{owner}}
- **Last updated:** {{YYYY-MM-DD}}
- **Status legend:** ⬜ Todo · 🟠 In Progress · 🟣 In Review (PR open) · 🧪 Ready to Test (merged, verifying) · ✅ Done

## ▶ Next up

{{One short paragraph: what's merged, and the first unblocked ticket(s) to pick next.}}

## Execution sequence{{ (Implementation milestone) if milestones exist}}

| Seq | Status | Ticket | What it does | Depends on | PR |
|----|--------|--------|--------------|-----------|----|
{{one row per implementation ticket, in topological order:}}
| {{n}} | {{legend}} | [{{ID}}]({{url}}) | {{concise what-it-does}} | {{blockedBy ids or —}} | {{[#PR](pr) ✅ merged, or —}} |

## Rollout & launch (non-code milestones)

{{Only if the source has launch/rollout chores. No PR column.}}

| Milestone | Status | Ticket | What |
|-----------|--------|--------|------|
| {{milestone}} | {{legend}} | [{{ID}}]({{url}}) | {{what}} |

## Git branches (pre-generated by the source)

{{Only if branch names are available.}}

| Ticket | Branch |
|--------|--------|
| {{ID}} | `{{branch}}` |

---
_Created {{YYYY-MM-DD}}. Keep this file in sync as tickets progress — it is the source of truth for "what's left." Always read [`specs/`](specs/) before implementing._
~~~

## specs README template

~~~markdown
# specs/ — {{canonicalName}}

Behavioral specifications for this project. **Read every file here before implementing any ticket** (see the callout in [[PI-Index]]). Implementation must conform to these specs; if a ticket contradicts a spec, stop and flag it.

Add one file per spec (e.g. `user-flow.md`, `pricing-rules.md`, `<decision>.md`) and list it in the **Current specs** callout at the top of [[PI-Index]].
~~~

---

## Drift report (when the project already exists)

Compare the live source (Step 2) against the existing `PI-Index.md` and report, concisely:

- **Name:** `canonicalName` (source) vs the title in the file — flag a rename.
- **New tickets:** in source, missing from the table.
- **Removed/archived:** in the table, no longer in the source (mark, don't delete).
- **Status changes:** per ticket, file legend vs mapped source status.
- **New/changed PRs:** PRs present in the source but missing/different in the table.
- **Verdict:** "in sync" or an itemized list. Then ask whether to apply the update (Step 6). Do nothing to disk until the user confirms.

---

## Guardrails

- **Never overwrite an existing project folder or its `specs/`.** The existence check in Step 4 is mandatory and comes before any write.
- **English only** for everything written to the vault (files, commit messages), regardless of chat language.
- **Deterministic slug** — never hand-tweak the slug; the algorithm in Step 3 is the contract.
- Always **commit + push the vault** after a create or an approved update.
- Fetch per-ticket relation/PR calls **in parallel** to keep it fast.
- If repo folder resolution is ambiguous, **ask** before writing.
