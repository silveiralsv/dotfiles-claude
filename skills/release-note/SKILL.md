---
name: release-note
description: Generate a release note for a shipped (or shipping) feature and save it to the Obsidian Vault under `<repo>/Releases/`. It produces one of two proven flavors — a precise ENGINEERING release note (rule tables, an ASCII pipeline diagram, the launch switch, "what the customer sees") or a friendly PRODUCT / customer-facing LAUNCH note (emoji sections, "what's new / what it looks like / example use cases / rollout plan") for the #product-releases channel — grounded in real material: the Linear project/tickets, git history, the vault's own Docs/Plans/Projects specs/Memories, the DevCycle feature flag, and screenshots reused from existing staging test evidence. It never invents behavior, writes everything in English, and commits + pushes the vault. Use when the user says "generate a release note", "write the release notes", "create the launch notes", "draft the #product-releases post", "gerar release notes", "criar a release note", "escrever as notas de lançamento", or points at a shipped feature / Linear project / set of merged tickets and asks to announce it.
metadata:
  author: lucas
  version: "1.0.0"
  argument-hint: '<feature name | Linear project URL | TICKET-IDs | --from-branch> [--technical | --product]'
---

# Generate a Release Note (Obsidian Vault → `<repo>/Releases/`)

Turn a shipped (or about-to-ship) feature into a polished release note in the Obsidian Vault, in one of two flavors this repo has already validated:

1. **Engineering release note** — precise and technical. Rule/eligibility **tables**, an **ASCII pipeline diagram** of how it works, the **launch switch** (DevCycle flag or "None"), and a "what the customer sees" walkthrough. Audience: engineering + technical stakeholders who need the exact behavior.
   *Reference outputs:* `olympus/Releases/2026-06-22-unpaid-customers-lifecycle-release-note.md`, `…/2026-06-23-anonymization-release-note.md`.
2. **Product / customer-facing launch note** — friendly and benefit-led. Emoji section headers (🎯 👀 💡 ✨ 🚦), "What's new / What it looks like / Example use cases / Also better than before / Rollout plan", inline screenshots. Audience: GTM/product and the **#product-releases** post.
   *Reference outputs:* `olympus/Releases/2026-07-02-segments-auto-assignment-soft-launch.md`, `…/2026-06-30-segments-auto-assignment-launch-notes.md`.

**The core principle: a release note is _reported_, never invented.** Every claim — rules, flag names, thresholds, screens — must trace back to a real source (below). If a fact can't be grounded, mark it `TODO(verify)` rather than guessing.

---

## Constants

- **Obsidian Vault root:** `/Users/lucas/www/Obsidian-Vault`
- **Releases subpath:** `<Vault>/<repo>/Releases/`
- **`<repo>`** = the vault folder for the product (e.g. `olympus`). Resolution order:
  1. explicit `into <repo-folder>` argument, else
  2. basename of the git origin remote of the current working directory, stripped of `.git`
     (`basename -s .git "$(git -C . remote get-url origin 2>/dev/null)"`), else
  3. last path segment of the git repo root.
  If ambiguous or `<Vault>/<repo>` does not exist, **ask** (via `AskUserQuestion`) before writing.
  > Note: the vault `<repo>` folder (where the note is filed, e.g. `olympus`) can differ from the **`Repo:`** line inside the note, which names the *code* repo(s) that shipped (e.g. `app-events`). File by product; label by code repo.
- **File name:** `YYYY-MM-DD-<slug>-release-note.md` (engineering) or `YYYY-MM-DD-<slug>-launch-notes.md` (product). Use today's date (from context) unless the user gives one. `<slug>` is kebab-case of the feature name.
- **Assets folder (screenshots):** a sibling folder next to the note — `<Vault>/<repo>/Releases/assets-YYYY-MM-DD-<short-slug>/` — holding the images the note references.
- **Product-release channel:** Slack **#product-releases** (the product note is written to be pasted there).

---

## Procedure

### Step 1 — Parse the request: feature, source, and flavor

From the argument determine three things:

- **The feature/scope** — a name, a Linear project, a ticket set, or `--from-branch` (derive from the current branch's merged work).
- **The flavor** — `--technical` (engineering) or `--product` (customer-facing). If not specified, **infer** (see Step 3) and confirm with one line, or ask via `AskUserQuestion` when it's a real toss-up.
- **The vault `<repo>`** — per Constants.

Echo the resolved plan before drafting: **feature · flavor · vault `<repo>` · target file path · sources you'll pull**.

### Step 2 — Gather the material (ground every claim)

Pull from as many of these as exist; they are the raw material for the note. Fetch independent sources in parallel.

| Need | Where to get it |
| --- | --- |
| Feature name, scope, status, **feature flag**, Linear link | Linear **project** (`mcp__edvisor-linear__get_project`) and its issues (`list_issues` / `get_issue` with `includeRelations`), or the ticket ids given |
| What actually changed (the truth of the diff) | **git history**: `git -C <repo> log --oneline`/`--stat` for the feature's branches/PRs; PR bodies via `gh pr view` |
| Behavior, rules, decisions, gotchas | The vault: `<repo>/Docs/<feature>.md`, `<repo>/Plans/*<feature>*.md`, `<repo>/Projects/<Project>/` (PI-Index, `specs/`, RCA, memory notes), `<repo>/Memories/*<feature>*.md` |
| Launch switch / flag default | DevCycle (`mcp__devcycle__get_feature*` / `list_features`) or the flag name referenced in the Plans/specs. **Default OFF unless proven otherwise.** |
| Screenshots | **Reuse existing staging test evidence first**: `<repo>/Testing/**` and `<repo>/Reports/**/*.png` (e.g. `Reports/assets/<apo>-smoke/evidence-*.png`). Only capture fresh ones if none exist (see Step 4). |
| Rollout plan / who has it | Linear project status/milestones, the flag targeting, the user's own words |

If the ticket/feature touches a **third-party provider** and you need to state provider behavior, verify it with the `provider-api-analyst` agent rather than asserting it (global hard rule).

Read enough to state behavior **precisely**. If two sources conflict, trust git + specs over prose, and flag the discrepancy.

### Step 3 — Choose the flavor (when not given)

- **Product / customer-facing launch note** when: the note is for #product-releases, the audience is GTM/customers, the feature is user-visible UI, or the user says "launch note", "announce", "soft launch".
- **Engineering release note** when: the feature is backend/infra (webhooks, crons, data changes), the audience is technical, the value is in *exact* rules/thresholds/state machines, or the user says "release note" for a technical change.
- **Backend feature that's still customer-relevant** (e.g. anonymization): engineering flavor, but keep a short "What the customer experiences" section in plain language.

State the chosen flavor in one line; only stop to ask if genuinely ambiguous.

### Step 4 — Screenshots

- **Prefer reuse.** Copy the relevant images from existing `Testing/`/`Reports/` evidence into the note's assets folder, renamed to a clean, ordered scheme (e.g. `01-banner-past-due.png`, `seg-02-automatic-assignment-modal.png`). Real precedent: `Reports/assets/apo-1026-smoke/evidence-05-modal-all-quotes.png` → `assets-…-segments-auto-assignment/seg-03-modal-all-quotes-selected.png`.
- **Capture fresh only if needed** and the user wants it: screenshots are taken **on Staging with the feature flag ON** (delegate to the `visual-prototype-designer` agent or the reproduction skill; never fabricate UI). Add the footer line *"Screenshots captured live on Staging with the feature flag ON."*
- **Embed style by flavor:**
  - Product note → Obsidian embeds: `![[seg-01-assignment-column.png]]` (assets folder is a sibling; Obsidian resolves by name).
  - Engineering note → markdown links with alt text and a relative path: `![Past-due banner](assets-…-slug/01-banner-past-due.png)`.
- **Backend-only feature (no UI):** skip screenshots; say plainly "no UI and no customer-facing screen", and describe before/after behavior instead.
- If a needed screen isn't available, insert a labeled placeholder line `> _TODO: screenshot — <what it should show>_` rather than omitting silently.

### Step 5 — Draft from the matching template

Use the **Engineering template** or the **Product template** below. Fill every placeholder from Step 2's material. Keep the voice of the reference outputs: short sentences, **bold the punchline**, tables for rules, and — for engineering — one fenced ASCII pipeline. Do not pad; every line should carry a fact a reader needs.

### Step 6 — Save + assets

1. Write the note to `<Vault>/<repo>/Releases/<filename>` (naming per Constants).
2. Ensure the assets folder exists and holds every image the note references, named to match.
3. Re-read the note once: does every rule/flag/threshold trace to a source? Any leftover placeholder that should be resolved? Any non-English word? Fix before committing.

### Step 7 — Commit & push the vault (MANDATORY, per global rules)

```bash
cd /Users/lucas/www/Obsidian-Vault && git add -A \
  && git commit -m "Add release note: <slug> (<repo>)" \
  && git push
```

Never skip the push. Then report the file path and a 2–3 line summary of what the note covers; if it's a product note, offer the paste-ready block for #product-releases.

---

## Engineering release note — template

Fill every `{{placeholder}}`. Drop sections that don't apply (e.g. "Manual override"). Everything in **English**.

~~~markdown
# Release Note — {{Feature Name}}

- **Date:** {{YYYY-MM-DD}}
- **Repo:** {{code-repo}}{{ (builds on <foundation> if relevant)}}
- **Scope of this release:** {{one line — what surface/area this covers}}
- **Launch switch:** {{DevCycle flag `<flag-name>` (off until cutover) | None — <what controls it, e.g. a threshold/cron>}}

## What shipped

{{2–4 sentences: what changed, the mechanism in one breath, and why it matters. Bold the key behavioral shift.}}

## {{Access rules | Eligibility rules | Behavior}} — the core

{{One line stating what decides the behavior (e.g. "decided by the mirrored Stripe status").}}

| {{Condition / State}} | {{Outcome}} | {{What the customer sees / notes}} |
| --------------------- | ----------- | ---------------------------------- |
| {{…}}                 | {{…}}       | {{…}}                              |

**{{So: the punchline — which state is the important boundary and why.}}**

{{Optional bold-led operational rules, each its own line:}}
**Manual override (ops):** {{…}}
**Auto-escalation:** {{…}}

## How {{we detect <state> | it runs}}

{{One line: event-driven vs scheduled, and the single source of truth.}}

```
{{source}}
  │  {{trigger}}
  ▼
{{service · component}}                {{what it does}}
  │  {{transport}}
  ▼
{{next component}}                     {{decision point}}
```

{{Bullets that a technical reader needs: the exact events/inputs; the columns/state kept in sync; cadence & config (env vars/flags); idempotency & safety; observability (logs/alerts).}}

## What the customer {{sees | experiences}}

{{If UI: numbered subsections, each a short paragraph + a screenshot.}}
### 1. {{Scenario}}
{{One or two sentences.}}
![{{alt}}](assets-{{YYYY-MM-DD-short-slug}}/{{01-name}}.png)

{{If backend-only: before/after bullets instead —}}
- **During {{window}}:** {{what the customer experiences}}
- **After {{event}}:** {{what changes}}
~~~

---

## Product / customer-facing launch note — template

Written to be pasted into **#product-releases**. Benefit-led, plain language, emoji section headers. Everything in **English**.

~~~markdown
# {{Feature Name}} — Launch Notes

- **Date:** {{YYYY-MM-DD}}
- **Product area:** {{area → downstream, e.g. Inventory (offerings) → Quotes}}
- **Linear project:** [{{name}}]({{url}})
- **Status:** {{🟡 **Soft launch** — <who/where first>; <full rollout when> | 🟢 **Rolling out** — <scope> | ✅ **Live** — <scope>}}
- **Feature flag:** `{{flag}}` ({{stays off until we turn it on, so nothing changes for anyone who doesn't have it yet}})

---

## 🎯 What's new

{{Plain-language: what it is and who it's for — 2–3 short paragraphs. No jargon.}}

**Why it matters:** {{the single biggest business win, concretely stated}}

---

## 👀 What it looks like

**1. {{First thing they'll notice}}** — {{one-line description}}.

![[{{seg-01-name}}.png]]

**2. {{Next step}}** — {{one-line description}}.

![[{{seg-02-name}}.png]]

{{…continue the walkthrough, one numbered step per screen…}}

---

## 💡 Example use cases

{{2–4 concrete "set it once → it does X" scenarios; end each with → the payoff.}}
- **{{Use case}}** — {{how they set it up}}. → {{the benefit}}
- **{{Use case}}** — {{how}}. → {{benefit}}

> **Rule of thumb:** {{when to choose option A vs option B}}

---

## ✨ Also better than before

- {{Adjacent fix / improvement shipped alongside}}
- {{…}}

---

## 🚦 Rollout plan

- **Now:** {{who has it today}}
- **Next{{ (target: <date>)}}:** {{full rollout scope}}
- Until then it stays behind the `{{flag}}` flag, so there is **no change** for customers who don't have it yet.

---

*{{Screenshots captured live on Staging with the feature flag ON.}}*
~~~

---

## Building blocks (mix into either flavor as the feature warrants)

- **Rule table** — the clearest way to state a state machine or eligibility matrix; one row per state, columns for outcome + what the user sees. Bold the punchline row/line right after.
- **ASCII pipeline** — for event-driven or scheduled backends: `source → gateway → worker → decision`, with the transport (webhook/SQS/cron) on the arrows. Keep it to the real components.
- **"What the customer sees/experiences"** — always translate the mechanism into user-visible terms, even for backend features.
- **Launch switch line** — every note states how it's gated: the DevCycle flag and its default, or "None" plus what actually controls it (a threshold, a cron). Default assumption is **OFF / not-yet-rolled-out** unless a source proves otherwise.
- **Provenance footer** — for product notes with live screenshots, the "captured on Staging with the flag ON" line.

---

## Guardrails

- **English only** — the note, the commit message, image names, everything written to the vault, regardless of chat language (global hard rule). Pre-flight check the content for any non-English word before writing/committing.
- **Report, don't invent.** Every rule, flag name, threshold, event, and screen must trace to a real source (git, Linear, specs/docs, DevCycle, evidence). Unverifiable → `TODO(verify)`, never a plausible guess.
- **Screenshots are real, never mocked.** Reuse staging evidence, or capture fresh on Staging with the flag ON via the proper agent/skill. Don't fabricate UI.
- **Gating is stated honestly.** If the flag is OFF / this is a soft launch, say so prominently — don't imply everyone has it.
- **Pick the flavor deliberately** and keep its voice (engineering = precise tables + pipeline; product = benefit-led + emoji sections). Don't blend into mush.
- **Always commit + push the vault** after writing (the vault has auto-backup; still run `git add -A ; git commit ; git push` so the push happens).
- **File under the product's vault `<repo>`/Releases/**, even when the code shipped from a different repo — name that code repo on the `Repo:` line instead.
- **Don't over-write.** If a note for this feature/date already exists, surface it and ask before overwriting; prefer a new dated file or an explicit update.
