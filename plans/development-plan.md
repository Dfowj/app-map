# App Map — Development Plan

## The story

An agent is deep in a coding task: it just reworked ShopMini's cart screen to add a
promo-code field. It already holds everything needed to document that screen — the
code it just read and wrote, and the conversation context explaining *why* the
change exists. The app-map skill turns that moment into a record: a small markdown
file at `app-map/surfaces/cart/surface.md` describing what the Cart surface *is* —
its kind, its code anchor, where it navigates, its states and dependencies —
conforming to a shared schema.

Do that for every surface and you have the App Map: a navigable, living document of
the app, readable by humans and searchable by agents. Everything else in this plan —
the CLI tools, the rendering, the drift detection — exists to serve that encoding
moment and keep its output trustworthy over time.

**This plan builds the agent first.** Tools come after, one at a time, each
justified by a concrete need the agent (or its human) actually hit. This is the
reverse of the previous iteration, which built a deterministic Python engine first
and deferred the agent indefinitely (see `previous-iteration/`).

## What carries over from the previous iteration

- **The schema.** `schema/surface.schema.json` is the canonical copy, unchanged.
  Surface records are markdown files with YAML frontmatter; the schema defines the
  frontmatter shape and per-field tier ownership.
- **The sample repo.** `samples/shopmini/` — a small real SwiftUI shopping app plus
  hand-authored "gold" surface records under its `app-map/`. Spec:
  [`plans/shopmini-sample.md`](shopmini-sample.md). It is the eval target for every
  milestone: run the skill, diff against gold.
- **The invariants.** These survived the reset because they're about the map, not
  the tooling:
  - **Descriptive, not declarative.** Code is the source of truth; the map only
    describes what it *is*. No todos, specs, or wishlists.
  - **Three ownership tiers.** Tier 1 mechanical (script-owned, always
    overwritten) · Tier 2 asserted (agent-owned, code-grounded, reconciled) ·
    Tier 3 authored (human-owned: `id`, body prose, `note` annotations — preserved
    always).
  - **Warn, record, never block.** No tool may gate a commit, push, or deploy.
  - **Records are source of truth; rendered output is gitignored.**
- **The vocabulary.** Surface / state / kind, and the three distinct relationship
  types: edges (navigation), containment (structural nesting), entry points
  (external ways in). Defined in [`app-map-handoff.md`](../app-map-handoff.md) §2.

## What changed

| Previous iteration | This iteration |
|---|---|
| Python engine (`stdlib + pyyaml`), shell wrapper, venv bootstrap | Compiled Swift CLI (`swift-argument-parser` + `Yams`), no runtime deps |
| Engine built first; agent skill a stub | Agent skill built first; each tool built when the agent needs it |
| PRD organized around data/invariants/determinism | Plan organized around the user story, milestone by milestone |

## Distribution model (scrappy, on purpose)

A consuming repo gets one folder, dropped in and committed:

```
app-map/
  INSTALL.md               # ~3 steps: copy folder, register skill, done
  skill/SKILL.md           # copied (or symlinked) into .claude/skills/app-map/
  schema/surface.schema.json
  bin/appmap               # committed universal binary (exists from milestone 2 on)
  surfaces/<id>/surface.md # the map data, grows in place
  manifest.yaml            # derived index (milestone 3)
  rendered/                # gitignored (milestone 3)
```

Tool + data live in one folder. That's deliberate: copy-and-run beats packaging
elegance at this stage. The binary is compiled in *this* repo and copied into the
drop-in; consuming repos never build anything. Splitting tool from data, or moving
to a real install story, is a later problem — revisit if the binary churn in git
gets annoying.

In this repo, the drop-in template lives at `dropin/app-map/` (created in
milestone 1), and the Swift package that produces `bin/appmap` lives at `cli/`
(created in milestone 2).

## Milestones

Each milestone opens with the story that motivates it, ships something usable, and
ends with a check against `samples/shopmini/`.

### Milestone 1 — An agent encodes a screen

> While working on a ShopMini task that touches CartView, the agent invokes the
> app-map skill and produces `app-map/surfaces/cart/surface.md`: schema-conformant
> frontmatter grounded in the code, plus an initial Description drawn from the
> task's context.

The skill is the whole product here. No CLI, no validation tooling — the agent
reads `schema/surface.schema.json` directly and conforms by understanding it.

Build:
- `skill/SKILL.md` — rewritten from the old stub ([draft exists](../skill/SKILL.md)).
  Covers: when to fire, how to identify a surface and its kind, which fields it
  owns (tier 2), how it uses conversation context (drafting prose on *new* records
  only), and the boundaries it must not cross.
- `dropin/app-map/` template folder with `INSTALL.md`, skill, schema.

Exit criteria:
- Fresh-encode test: point the skill at ShopMini screens with the gold records
  hidden; diff its output against `samples/shopmini/app-map/surfaces/`. Judged on
  substance (right surfaces, right kinds, right edges, sane ids), not
  byte-equality.
- Update test: make a code change to one ShopMini screen mid-task, let the skill
  reconcile the existing record; tier-3 content survives untouched.

### Milestone 2 — The agent can check its work (`appmap validate`)

> The agent (or a human) has just written or reconciled records and wants a
> machine answer to "is the map internally sound?" — schema violations, edges
> pointing at surfaces that don't exist, code anchors whose file or symbol
> vanished.

First Swift code. This is where milestone 1's honor-system conformance gets teeth.

Build:
- `cli/` SwiftPM package → `appmap` executable. Deps: `swift-argument-parser`,
  `Yams`. Universal binary (arm64 + x86_64) copied into `dropin/app-map/bin/`.
- Record reading: frontmatter split from body, body preserved byte-for-byte —
  the foundation every later write path shares.
- `appmap validate`: schema check (required/type/enum/pattern), dangling
  `edge.to` / `contains` / `entry_point.to`, missing `code_anchor.file`, absent
  `code_anchor.symbol` (word-boundary search), unresolved state screenshots.
  Severity ranks attention only; **always exits 0** except on CLI misuse.
- Skill updated: "after writing a record, run `bin/appmap validate` and resolve
  findings."

The previous iteration's Python engine and its unit tests
(`previous-iteration/appmap/`, `previous-iteration/tests/`) are the behavioral
reference — port the semantics and the test cases, not the code.

Exit criteria: validate runs green on the gold shopmini map; a deliberately broken
map (dangling edge, dead anchor) yields the expected findings and still exits 0.

### Milestone 3 — A human can browse the map (`appmap render`)

> A teammate who has never read YAML wants to answer "what does Cart connect to,
> and what does it look like when it's empty?" in a browser.

Build:
- Backlink derivation: invert every outgoing `edge.to` into incoming links at
  render time (incoming is never stored).
- `appmap render`: rebuilds `manifest.yaml` wholesale (id-sorted, no volatile
  fields — a re-render on unchanged records is byte-identical) and emits a static
  site to `rendered/`: searchable index + one page per surface showing outgoing
  edges, derived incoming, states with screenshots when they resolve, and body
  prose.
- Skill updated: read `manifest.yaml` as the fast index instead of globbing
  surfaces.

Exit criteria: render the gold shopmini map; manifest matches the committed one
from the previous iteration in substance; pages are readable and complete.

### Milestone 4 — The map notices drift

> A surface's source file changed in a commit but its record didn't. Nobody blocks
> the commit — the map flags the surface for review and the next agent session
> works the queue.

Build:
- `appmap stamp` (or hook subcommand): re-stamp `last_verified` (sha + date) on
  changed records; set `needs_review: true` when a `code_anchor.file` changed but
  its record didn't; patch the manifest. Exit 0 unconditionally.
- Thin pre-commit shim in the drop-in that calls `bin/appmap`.
- Skill updated: work `review_queue` from the manifest — inspect changed source,
  reconcile tier 2, clear `needs_review` or leave it flagged with a reason.

Exit criteria: scripted scenario in shopmini — touch `CartView.swift` without
touching its record, commit, observe the flag; run the skill, observe the queue
drain.

### Parked (build when a milestone actually needs them)

- Reachability / orphan / dead-end analysis (`graph_health` beyond dangling links)
- Screenshot capture wired to snapshot-test output paths
- Incremental render / manifest patching (wholesale rebuild is fine at this scale)
- `appmap init` scaffolding (the drop-in folder *is* init, for now)
- Keyed-merge reconcile as a CLI primitive (in milestones 1–4 the agent performs
  the merge itself, honoring tier boundaries; mechanize if it proves error-prone)

## Development conventions

- Plans live in `plans/`. The previous iteration is frozen under
  `previous-iteration/` — reference it, don't extend it.
- The Swift CLI gets unit tests from milestone 2 on (`swift test` in `cli/`);
  shopmini remains the end-to-end check for every milestone.
- Schema changes are allowed but deliberate: update `schema/surface.schema.json`,
  the drop-in copy, and the gold records together.
