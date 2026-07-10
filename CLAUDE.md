# CLAUDE.md — app-map-tool

## What this repo is

The **portable App Map tool** (reusable engine) plus a **test harness** for developing and refining its output. The App Map is a "map-as-projection" of an app's surfaces (screens/sheets/tabs/…), refreshed *from* code. Full design: [`plans/app-map-tooling.md`](plans/app-map-tooling.md). Originating spec: `~/Downloads/app-map-handoff.md`.

## Load-bearing model (don't violate)

- **Map-as-projection.** The map describes *what is*, never intent. No todos/specs/wishlists in it.
- **Three ownership tiers.** Tier 1 (mechanical, script-owned, always overwritten) · Tier 2 (agent-asserted, code-grounded, reconciled) · Tier 3 (human-authored: `id`, body prose, and `note` annotations — **preserved always; agent may suggest, never overwrite**).
- **Warn, record, never block.** No tool action may gate a commit/push/deploy. Everything exits 0.
- **Records are source of truth; `rendered/` is gitignored build output.** Only records get committed, so commit diffs stay the signal the (future) hook keys on.

## Conventions

- **Plans live in `plans/`** in this repo (not in Claude's home dir). Write design/planning docs there.
- **Engine:** Python (stdlib + `pyyaml` only). No other deps — keeps "copy the folder and run" cheap. Validation is hand-rolled against `appmap/schema/surface.schema.json` (no `jsonschema`).
- **Front door is `./app-map`** (shell wrapper). It provisions deps and dispatches to `python -m appmap`. The future commit hook calls the same wrapper, not the engine directly.
- Surface record schema and tier boundaries: see `appmap/schema/surface.schema.json` and the frontmatter comments in any `samples/shopmini/app-map/surfaces/*/surface.md`.

## Dev loop

```sh
cd samples/shopmini
../../app-map validate     # drift / broken links / bad anchors — never fails
../../app-map render       # rebuild manifest.yaml + rendered/
open app-map/rendered/index.html
```

## Status / roadmap

Built: deterministic core (schema, model, backlinks, broken-link + stale-anchor checks, manifest, HTML render, shell wrapper). See README "Roadmap" for what's deferred (commit hook, agent skill, reachability analysis, incremental render, screenshot wiring). `samples/shopmini` is a real SwiftUI app to be fleshed out and used for an actual agent/skill run — spec in [`plans/shopmini-sample.md`](plans/shopmini-sample.md).
