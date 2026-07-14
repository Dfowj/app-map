# App Map

A living, code-grounded record of an app's **surfaces** — screens, sheets,
tabs, modals — kept accurate by an agent as a normal part of coding work, and
browsable by anyone. Devs get records anchored to real files and symbols; PMs
get a searchable index and a navigation-graph view of what the app *is* today.

Each surface is one markdown file with YAML frontmatter at
`app-map/surfaces/<id>/surface.md`: its kind, code anchor, outgoing navigation,
states, and dependencies, plus human prose. Records are the source of truth;
everything else (`manifest.yaml`, the rendered site) is derived.

**New here? Read [PRD.md](PRD.md)** — the problem, what you get as a PM /
engineer / agent, and the architecture that keeps the map trustworthy.

## Demo

Browse the rendered ShopMini sample map on
[GitHub Pages](https://dfowj.github.io/app-map/).

## Try it

```sh
cd samples/shopmini

# If you haven't built the CLI yet:
cd ../../cli && swift build -c release && cd -
mkdir -p app-map/bin
cp ../../cli/.build/release/appmap app-map/bin/appmap

./app-map/bin/appmap validate   # findings: schema, broken links, dead anchors
./app-map/bin/appmap render     # rebuild manifest.yaml + rendered/ site
open app-map/rendered/index.html
```

## Adopt it in a repo

Download the latest release from the
[Releases page](https://github.com/Dfowj/app-map/releases/latest)
and follow the included `INSTALL.md` — register the skill, optionally install
the drift-detection pre-commit hook. The `bin/appmap` binary is a universal
macOS binary; nothing to build.

## How it stays trustworthy

- **The skill encodes at the moment of change.** An agent that just modified a
  screen writes/reconciles its record from the code it's already reading.
- **`appmap validate`** reports schema violations, dangling links, and dead
  code anchors — and never blocks anything (always exit 0).
- **`appmap stamp`** (pre-commit) re-stamps `last_verified` on committed
  records and flags `needs_review` when source changes outrun the map; the
  next agent session works the review queue.
- **Three ownership tiers** keep humans in charge: mechanical fields are
  script-owned, asserted fields are agent-owned and code-grounded, and human
  prose/notes are never overwritten.

## Repo layout

| Path | What |
|---|---|
| `cli/` | SwiftPM source for `appmap` (`swift test` runs the suite) |
| `schema/surface.schema.json` | Canonical record contract |
| `skill/SKILL.md` | The agent skill |
| `install/` | Files that ship only in the dropin (INSTALL.md, hooks) |
| `script/assemble-dropin.sh` | Assembles the release tarball from canonical sources |
| `.github/workflows/release.yml` | Tag-triggered release + GitHub Pages deploy |
| `samples/shopmini/` | SwiftUI sample app + gold records (end-to-end eval) |
| `plans/` | Development plan and change history |
| `previous-iteration/` | Frozen first pass (Python engine) — reference only |

Working conventions live in [`CLAUDE.md`](CLAUDE.md); the full story and
milestones in [`plans/development-plan.md`](plans/development-plan.md).
