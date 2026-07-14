# CLAUDE.md

Working instructions for this repo. Read alongside
[`plans/development-plan.md`](plans/development-plan.md) (the milestone-by-
milestone plan and the full story).

## What this project is

App Map: a living, code-grounded record of an app's **surfaces** (screens,
sheets, tabs, modals). Each surface is a markdown file with YAML frontmatter at
`app-map/surfaces/<id>/surface.md`, conforming to `schema/surface.schema.json`.
An agent skill maintains the map as a normal part of coding work; CLI tooling is
built after, one command at a time, each justified by a real need.

## Directional decisions

- **Agent-first, tools-after.** The skill is the product; each CLI command is
  added only when the agent (or its human) actually hits the need. This is a
  deliberate reversal of the previous iteration (frozen under
  `previous-iteration/` — reference it, don't extend it).
- **Swift CLI, no runtime deps.** `appmap` is a compiled universal binary built
  from `cli/` (SwiftPM: `swift-argument-parser` + `Yams`), published as a
  GitHub Release tarball (assembled by `script/assemble-dropin.sh`). Consuming
  repos never build anything. Commands: `validate` (findings, never fails),
  `render` (manifest + static site), `stamp` (drift detection, run by
  `hooks/pre-commit`).
- **Scrappy distribution.** Tool + data ship as one dropped-in `app-map/` folder
  (assembled by `script/assemble-dropin.sh`, published on tag push as a GitHub
  Release). Copy-and-run over packaging elegance.
- **Invariants (don't violate):**
  - *Descriptive, not declarative* — code is the source of truth; the map
    records what a surface *is*, never intentions or wishlists.
  - *Three ownership tiers* — T1 mechanical (script-owned) · T2 asserted
    (agent-owned, code-grounded) · T3 authored (human-owned: `id`, body prose,
    `note`s — never overwritten/deleted; agent may *add* a grounded note).
  - *Warn, record, never block* — no tool gates a commit/push/deploy.
  - *Records are source of truth; rendered output is gitignored.*
- **`samples/shopmini/`** (SwiftUI app + hand-authored "gold" records) is the
  end-to-end eval target for every milestone: run the skill, diff against gold.

## Working conventions

- **Plans live in `plans/`.** Schema changes are deliberate: update
  `schema/surface.schema.json` and the gold records together.
- **Dev loop for `cli/`:** edit → `swift test` (in `cli/`) → sanity-run the
  sample (`cd samples/shopmini && ./app-map/bin/appmap validate` and `render`).
  To publish: tag (`git tag v0.X.0 && git push --tags`) and the release
  workflow builds + publishes the dropin tarball.
- **Log every change** in [`plans/history.md`](plans/history.md) — newest first,
  one paragraph max, summarizing what changed and the motivation.
- **Record future work** in [`TODOS.md`](TODOS.md) — when a task or nice-to-have
  is identified but out of scope, add it there rather than losing it. (Larger
  milestone-adjacent items go in the plan's "Parked" section.)
