# App Map PRD

Requirement documentation for App Map, a tool for mapping an app's surfaces and their connections.

Requirements are tagged `[IMPLEMENTED]` (built and doing this today) or `[PLANNED]`
(intended, not built yet).

## Table of Contents

- [What is the App Map?](#what-is-the-app-map)
  - [Tell the story of how the App Map works](#tell-the-story-of-how-the-app-map-works)
  - [Agent Skill encodes surface data into records following the schema](#agent-skill-encodes-surface-data-into-records-following-the-schema)
  - [Renderer computes throwaway html for use by humans](#renderer-computes-throwaway-html-for-use-by-humans)
  - [Scripts/Hooks maintain the records deterministically](#scriptshooks-maintain-the-records-deterministically)
- [Requirements](#requirements)
  - [Skill](#skill)
  - [Renderer](#renderer)
  - [Scripts](#scripts)

---

## What is the App Map?

### Tell the story of how the App Map works

The App Map is a map of an app's surfaces — its screens, sheets, tabs, modals, and
the navigation between them — kept as a set of small records that live beside the
code and are refreshed from it. It's a projection: it describes what the app *is*,
not what anyone wants it to become, so it never holds todos, specs, or wishlists.

The map stays current through a loop with three actors:

- An **agent Skill** reads the code and writes what it finds into surface records.
- **Scripts and hooks** keep the mechanical parts of those records honest,
  deterministically, every time they change.
- A **renderer** turns the records into throwaway HTML a human can browse.

The records are the source of truth — they're what gets committed. The rendered
HTML is build output: regenerated on demand, gitignored, never the thing you edit.

What keeps three different authors from stepping on each other is a strict
ownership model. Every field in a record has exactly one owner:

- **Tier 1 — mechanical.** Derived by scripts and always overwritten — backlinks,
  the manifest, validation state, the verification stamps.
- **Tier 2 — asserted.** Written by the agent Skill, grounded in code, reconciled
  when the code changes — `title`, `kind`, `code_anchor`, `edges`, and the like.
- **Tier 3 — authored.** Written by a human — the surface `id`, the body prose,
  and any `note` annotations. Preserved always; the agent may suggest, never
  overwrite.

One rule sits above all the tooling: **warn, record, never block.** Nothing the
App Map does may gate a commit, push, or deploy. Every command exits 0; problems
are reported for attention, never enforced.

### Agent Skill encodes surface data into records following the schema

The Skill is the agent side of the loop. Pointed at the app's code, it identifies
surfaces and encodes them as records under `app-map/surfaces/<id>/surface.md`,
filling in the Tier-2 fields it can ground in code — the surface's title and kind,
its `code_anchor`, outgoing edges, entry points, states, and dependencies — all
shaped by `surface.schema.json`. Where prose would help it may suggest Tier-3
notes, but it never rewrites what a human wrote. As the code drifts, the Skill's
job is to reconcile its Tier-2 assertions and work down the review queue. This
actor is largely not built yet.

### Renderer computes throwaway html for use by humans

The renderer turns the records into a small static site — an index of every
surface plus one page each — so a person can browse the map without reading YAML.
Each surface page shows where it navigates to, what navigates to it (derived), and
the human's notes. The output is throwaway: written to `app-map/rendered/`,
gitignored, and rebuilt from the records whenever you run `render`.

### Scripts/Hooks maintain the records deterministically

The scripts are the mechanical spine. They own every Tier-1 detail and recompute
it from scratch, deterministically, so those parts of a record are never
hand-maintained and never drift. They parse and rewrite records without touching
prose, invert edges into backlinks, rebuild the manifest index, and validate the
map — warning about broken links, stale code anchors, and missing screenshots
without ever blocking. A planned commit hook extends this to stamping each changed
record's `last_verified` and flagging records whose source moved out from under
them.

---

## Requirements

### Skill

The agent that reads code and encodes surfaces as records. Largely unbuilt today;
the schema and records it targets exist, but the Skill itself is deferred
(`skill/SKILL.md`).

- Identifies an app's surfaces from its code and writes one record per surface
  under `app-map/surfaces/<id>/surface.md`. `[PLANNED]`
- Asserts the Tier-2 fields it can ground in code — `title`, `kind`,
  `code_anchor`, `edges`, `entry_points`, `states`, `dependencies` — conforming
  to `surface.schema.json`. `[PLANNED]`
- May suggest Tier-3 prose (`note` annotations, body text) but never overwrites
  human-authored content. `[PLANNED]`
- Reconciles its Tier-2 assertions when the underlying code changes, and works
  down the review queue, clearing `needs_review` once a record is confirmed.
  `[PLANNED]`

### Renderer

Turns records into browsable, throwaway HTML. Built today.

- `render` writes an index page — searchable, with review-queue and broken-link
  banners — plus one HTML page per surface. `[IMPLEMENTED]`
- Each surface page shows its outgoing edges, its derived incoming backlinks, and
  the body prose (rendered through a small markdown subset). `[IMPLEMENTED]`
- A state's screenshot is inlined when the image resolves; otherwise the page
  notes it as unresolved. `[IMPLEMENTED]`
- Output lands in `app-map/rendered/`, which is gitignored — only records and the
  manifest are committed. `[IMPLEMENTED]`

### Scripts

The deterministic Tier-1 layer. This is the built core of the tool.

**Reading and rewriting records safely**

- Frontmatter is split from the markdown body and the body round-trips
  byte-for-byte, so rewriting mechanical fields never disturbs human prose.
  `[IMPLEMENTED]`
- A file with no frontmatter is tolerated: empty data, whole text kept as the
  body. `[IMPLEMENTED]`
- `---` fence sequences inside the body survive the round-trip. `[IMPLEMENTED]`
- Records load sorted by `id`, so downstream output is deterministic.
  `[IMPLEMENTED]`
- Missing fields read back as sane defaults: `id` → the folder name, `kind` →
  `"screen"`, list/dict fields → empty. `[IMPLEMENTED]`

**Deriving the navigation graph**

- Each outgoing `edge.to` is inverted into an incoming backlink on its target
  surface. `[IMPLEMENTED]`
- An `edge.to`, a `contains` child, or an `entry_point.to` naming a surface with
  no record is recorded as a dangling link, tagged with its kind. `[IMPLEMENTED]`
- An edge with no `to` value is skipped, not flagged. `[IMPLEMENTED]`
- A fully valid graph (every target exists) yields zero dangling links.
  `[IMPLEMENTED]`
- Reachability / orphan / dead-end analysis is out of scope for now. `[PLANNED]`

**Building the manifest index**

- `render` rebuilds `app-map/manifest.yaml` wholesale as a fully-derived index,
  safe to regenerate at any time. `[IMPLEMENTED]`
- The index lists, per surface (id-sorted): `title`, `kind`, `path`,
  `last_verified.sha`, and `needs_review`. `[IMPLEMENTED]`
- `review_queue` is projected from each surface's `needs_review` flag.
  `[IMPLEMENTED]`
- `link_health.dangling_links` carries the broken links found above.
  `[IMPLEMENTED]`
- `launch_surface` passes through from config. `[IMPLEMENTED]`
- The manifest carries no volatile fields — no wall-clock timestamp, no git sha —
  so a re-render on unchanged records is byte-identical and committing it creates
  no churn. `[IMPLEMENTED]`

**Validating and warning on drift**

- `validate` reports findings for the human's attention and never fails a build;
  severity (`warn` / `error`) only ranks attention — everything exits 0.
  `[IMPLEMENTED]`
- Frontmatter is checked against a hand-rolled schema subset
  (`required` / `type` / `enum` / `pattern`); violations are warnings.
  `[IMPLEMENTED]`
- A `code_anchor.file` missing on disk is an error-severity finding (still exit
  0). `[IMPLEMENTED]`
- A `code_anchor.symbol` absent from its file (word-boundary search) is a warning.
  `[IMPLEMENTED]`
- A state `screenshot` that resolves to no file is a warning. `[IMPLEMENTED]`
- Dangling links surface as error-severity findings. `[IMPLEMENTED]`
- `validate` never raises, even on a deliberately broken map. `[IMPLEMENTED]`

**Finding and bootstrapping a map**

- `find_map_dir` locates the nearest `app-map/` — the cwd's child, the cwd itself
  if it *is* `app-map/`, then walking up parents; returns nothing if none is
  found. `[IMPLEMENTED]`
- `load_config` reads `app-map.config.yaml` and fills sane defaults for absent
  keys. `[IMPLEMENTED]`
- Commands (`init` / `validate` / `render`) exit 0 for normal work; only CLI
  misuse or a missing map exits non-zero. `[IMPLEMENTED]`
- `init` scaffolds `app-map/`, always refreshing the canonical schema copy but
  never clobbering an existing config. `[IMPLEMENTED]`
- The `./app-map` wrapper preflights `python3` + `pyyaml`, bootstraps a local
  `.tool-venv` once, and warns (no stack trace) when dependencies are missing. It
  is the single entry the commit hook will also call. `[IMPLEMENTED]`

**Maintaining records on commit (hooks)**

- On a commit touching `app-map/**` or a surface's `code_anchor.file`, re-stamp
  that record's `last_verified` (sha + date). Today `last_verified` is only ever
  read, never written by a script. `[PLANNED]`
- When a surface's source changed but its record didn't, set `needs_review: true`
  and print a visible warning naming it. `[PLANNED]`
- A thin pre-commit shim calls `./app-map` to stamp `last_verified`, drift-flag
  `needs_review`, patch the manifest, and exit 0 unconditionally. `[PLANNED]`

---

See also: [`CLAUDE.md`](CLAUDE.md) (invariants + conventions),
[`plans/app-map-tooling.md`](plans/app-map-tooling.md) (full design),
[`appmap/schema/surface.schema.json`](appmap/schema/surface.schema.json) (per-field
tier ownership).
