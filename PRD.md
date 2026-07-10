# App Map — Tier 1 behavior (light PRD)

This document specifies the **Tier 1** layer of the App Map tool: the mechanical,
script-owned behavior. It's written to be read top-down — start with what the
tool is, then the mental model, then each capability. Every acceptance criterion
is tagged `[IMPLEMENTED]` (there's code and it does this today) or `[PLANNED]`
(intended, not built yet), with a pointer to the source.

Related docs: [`CLAUDE.md`](CLAUDE.md) (invariants + conventions),
[`plans/app-map-tooling.md`](plans/app-map-tooling.md) (full design).

---

## 1. What the App Map is

The App Map is a **map-as-projection** of an app's surfaces (screens, sheets,
tabs, modals, …), refreshed *from* the code. It describes *what is*, never intent
— no todos, specs, or wishlists live in it.

- **Records are the source of truth.** Each surface is a folder
  `app-map/surfaces/<id>/surface.md`: YAML frontmatter + a markdown body. These
  records (plus config, schema, and the derived `manifest.yaml`) are what gets
  committed.
- **`rendered/` is throwaway build output.** The browsable HTML is regenerated
  on demand and is gitignored; commit diffs stay meaningful because only records
  and the (stable) manifest are tracked.
- **Operating philosophy: warn, record, never block.** No tool action may gate a
  commit, push, or deploy. Every command exits 0; only CLI misuse (bad args, no
  map found) returns non-zero. `[IMPLEMENTED]`
  [`appmap/__init__.py`](appmap/__init__.py), [`appmap/cli.py`](appmap/cli.py)

## 2. The three ownership tiers

Every field in a record has exactly one owner. This is the model that makes every
rule below make sense:

- **Tier 1 — mechanical, script-owned.** Derived/computed; **always
  overwritten** on recompute. (This document.)
- **Tier 2 — agent-asserted, code-grounded.** Written by the agent, validated
  against code, reconciled on change.
- **Tier 3 — human-authored.** The surface `id`, the markdown body prose, and
  `note:` annotations. **Preserved always** — the agent may suggest, never
  overwrite.

The Tier 1 scripts must never damage Tier 2 or Tier 3 material. The load-bearing
enforcement is in §3.

Per-field tier ownership is documented inline in
[`appmap/schema/surface.schema.json`](appmap/schema/surface.schema.json) and the
scaffold [`appmap/templates/surface.md`](appmap/templates/surface.md).

## 3. Safe record handling

**Purpose:** the tool reads and rewrites surface records without ever damaging
the human's prose.

- When a record is parsed and re-serialized, the YAML frontmatter is split from
  the markdown body and the **body round-trips byte-for-byte** — compute never
  rewrites prose as a side effect. `[IMPLEMENTED]`
  [`appmap/model.py:72`](appmap/model.py) (`dumps`),
  [`appmap/model.py:85`](appmap/model.py) (`parse_surface`)
- A file with no frontmatter is tolerated: `data` comes back empty and the whole
  text is kept as the body. `[IMPLEMENTED]` [`appmap/model.py:91`](appmap/model.py)
- `---` fence sequences appearing inside the body survive the round-trip (the
  split only consumes the first two fences). `[IMPLEMENTED]`
  [`appmap/model.py:94`](appmap/model.py)
- Records load in a stable order (sorted by `id`) so downstream output is
  deterministic. `[IMPLEMENTED]` [`appmap/model.py:104`](appmap/model.py)
  (`load_surfaces`)
- Missing fields fall back to sane defaults when read: `id` → the surface's
  folder name, `kind` → `"screen"`, list/dict fields → empty. `[IMPLEMENTED]`
  [`appmap/model.py:32`](appmap/model.py)

## 4. Understanding how surfaces connect

**Purpose:** the tool derives the navigation graph from each surface's *outgoing*
edges, so the map can show both directions and catch broken links. (Only outgoing
edges are authored; incoming links are always derived.)

- Every outgoing `edge.to` is inverted into an **incoming backlink** on the
  target surface. `[IMPLEMENTED]` [`appmap/links.py:44`](appmap/links.py)
  (`build_links`)
- An `edge.to`, a `contains` child, or an `entry_point.to` that names a
  surface with no record is recorded as a **dangling link**, tagged with its kind
  (`edge` / `contains` / `entry_point`). `[IMPLEMENTED]`
  [`appmap/links.py:49`](appmap/links.py)
- An edge with no `to` value is skipped, not flagged as dangling. `[IMPLEMENTED]`
  [`appmap/links.py:52`](appmap/links.py)
- A fully valid graph (every target exists) yields zero dangling links.
  `[IMPLEMENTED]`
- No reachability / orphan / dead-end analysis is done here — that's deferred.
  `[PLANNED]` [`appmap/links.py:9`](appmap/links.py)

## 5. The front-door index (manifest)

**Purpose:** `render` rebuilds `app-map/manifest.yaml` wholesale as a stable,
fully-derived index of the map — safe to regenerate at any time.

- The surface index lists, per id (id-sorted): `title`, `kind`, `path`,
  `last_verified.sha`, and `needs_review`. `[IMPLEMENTED]`
  [`appmap/manifest.py:28`](appmap/manifest.py)
- `review_queue` is projected from each surface's `needs_review` flag (sorted).
  `[IMPLEMENTED]` [`appmap/manifest.py`](appmap/manifest.py)
- `link_health.dangling_links` carries the broken links found in §4.
  `[IMPLEMENTED]`
- `launch_surface` is passed through from config. `[IMPLEMENTED]`
- The manifest carries **no volatile fields** — no wall-clock timestamp, no git
  sha — so a re-render on unchanged records produces a **byte-identical** file
  and committing it creates no churn. `[IMPLEMENTED]`
  [`appmap/manifest.py:1`](appmap/manifest.py)

## 6. Warning on drift and broken things (validate)

**Purpose:** `validate` reports problems for the human's attention and **never
fails a build**. Findings carry a severity (`warn` / `error`) purely to rank the
human's attention — both still exit 0.

- Frontmatter is checked against a hand-rolled JSON-schema subset
  (`required` / `type` / `enum` / `pattern`); any violation is a WARN finding.
  `[IMPLEMENTED]` [`appmap/validate.py:44`](appmap/validate.py)
- A `code_anchor.file` that doesn't exist on disk → ERROR-severity finding (still
  exit 0). `[IMPLEMENTED]` [`appmap/validate.py:92`](appmap/validate.py)
- A `code_anchor.symbol` not found (word-boundary search) within its file → WARN.
  `[IMPLEMENTED]` [`appmap/validate.py:99`](appmap/validate.py)
- A state `screenshot` that resolves to no file (searched against the surface dir
  and configured screenshot dirs) → WARN. `[IMPLEMENTED]`
  [`appmap/validate.py:107`](appmap/validate.py)
- Dangling links (from §4) surface as ERROR-severity findings. `[IMPLEMENTED]`
  [`appmap/validate.py:143`](appmap/validate.py)
- **`validate()` never raises**, even on a deliberately broken map — the whole
  point is to observe, not block. `[IMPLEMENTED]`

## 7. The browsable rendered map

**Purpose:** `render` writes static HTML (gitignored build output) so a human can
browse the map.

- Output is an index page (searchable, with review-queue and broken-link
  banners) plus one page per surface. `[IMPLEMENTED]`
  [`appmap/render.py:234`](appmap/render.py) (`render_map`)
- Each surface page shows the surface's outgoing edges **and** its derived
  incoming backlinks, plus the body prose. `[IMPLEMENTED]`
  [`appmap/render.py:110`](appmap/render.py)
- `rendered/` is gitignored; only records and the manifest are committed.
  `[IMPLEMENTED]` [`.gitignore`](.gitignore)

## 8. Finding and bootstrapping a map

**Purpose:** the tool locates the nearest `app-map/` and provisions its single
dependency without ceremony.

- `find_map_dir` checks the cwd's `app-map/` child, then the cwd itself if it *is*
  `app-map/`, then walks up parents; returns nothing if no map is found.
  `[IMPLEMENTED]` [`appmap/config.py:42`](appmap/config.py)
- `load_config` reads `app-map.config.yaml` and fills sane defaults for absent
  keys (e.g. `source_globs` → `["**/*"]`). `[IMPLEMENTED]`
  [`appmap/config.py:57`](appmap/config.py)
- CLI commands (`init` / `validate` / `render`) exit 0 for normal work; only CLI
  misuse or a missing map exits 2. `[IMPLEMENTED]`
  [`appmap/cli.py:70`](appmap/cli.py)
- `init` scaffolds `app-map/` — always refreshing the canonical schema copy, but
  never clobbering an existing config. `[IMPLEMENTED]`
  [`appmap/cli.py:46`](appmap/cli.py)
- The `./app-map` wrapper preflights `python3` + `pyyaml`, bootstraps a local
  `.tool-venv` once, and warns (no stack trace) when dependencies are missing.
  It is the single entry the future commit hook also calls. `[IMPLEMENTED]`
  [`app-map`](app-map)

## 9. Planned automation (not yet built)

Captured here so the intent survives — none of this is wired up yet; the
`hooks/pre-commit` file is a stub that just exits 0.
[`hooks/pre-commit`](hooks/pre-commit)

- On a commit touching `app-map/**` or a surface's `code_anchor.file`, re-stamp
  that record's `last_verified` (sha + date). Today `last_verified` is only ever
  read, never written by any script. `[PLANNED]`
- When a surface's *source* changed but its *record* didn't, set
  `needs_review: true` and print a visible warning naming it. Today `needs_review`
  is only human/agent-authored and merely read by the manifest and renderer.
  `[PLANNED]`
- A thin pre-commit shim calls `./app-map` to stamp `last_verified`, drift-flag
  `needs_review`, patch the manifest, and exit 0 unconditionally. `[PLANNED]`
