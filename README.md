# App Map Tool

A navigable, living document of every **surface** in an app — its behavior, dependencies, states, and navigation. It serves two audiences: humans reading current-state documentation, and agents using it as a searchable context index for the codebase.

This repo holds the **portable tool** (the reusable engine you carry to new projects) plus a **test harness** (`samples/shopmini/`) for developing and refining output in place.

See [`plans/app-map-tooling.md`](plans/app-map-tooling.md) for the design and [`~/Downloads/app-map-handoff.md`] for the originating spec.

## The one idea

The map **describes what is** — the current state of the codebase. It is refreshed *from* code; it is not a place to author intent. Every field has exactly one owner across three tiers:

| Tier | Owner | On recompute |
|---|---|---|
| **1 — Mechanical** | Script | Always overwritten |
| **2 — Asserted, code-grounded** | Agent (hook-validated) | Refreshed on code change; reconciled |
| **3 — Authored** | Human | Preserved always (agent may *suggest*, never overwrite) |

Operating philosophy: **warn, record, never block.** Nothing this tool does may gate a commit, push, or deploy.

## Quick start

```sh
# From a target project's map directory:
cd samples/shopmini
../../app-map validate      # report drift / broken links / bad anchors (never fails)
../../app-map render        # rebuild manifest.yaml + rendered/ HTML
open app-map/rendered/index.html
```

The `app-map` wrapper preflights dependencies (`python3` + `pyyaml`), bootstrapping a local `.venv` on first run, then dispatches to the Python engine in `appmap/`.

## Porting to a new project

The reusable unit is this repo's tool root (`app-map` + `appmap/` + later `skill/` + `hooks/`). To adopt it elsewhere:

```sh
cp -R /path/to/app-map-tool /path/to/other-project/.app-map-tool   # copy the folder
cd /path/to/other-project
./.app-map-tool/app-map init        # scaffold ./app-map/ (config, schema, empty surfaces/)
# ...author surface records, then:
./.app-map-tool/app-map render
```

## Layout

```
app-map          # shell front door (dep preflight + dispatch)
appmap/          # Python engine (stdlib + pyyaml)
skill/           # agent skill (STUB — see roadmap)
hooks/           # commit hook (STUB — see roadmap)
samples/shopmini # real SwiftUI sample app + its generated map (test harness)
plans/           # in-project planning docs
```

## Roadmap

Built (deterministic core):
- [x] Surface schema + folder-per-surface records
- [x] Wholesale render: manifest + per-surface HTML + searchable index
- [x] Backlinks (incoming-edge inversion) + broken-link / stale-anchor detection
- [x] `app-map` shell wrapper with dependency preflight

Deferred (next iterations):
- [ ] Commit hook — stamp `last_verified`, drift-flag `needs_review`, patch manifest, exit 0 ([`hooks/pre-commit`](hooks/pre-commit))
- [ ] Agent skill — tier-2 assertions, review-queue work, tier-3 suggestions ([`skill/SKILL.md`](skill/SKILL.md))
- [ ] Reachability analysis (orphans, dead-ends, unreachable-from-launch)
- [ ] Incremental render mode; snapshot-test screenshot wiring; edge-`id` auto-slug
