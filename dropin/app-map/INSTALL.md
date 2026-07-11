# Installing the App Map

The App Map is a living, code-grounded record of your app's **surfaces** —
screens, sheets, tabs, modals. It lives in this `app-map/` folder and is
maintained by an agent skill as a normal part of coding work.

## Install (3 steps)

1. **Copy this folder** into the root of your repo, committed as `app-map/`.

2. **Register the skill** so your agent can find it. Either symlink or copy the
   skill into your Claude skills directory:

   ```sh
   ln -s "$(pwd)/app-map/skill" .claude/skills/app-map
   # or, to copy instead of symlink:
   # cp -R app-map/skill .claude/skills/app-map
   ```

3. **Done.** There's nothing to build. The agent reads
   `app-map/schema/surface.schema.json` and conforms to it directly.

## What's in here

```
app-map/
  INSTALL.md                    # this file
  skill/SKILL.md                # the agent skill (register in step 2)
  schema/surface.schema.json    # the record contract
  surfaces/<id>/surface.md      # the map data — grows as the app is mapped
```

Later milestones add a committed `bin/appmap` CLI (validate, render, drift
stamping) and derived `manifest.yaml` / gitignored `rendered/`. None of that
exists yet — at this stage the skill and schema are the whole product.

## How it works

The map is **descriptive, not declarative**: code is the source of truth, and
each record describes what a surface *is* today — its kind, its code anchor,
where it navigates, its states and dependencies. The agent invokes the skill
after creating or changing a surface, grounding every claim in the code it's
already reading.

Records are the source of truth. Human-authored prose and `note` annotations
are preserved across every automated update.
