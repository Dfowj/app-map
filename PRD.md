# App Map — what it is and why you'd want it

*Product & architecture doc. For working conventions in this repo, see
[CLAUDE.md](CLAUDE.md); for the build story, [plans/development-plan.md](plans/development-plan.md).*

## The problem

Every team has a version of this conversation:

> "What screens do we actually have?"
> "What can you get to from the cart?"
> "Is the onboarding doc still accurate, or did that flow change in March?"

The answers live in the code, so only people who read the code have them.
Documents written to fix this rot immediately — they're maintained by hand, on
goodwill, and the codebase doesn't wait. The result is that PMs, designers, and
new engineers navigate the app by tribal knowledge and screenshots in Slack.

App Map fixes the maintenance problem, not just the documentation problem. The
map is **descriptive, not declarative** — it records what each screen *is*,
grounded in code — and it's maintained by the coding agent **at the moment of
change**, when the knowledge is free: the agent that just modified the cart
screen already holds the code it read and the reason for the change. Writing
the record costs it a minute; no human ever has to "remember to update the
docs."

## What you get

One `app-map/` folder in your repo. Inside it, one small markdown record per
**surface** — screen, sheet, tab, modal — plus a derived index and a derived
browsable site.

**If you're a PM or designer**, open `app-map/rendered/index.html`:

- A searchable directory of every surface — name, kind, a one-line description,
  how many ways in and out.
- A navigation graph: the whole app as a diagram, tab structure and
  screen-to-screen flows, each node clickable through to its detail page.
- Per-surface pages answering "what is this, what connects to it, what does it
  look like empty?" — states with screenshots, entry points like deep links,
  and the prose your team wrote.
- Trust signals built in: each page shows when its record was last verified
  against code, and anything flagged as possibly stale says so.

**If you're an engineer**, each record is anchored to a real file and symbol
(`CartView.swift` · `CartView`), so the map doubles as a code index. The
things you'd review-comment on are checked mechanically: links to screens that
don't exist, anchors to files that moved, records whose source changed
underneath them.

**If you're a coding agent**, `manifest.yaml` is your fast index of the app's
surfaces, the schema is your contract, and the skill tells you when and how to
write. You get a map of unfamiliar territory before your first edit.

## How to use it

Setup is three steps (full text in [dropin/app-map/INSTALL.md](dropin/app-map/INSTALL.md)):
copy the `app-map/` folder into your repo, register the skill with your agent,
optionally symlink the pre-commit hook. The CLI is a committed universal macOS
binary — nothing to install or build.

Day to day, nobody "uses" App Map; it rides along:

1. **You code (with an agent).** The agent finishes a task that touched a
   surface and, as part of finishing — like updating a test — creates or
   reconciles that surface's record, then runs `appmap validate` and
   `appmap render`.
2. **You commit.** The pre-commit hook stamps the records that moved with the
   commit as verified. If source changed but its record didn't, the surface is
   flagged `needs_review` — visibly, in the commit output and on the rendered
   site. **Nothing ever blocks the commit.**
3. **The queue drains.** The next agent session sees the review queue in the
   manifest, re-reads the changed code, reconciles the records, clears the
   flags.
4. **Anyone browses.** `open app-map/rendered/index.html`.

## Why you can trust it (design pillars)

**Descriptive, not declarative.** Code is the source of truth; the map records
what *is*. No roadmaps, no wishlists, no "TODO: add search here." A map that
mixes fact with intent can't be trusted as either.

**Warn, record, never block.** No App Map tool gates a commit, push, or
deploy — every command exits 0. Findings rank attention; they never rank
permission. The moment doc tooling can fail a commit, it gets deleted.

**Three ownership tiers.** Every field has exactly one owner, so automation
and humans never fight:

| Tier | Owner | Examples | Rule |
|---|---|---|---|
| 1 — mechanical | scripts | `last_verified`, `needs_review` | always overwritten |
| 2 — asserted | agent | kind, code anchor, edges, states, deps | reconciled against code |
| 3 — authored | humans | `id`, body prose, `note` annotations | never overwritten or deleted; agent may *add* a grounded note |

**Drift is detected, not prevented.** You can't stop code from outrunning
docs; you can notice within one commit. The stamp/flag/queue cycle keeps the
gap short and — crucially — *visible*: an unmaintained map looks unmaintained.

**Records are the source of truth.** The manifest and rendered site are
derived, deterministic, and disposable — regenerate anytime, byte-identical if
nothing changed. Merge conflict in the manifest? Take either side, re-render.

## The data model, in one record

```markdown
---
id: cart                          # tier 3: immutable slug
title: Cart
kind: tab-root                    # screen | tab-root | tab-bar | sheet | modal | popover | container
code_anchor:
  file: Sources/ShopMini/Cart/CartView.swift
  symbol: CartView
watches:                          # extra files that carry this surface's logic;
  - Sources/ShopMini/Cart/CartViewModel.swift   # drift detection covers them too
edges:                            # OUTGOING navigation only; incoming is derived
  - id: checkout-cta
    to: checkout
    via: present
    trigger: "Tap 'Checkout'"
    note: Only enabled when cart total > $0.   # tier 3: human property
entry_points:
  - { type: deepLink, value: "shopmini://cart", to: cart }
states:
  - { name: default, screenshot: screenshot.default.png }
  - { name: empty,   screenshot: screenshot.empty.png }
dependencies:
  data:
    - { type: fetch, name: "GET /cart" }
last_verified: { sha: 'abc1234', date: '2026-07-13' }   # tier 1: stamped by hook
needs_review: false                                      # tier 1: drift flag
---

## Description                    ← tier 3: human prose, preserved verbatim

The shopping cart. Shows line items or an empty state, and gates the
checkout sheet.
```

Three relationship types, never conflated: **edges** (outgoing navigation),
**contains** (structural nesting — a tab bar contains its tab roots; tapping a
tab is a switch, not a push), and **entry points** (ways in from outside the
app — deep links, notifications, widgets). Variants of one screen (cart empty
vs. filled) are **states**, not separate surfaces. Incoming links are always
derived at render time, never stored — one source of truth per fact.

The full contract is [schema/surface.schema.json](schema/surface.schema.json).

## Architecture

**Agent-first, tools-after.** The skill
([dropin/app-map/skill/SKILL.md](dropin/app-map/skill/SKILL.md)) is the
product: it defines the encoding moment, the tier boundaries, and the
reconcile discipline. The CLI exists to serve it — each command was added when
the agent (or its human) hit the need, in order:

| Command | Need it answers |
|---|---|
| `appmap validate` | "Is the map internally sound?" — schema violations, dangling links, dead anchors, vanished symbols. |
| `appmap render` | "Let a human browse this." — rebuilds `manifest.yaml` + the static site in `rendered/`. |
| `appmap stamp` | "Notice drift at commit time." — run by the pre-commit shim. |

**Implementation** (`cli/`, Swift, `swift-argument-parser` + `Yams`, ~52 unit
tests): a compiled universal binary with zero runtime dependencies, committed
into the drop-in folder so consuming repos copy one folder and run. Details
that carry the invariants:

- *Byte-safe writes.* Record parsing keeps the body and raw frontmatter text
  verbatim; the only write path (`stamp`) patches the two tier-1 lines
  surgically, so hand-authored YAML formatting and human prose survive
  byte-for-byte.
- *Deterministic derivation.* The manifest emitter and renderer produce
  byte-identical output for unchanged records — derived files never generate
  diff noise. Even the navigation graph is laid out deterministically (BFS
  layers from the launch surface; no physics, no randomness).
- *`last_verified.sha` is the parent commit* — the codebase state the record
  was verified on top of; the commit's own sha doesn't exist at pre-commit
  time. The error is conservative: a future reconciler diffing from it can see
  already-reconciled changes, but can never miss one.
- *Static, self-contained rendering.* Inline CSS/JS, no external requests, no
  server — `rendered/` works from the filesystem and stays gitignored.

**Distribution is scrappy on purpose.** Tool + data ship as one committed
folder; the binary is compiled here, in this repo, never in consuming repos.
Splitting tool from data is a later problem, taken on when binary churn in git
actually hurts.

## Non-goals and current limits

- **Not a spec tool.** It will never hold intended behavior — that's what
  tickets and design docs are for.
- **Not a gate.** No CI failure mode exists, by design.
- **Honor-system encoding.** Record quality depends on the agent following the
  skill; `validate` catches structural breakage, not missing insight.
- **macOS-only binary** today; Linux users build from `cli/`. Screenshot
  capture and reachability analysis are parked until a real need lands
  ([TODOS.md](TODOS.md), plan's Parked section).
