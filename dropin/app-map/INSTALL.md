# Installing the App Map

The App Map is a living, code-grounded record of your app's **surfaces** —
screens, sheets, tabs, modals. It lives in this `app-map/` folder and is
maintained by an agent skill as a normal part of coding work.

## Install

1. **Copy this folder** into the root of your repo, committed as `app-map/`.

2. **Register the skill** so your agent can find it. Either symlink or copy the
   skill into your Claude skills directory:

   ```sh
   ln -s "$(pwd)/app-map/skill" .claude/skills/app-map
   # or, to copy instead of symlink:
   # cp -R app-map/skill .claude/skills/app-map
   ```

3. **(Optional, recommended) Install the drift hook** so the map notices when
   source changes outrun their records:

   ```sh
   ln -sf ../../app-map/hooks/pre-commit .git/hooks/pre-commit
   ```

   The hook never blocks a commit — it re-stamps `last_verified` on committed
   records, flags drifted surfaces `needs_review`, and updates the manifest,
   staging its edits into your commit.

4. **Done.** There's nothing to build. The agent reads
   `app-map/schema/surface.schema.json` and conforms to it directly.

## What's in here

```
app-map/
  INSTALL.md                    # this file
  skill/SKILL.md                # the agent skill (register in step 2)
  schema/surface.schema.json    # the record contract
  bin/appmap                    # committed CLI (universal macOS binary)
  hooks/pre-commit              # drift-detection shim (install in step 3)
  surfaces/<id>/surface.md      # the map data — grows as the app is mapped
  manifest.yaml                 # derived index (committed, regenerated)
  rendered/                     # derived static site (gitignore this)
```

The `bin/appmap` CLI is a compiled universal binary (arm64 + x86_64) with no
runtime dependencies — nothing to build or install. Current commands:

```sh
app-map/bin/appmap validate    # schema violations, broken links, dead anchors
app-map/bin/appmap render      # rebuild manifest.yaml + rendered/ static site
app-map/bin/appmap stamp       # drift detection (what the pre-commit hook runs)
```

`render` emits a browsable site into `rendered/`: a searchable surface index,
a navigation-graph overview, and one page per surface (outgoing + derived
incoming edges, states with screenshots, prose). Open
`app-map/rendered/index.html` in a browser. Add `app-map/rendered/` to your
`.gitignore` — records and manifest are the committed source of truth.

`stamp` records `last_verified` as the short sha of the commit each record was
verified on top of, plus the date. Every command **warns, records, never
blocks** — exit 0 always, except on CLI misuse.

## How it works

The map is **descriptive, not declarative**: code is the source of truth, and
each record describes what a surface *is* today — its kind, its code anchor,
where it navigates, its states and dependencies. The agent invokes the skill
after creating or changing a surface, grounding every claim in the code it's
already reading.

Records are the source of truth. Human-authored prose and `note` annotations
are preserved across every automated update.
