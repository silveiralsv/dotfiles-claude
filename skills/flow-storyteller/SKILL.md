---
name: flow-storyteller
description: Turn context the user provides (a feature, a rule, a lifecycle, or a piece of the codebase) into a VISUAL flow diagram told like a story — a clean, self-contained SVG that walks a reader through what happens step by step, who does each step, and the key branches/decisions, in plain didactic language. It keeps the few technical facts that actually help a reader (e.g. "free users are the ones flagged `is_free`") and deliberately drops verbose internals (function names, line numbers, exact Prisma/SQL queries, controller wiring). Optimized for non-technical or mixed audiences — short labels, no walls of text. It renders and verifies the SVG, saves it (the Vault project `feedback/` folder by default), and can send it to the user. Use when the user says "explain this flow visually", "make a flow / storyteller diagram", "visualize how X works", "turn this into a diagram", "diagrama de fluxo", "explica esse fluxo num diagrama", "cria um diagrama (contando a história) disso", "feedback visual do fluxo", or liked a previous flow SVG and wants another for a new topic.
metadata:
  author: lucas
  version: "1.0.0"
  argument-hint: '<what to visualize: a description, a feature/flow name, or "explore <area>"> [→ save to <path>]'
---

# Flow Storyteller — context → didactic flow diagram (SVG)

Turn whatever context the user gives you into **one clean flow diagram that tells a story**: a reader who is *not* deep in the code should be able to follow, top to bottom, **what happens, who does it, and where it branches** — in plain language, with only the technical facts that genuinely help.

The output is a **self-contained SVG** (light theme, no external assets) in the same visual family as the work-order lifecycle diagram this skill was distilled from. Small, calm, legible. Not a wall of text; not a UML dump.

## The one rule that matters most: the didactic filter

For every fact you *could* put on the diagram, ask **"does this help the reader understand the flow, or is it plumbing?"** Keep the former in a few words; drop the latter.

| ✅ Keep (say it plainly) | ❌ Drop (plumbing / verbose) |
| --- | --- |
| The meaningful fact: *"free users are the ones flagged `is_free`"* | The lookup path: `is_free_user()` in the controller at line 624; the Prisma read on `users.free` |
| A status / state name a person would recognize (`Open`, `Draft`, `Approved`) | Enum backing types, DB column types, migration names |
| A decision and its plain condition (*"if the vendor did the work → bill the vendor"*) | The `if/else` structure, guard clauses, exception classes |
| Who acts (Resident, Staff, Vendor, Accounting, System, a cron job) | Service/class names, DI wiring, file paths |
| The business "so what" (*"money goes OUT to the vendor"*) | HTTP verbs, route strings, request/response shapes |

A named field/flag/status is fair game **when it is the thing the reader would look for** (`is_free`, `status = draft`). A function, line number, query, or class name almost never is. When in doubt, cut it — a short label beats a correct-but-noisy one.

> This skill is for **narrative flows** (a sequence with actors and branches). For pure quantitative charts (bars/lines/heatmaps), use the `dataviz` skill instead.

## Method

### 1. Get the flow (and only then filter it)
- If the user described the flow, use that. If they point at code ("explain how X works", "explore <area>"), **use the `Explore` subagent** to learn the *real* flow first — you can only filter well once you actually know it. Then throw away 90% of what you found and keep the story.
- If the scope is ambiguous (which flow? which audience? where does it start/end?), ask **one** quick `AskUserQuestion` — don't guess a wrong story.

### 2. Extract the skeleton
Pull out four things:
- **Actors** — who does each step (the personas). Keep it to a handful; give each a color (see palette).
- **Steps** — the ordered beats of the story. Aim for **4–7**; merge trivia, split only real forks.
- **Decisions / branches** — the forks, each with a plain condition. Note when branches are mutually exclusive vs. "one, the other, or **both**".
- **The "so what"** — the point of each step and of the whole flow (often a money/state/ownership change). This is what makes it a *story*, not a list.

### 3. Tell it as a story
Write each step as **"what happens + why"** in the actor's plain voice, before you draw anything. One or two short sentences per step. If a step needs a paragraph, you haven't filtered enough — go back to step 2.

### 4. Draw it (the visual system)
Author the SVG **by hand** (full control). One vertical column of step cards, connected by arrows, forking into side-by-side branch cards at decisions, merging back to a final node. Concrete spec:

- **Canvas:** `viewBox="0 0 1000 <height>"`, white background, system font stack. Grow height as needed.
- **Title** (~23px bold, `#111827`) + one-line subtitle (~13.5px, `#6b7280`) that states what the diagram covers. A small **legend** of actor chips under it.
- **Step card:** rounded rect (`rx=10`), fill `#f8fafc`, `1.5` colored border, a **6px colored left accent stripe**, a small **actor pill** (`rx=9.5`, ~11px), a **bold title** (~15px, numbered `1 · …`), and 1–2 **body lines** (~12.5px, `#374151`). Bold the key words (status names, the kept technical term) with `<tspan font-weight="700">`.
- **Arrows:** one reusable marker (`<marker id="arrow" …><path d="M0 0 L10 5 L0 10 z" fill="#9ca3af"/></marker>`), lines `#9ca3af`, `stroke-width="1.5"`.
- **Decision:** a dark pill (`fill="#111827"`, white text) phrased as a question ("Where should the cost go?"). Split with orthogonal connectors to the branch cards; add a plain note under a fork when it can be "one, the other, or BOTH".
- **Branch cards:** tint by meaning — positive/inflow emerald (`#ecfdf5`/`#059669`), outflow/cost amber (`#fffbeb`/`#d97706`), neutral slate. Give each a tiny outcome badge (e.g. `→ money goes OUT` / `→ money comes IN`).
- **Palette (actors):** teal `#0d9488`/`#ecfdf5`/`#0f766e` · indigo `#4f46e5`/`#eef2ff`/`#3730a3` · amber `#b45309`/`#fffbeb`/`#92400e` · rose `#be123c`/`#fff1f2`/`#9f1239` · emerald `#059669`/`#ecfdf5`/`#047857`. Neutrals: body `#374151`, muted `#6b7280`, lines `#9ca3af`.
- Copy `references/svg-flow-template.svg` as a starting skeleton (legend + step card + arrow marker + decision + two branches + merge + done). Adapt, don't reinvent.

**Text must fit inside its card.** Rough budget at 12.5px ≈ 6.4px per character, so a ~648px-wide card body holds ~100 characters per line — **split longer lines** onto a second `<text>` line (and grow the card height). Short beats clever.

### 5. Verify the render (do not skip)
SVG text overflow is invisible in the source. Rasterize and **look at it**:
```bash
qlmanage -t -s 1000 -o <scratchpad-dir> <path-to>.svg    # writes <name>.svg.png
```
Then `Read` the PNG. Check: no text spilling past card borders, no overlaps, arrows land right, story reads top-to-bottom. Fix and re-render until clean. (`rsvg-convert -w 1000 in.svg -o out.png` is a fallback if `qlmanage` isn't available.)

### 6. Save + present
- **Where:** if working inside a tracked project, default to the Vault `<repo>/Projects/<project>/feedback/` folder (same place the work-order diagrams live) with a descriptive `kebab-case.svg` name. Otherwise save beside the relevant work or ask. State the path.
- **Language:** anything saved to the Vault or a repo is an **external artifact → write it in English** (per the global English-only rule). A throwaway diagram purely for the user's own understanding may match their language if they ask — but the default is English.
- **Deliver:** `SendUserFile` the SVG with `display: "render"` so they see it inline, plus a 2–4 line plain-language recap of the story in chat.
- **Vault push:** if you saved into the Vault, `git -C <vault> add -A && commit && push` per the global Vault rule.

## Do / Don't
- **Do** keep it to one story per diagram. If the user asks for "everything", propose 2–3 focused diagrams instead of one crowded one.
- **Do** name the actors and color them consistently; a reader should be able to tell "who does this" at a glance.
- **Do** keep the kept-technical-terms to the ones a reader would search for (`is_free`, `status = draft`), stated in plain words.
- **Don't** put function names, line numbers, file paths, class/service names, SQL/Prisma queries, HTTP routes, or type signatures on the diagram.
- **Don't** write multi-line paragraphs inside a card. If it doesn't fit in ~1–2 short lines, it's the wrong altitude.
- **Don't** ship without rasterizing and eyeballing the PNG.
- **Don't** use external fonts/images/CSS — the SVG must be self-contained.

## Example calibration (the user's own)
> "A free user is defined by the `is_free` boolean column." → put **"Free users are the ones flagged `is_free`"** on the card.
> The controller's `is_free_user()` at line 624, and the Prisma check against `users.free` → **leave off the diagram entirely.** It's true, but it's plumbing, and it makes the explanation verbose and confusing.
