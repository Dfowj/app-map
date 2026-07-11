# App Map — Implementation Handoff

A navigable, living document of every **surface** in the app: its behavior, dependencies, states, and navigation. It serves two audiences — humans reading current-state documentation, and agents using it as a searchable context index for the codebase.

This handoff pins down the **model and the rules**. Where an approach is a suggestion rather than a requirement, it's flagged as a **Recommendation** — adapt it as the implementation takes shape.

---

## 1. The one idea everything hangs on: **map-as-projection**

The map **describes what is** — the current state of the codebase. It is refreshed *from* code; it is not a place to author intent (no todos, no specs, no wishlist).

This is what makes edits-as-signal safe: a human or agent can edit the map to *propose* a change, but recompute reclaims anything the code didn't actually land. The diff is a transient nudge; the code is the arbiter. **Durable, not permissive** — the map can never quietly drift into a plan.

Corollary — the operating philosophy for all automation: **warn, record, never block.** Anything computable is written for free. Anything needing human judgment is *flagged*, not gated. Nothing this system does may ever block a commit, a push, or a deploy.

---

## 2. Vocabulary (make these definitions load-bearing)

**Surface** — a full-screen experience, *or* a navigational container that hosts full-screen experiences.
- **Is a surface:** a pushed screen, a tab root, the tab bar itself, a sheet, a modal, a popover.
- **Is _not_ a surface:** alerts, toasts, error banners, inline error messages.
- Rule of thumb: correlated to size on screen **and** whether it represents a whole task/experience.

**State** — a variant of one surface (e.g. Cart `empty` vs `default`). States live *inside* a single surface record; they do not spawn new surfaces. A state may carry its own screenshot and note.

**`kind`** — `screen | tab-root | tab-bar | sheet | modal | popover | container`.

Three distinct relationship types — **do not conflate them**, they mean different things to the graph:
- **Edge** — a navigation transition (push, present, tab-switch, deep-link). Directional.
- **Containment** — structural nesting (the tab-bar *contains* its tabs). Tapping a tab is a switch, not a push; modeling it as an edge would corrupt reachability.
- **Entry point** — a way *into* a surface from outside the app graph (deep link, push-notification destination, widget, Siri). First-class, because for a shopping app external entry is half the real navigation.

---

## 3. Ownership model → the three output classes

Every field has exactly one owner. Ownership determines recompute behavior, and it maps cleanly onto the three-way classification you asked for.

| Tier | Owner | On recompute | Output class |
|---|---|---|---|
| **1 — Mechanical** | Script | Always overwritten | **Deterministic** |
| **2 — Asserted, code-grounded** | Agent (hook-validated) | Refreshed on code change; reconciled | **Agentic** |
| **3 — Authored** | Human | Preserved always (agent may *suggest*, never overwrite) | **Manual** |

Recompute = **refresh tier 1 · reconcile tier 2 · never touch tier 3.** No one's edits are ever silently destroyed, because ownership is explicit.

---

## 4. File & directory layout

```
app-map/
  manifest.yaml            # committed · tier-1 · regenerated — the "front door"
  app-map.config.yaml      # committed · hand-authored tool config
  schema/
    surface.schema.json    # validation schema for surface frontmatter
  surfaces/
    cart/
      surface.md           # frontmatter (tiers 1&2) + body (tier 3)
      screenshot.default.png
      screenshot.empty.png
    checkout/
      surface.md
      ...
  rendered/                # gitignored build output (html, graphs)
```

Key decisions baked in:
- **Folder-per-surface** so data, prose, and screenshots for one surface live together.
- **Renders are gitignored.** Only *records* are committed, which keeps commit diffs to source-of-truth changes — exactly the signal the hook keys on. The HTML view is rebuilt on demand / on a periodic cadence, surfaced via a top-level repo link.
- **The manifest _is_ committed** (unlike `rendered/`), because tooling consumes it as the fast index.

---

## 5. Schemas

### 5a. `surfaces/<id>/surface.md`

```yaml
---
# ── TIER 2 (agent-asserted, code-grounded, hook-validated) ──────────
id: cart                       # TIER-manual: immutable slug, human-set once, never changes
title: Cart
kind: screen
code_anchor:                   # mutable; hook flags if file/symbol vanishes
  file: Sources/Cart/CartView.swift
  symbol: CartView
contains: []                   # structural nesting (tab-bar → [home, search, cart, profile])
edges:                         # OUTGOING only — incoming is derived at render
  - id: checkout-cta           # stable key; required because `to` isn't unique
    to: checkout
    via: present
    presentation: sheet
    trigger: "Tap 'Checkout'"
    note: >                    # TIER-3, preserved on merge
      Only enabled when cart total > $0 and a shipping address is on file.
  - id: line-item-tap
    to: product-detail
    via: push
    trigger: "Tap a line item"
entry_points:
  - { type: deepLink, value: "shopper://cart" }
  - { type: pushNotification, note: "Abandoned-cart reminder" }
states:
  - { name: default, screenshot: screenshot.default.png }
  - { name: empty,   screenshot: screenshot.empty.png }
dependencies:
  external: [Stripe]           # notable external only — not internal packages
  data:
    - { type: model, name: Cart }
    - { type: fetch, name: "GET /cart", note: "Paginated for >50 items" }
# ── TIER 1 (mechanical, script-owned) ──────────────────────────────
last_verified: { sha: a1b2c3d, date: 2026-07-09 }
needs_review: false
---

## Description        ← TIER 3 · preserved across recompute
## Goal
## KPIs
## Notes
```

**Annotations are a field-level hybrid.** Any structured item may carry an optional tier-3 `note` (edges, data deps, states…). The item's *shape* is tier-2 (agent-owned); its `note` is tier-3 (human-owned, preserved on merge). This is why annotatable list items need a stable identity — edges get an explicit `id`; elsewhere a natural key exists (states by `name`, entry points by `type+value`, deps by `name`).

### 5b. `manifest.yaml` — the front door (all fields derived, tier-1)

```yaml
generated_at: 2026-07-09T14:20:00Z
map_sha: a1b2c3d
launch_surface: tab-bar         # the app-graph ROOT — reachability computes from here
surfaces:                        # index so agents read ONE file, not N
  cart:     { title: Cart,     kind: screen,   path: surfaces/cart/surface.md,   last_verified: a1b2c3d, needs_review: false }
  checkout: { title: Checkout, kind: sheet,    path: surfaces/checkout/surface.md, last_verified: 9f8e7d6, needs_review: true }
review_queue: [checkout]         # projection of per-surface needs_review flags
graph_health:
  orphans: []                    # no incoming edge and not an entry point
  dead_ends: []
  dangling_edges: []             # edge `to:` a nonexistent id
  unreachable_from_launch: []
```

Two distinctions to preserve:
- **Documentation entry point vs app-graph root.** The manifest itself is where a *reader/agent* starts. `launch_surface` (stored inside it) is where the *app's* graph begins. Different things; both belong here.
- **`needs_review` lives per-surface (source of truth); the manifest only indexes it.** A central mutable file is a merge-conflict magnet; keeping the flag local and the manifest *derived* means manifest conflicts are low-stakes — resolve by taking either side and re-rendering. Self-healing.

### 5c. `app-map.config.yaml` — hand-authored tool config (tier-3-ish)

Source globs for code anchors, screenshot-path resolution rules, render options/output dir, `launch_surface` declaration, ignore lists.

---

## 6. Classification: what's **deterministic**, **agentic**, and **manual**

The master reference. Where a row is a *hybrid*, it's split into its deterministic and agentic halves.

### Deterministic (script-owned — computed, never reasoned about)

- Stamp `last_verified` (SHA + date) on any surface whose record changed.
- Resolve/validate screenshot paths against snapshot-test output locations.
- **Derive incoming edges** by inverting all surfaces' outgoing edges at render.
- **Graph computation:** orphans, dead-ends, dangling edges, unreachable-from-launch.
- **Drift *detection*:** "surface source file changed but its record didn't" → set `needs_review: true`, print warning, **exit 0.** (Detection is a file diff — deterministic. *Resolution* is agentic, below.)
- Regenerate `manifest.yaml` (index, review_queue, graph_health).
- Render outputs (HTML per-surface pages, searchable index, nav graph) into `rendered/`.
- **Merge *mechanics*:** given tier-2 values from the agent, apply the keyed merge (match key → overwrite tier-2 fields → preserve tier-3 `note`). The *how* of merging is mechanical; the *values* are agentic.
- Schema validation of frontmatter against `surface.schema.json`.

### Agentic (requires reasoning — the coding agent asserts these)

- **Decide whether an edge exists, changed, or was removed.** SwiftUI nav can't be reliably derived statically (declarative nav, `NavigationStack` paths, programmatic pushes, deep links), so edges are *asserted from code understanding*, not parsed.
- Classify `kind`; identify `contains` relationships.
- Identify **states** of a surface.
- Distinguish **notable external deps** from internal packages; identify data deps (models, fetches, APIs).
- Identify **entry points** (deep links, push destinations, widgets).
- **Reconcile tier-2 on code change** — supply updated values for the deterministic merge.
- **Resolve drift** flagged by the hook — inspect the changed source, update the record, clear `needs_review` (or leave flagged with a reason if human judgment is needed).
- Assign edge `id` slugs (see Recommendation 3).
- **Suggest** tier-3 content (description/goal/notes) — surfaced as a proposal, **never written over** existing human prose.

### Manual (human-authored — tools preserve, may suggest, never overwrite)

- `id` — the immutable slug, set once at surface creation.
- Body prose: **Description, Goal, KPIs, Notes.**
- `note` annotations on edges / data deps / states (the "color" — *how/when* a transition fires, caveats).
- `app-map.config.yaml`.
- Final call on any `needs_review` item that the agent couldn't resolve unambiguously.

---

## 7. Components to build

### A. Render / compute script — *deterministic*
Reads all records → derives incoming edges → runs graph validations → regenerates `manifest.yaml` → emits `rendered/`. Two modes:
- **incremental** (hook path): patch only the changed surface's manifest entry + re-stamp its `last_verified`.
- **wholesale** (`render`): rebuild manifest + all outputs from scratch. An imperfect incremental patch self-corrects here.

### B. Commit hook (local) — *deterministic detection, agentic resolution deferred*
On commit touching `app-map/**` or a surface's `code_anchor.file`:
1. Re-stamp `last_verified` for changed records (free).
2. If a surface's **source** changed but its **record** didn't → set `needs_review: true`, print a visible warning naming the surface.
3. Patch the manifest index for changed surfaces.
4. **Exit 0 unconditionally.** Never blocks. The urgent-bugfix path: mechanical updates land for free, higher-order drift is *visible debt*, nothing is gated.

### C. Agent skill / instructions — *agentic*
A skill (`SKILL.md` + supporting scripts) the coding agent invokes when working in the app. Responsibilities:
- On a code change affecting a surface, update tier-2 fields and supply values to the merge.
- Work the `review_queue` from the manifest — resolve flagged drift, clear or annotate `needs_review`.
- Create new surface records (scaffold folder + frontmatter, prompt human for `id` and tier-3 prose, or leave placeholders).
- Propose tier-3 suggestions without overwriting.
- Read the manifest first as the fast index rather than opening every surface file.

### D. Validations — *deterministic* (the linter's teeth)
Dangling edge · orphan · dead-end · unreachable-from-launch · stale/invalid `code_anchor`. Reported in `graph_health`; surfaced in the render; warnings only.

### E. Screenshots — *deterministic upkeep, declarative source*
Tie each state's screenshot to a **stable snapshot-test output path** (tests can be written/adjusted to match the map's needs). The record references the path; the script validates it resolves; regenerating snapshots regenerates map imagery. No manual capture, no silent staleness.

---

## 8. Implementation recommendations (adapt as you see fit)

These fell out of the design discussion. They're **starting points**, not mandates — the implementor decides how they fit as the build takes shape.

1. **Keyed-merge reconcile.** For each annotatable array, define `(match key, overwrite-set, preserve-set)`. Edges → key `id`, overwrite `{to, via, presentation, trigger}`, preserve `{note}`. States → key `name`. Entry points → key `type+value`. Data deps → key `name`. If a note-bearing item disappears from code, don't silently drop it — flag `needs_review` and let a human decide.

2. **Manifest regeneration.** Incremental patch on the hook (cheap — the changed file is already parsed) + wholesale rebuild on full render (self-correcting). Keep surface entries sorted by `id` so diffs stay localized and conflicts stay small.

3. **Edge-`id` convention.** Agent auto-slugs from the trigger (`"Tap 'Checkout'"` → `checkout-cta`); human may rename; **stable once a `note` is attached** (renaming after annotation would orphan the note on the next merge).

---

## 9. Suggested build order

1. **Schema + one hand-written surface record.** Prove the shape feels right before automating anything.
2. **Render/compute script** (wholesale mode) → manifest + basic HTML from records. Deterministic core, testable in isolation.
3. **Graph validations** wired into the render.
4. **Screenshot path resolution** against the snapshot suite.
5. **Commit hook** (stamp + drift-flag + manifest patch, exit 0).
6. **Agent skill** — the last and most iterative piece, since it depends on all the deterministic scaffolding existing to write into.

---

## 10. Decisions intentionally left to the implementor

- Exact frontmatter serialization details and schema strictness.
- Incremental-manifest patch fidelity (how much it does before deferring to wholesale).
- Render stack / graph-viz choice for `rendered/`.
- Whether the agent skill auto-runs on commit vs. is invoked on demand vs. both.
- How aggressively the agent proposes tier-3 suggestions.

---

### The spine, in one breath
Map-as-projection · three ownership tiers (deterministic / agentic / manual) · field-level merge for hybrids · per-surface truth indexed by a derived manifest · **warn, record, never block.**
