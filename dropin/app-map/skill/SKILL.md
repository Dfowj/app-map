---
name: app-map
description: Maintain the App Map for this repo. Invoke after creating or modifying a screen, sheet, tab, modal, or popover — or when asked to map the app's surfaces. Encodes what each surface *is* (kind, code anchor, navigation, states, dependencies) into app-map/surfaces/<id>/surface.md per the schema.
---

# App Map skill

You maintain a map of this app's **surfaces** — its screens, sheets, tabs, modals —
as records under `app-map/surfaces/<id>/surface.md`. The map is **descriptive,
not declarative**: code is the source of truth, and the map records what it *is* —
never what anyone wants it to become.

You have two inputs no script has: the **code** you are reading anyway, and the
**context of the current task** — what is being built and why. Ground every
structural claim in the code; use the task context to write prose a human would
have written.

## When to act

- You created a new surface → create its record.
- You modified an existing surface (navigation, states, dependencies, moved its
  file) → reconcile its record.
- You were asked to map surfaces directly → encode each one.

Do this as part of finishing the task, like updating a test.

## What is (and isn't) a surface

A surface is a full-screen experience or a navigational container hosting them:
a pushed screen, a tab root, the tab bar itself, a sheet, a modal, a popover.

**Not** surfaces: alerts, toasts, banners, inline errors. A variant of one screen
(Cart empty vs. filled) is a **state** inside that surface's record, not a new
surface.

## Writing a record

The frontmatter shape and per-field ownership live in
`app-map/schema/surface.schema.json`. **Read it before writing** — it is the
contract, this file is only the guide.

1. **Identity.** New surfaces get a kebab-case `id` (e.g. `product-detail`).
   The `id` is immutable once created — never rename an existing one.
2. **Kind.** One of `screen | tab-root | tab-bar | sheet | modal | popover |
   container`.
3. **Code anchor.** The one file + symbol that best *is* this surface (usually
   the SwiftUI view type).
4. **Relationships — three distinct types, never conflated:**
   - `edges`: **outgoing** navigation only (push, present, tab-switch,
     deep-link). Incoming is derived later; never write it. Each edge gets a
     stable `id` slugged from its trigger (`"Tap 'Checkout'"` → `checkout-cta`).
     A mutation is not an edge — "Add to Cart" changes state, it doesn't
     navigate.
   - `contains`: structural nesting (the tab-bar contains its tab roots).
     Tapping a tab is a switch, not a push — modeling containment as edges
     corrupts the graph.
   - `entry_points`: ways in from **outside** the app graph — deep links, push
     notifications, widgets.
5. **States.** Named variants of this surface (`default`, `empty`, …), with
   screenshot paths if known.
6. **Dependencies.** Notable external deps (Stripe — not internal packages) and
   data deps (models, fetches), scoped to what this surface actually touches.
7. **Body prose — new records only.** Below the frontmatter, draft a
   `## Description` from the task context: what the surface is for, in a
   sentence or two of current-state fact. This is the one moment you may write
   prose, because no human has yet.

## Finding your way around

`app-map/manifest.yaml` is the derived fast index — every surface's id, title,
kind, record path, and `needs_review` flag, plus the map-wide `review_queue`
and `link_health`. Read it to find existing surfaces instead of globbing
`surfaces/`. It is tier-1 output: never edit it by hand; it's rebuilt by
`appmap render`.

## Reconciling an existing record

Update only what the code contradicts, keyed by stable identity: edges by `id`,
states by `name`, entry points by `type`+`value`, data deps by `name`.

**Never modify or delete tier-3 content:** the `id`, all body prose, and any
existing `note` on an edge/state/entry point/dep. Existing notes are human
property — preserve them verbatim. If a `note`-bearing item no longer exists in
code, don't silently delete it — set `needs_review: true` on the record and say
why in your response, so a human decides.

You **may add** a `note` to a field that lacks one — on new *and* existing
records — when the code grounds an observation worth recording (an enablement
condition, a pagination rule, a client-side filter). Add only; never overwrite
what's already there.

Want to change existing human prose or notes? Propose the text in your response
to the user. Never rewrite it in place.

## Boundaries

- **Descriptive, not declarative.** No todos, intentions, or planned work in any
  record.
- **Preserve tier 3, always.** Never overwrite or delete existing prose or
  notes — they're human property. You may *add* a code-grounded note where none
  exists.
- **Warn, record, never block.** Flag problems (`needs_review`, or in your
  response); never let map work gate the actual task.
- **Outgoing only.** Incoming edges and the manifest are derived — never
  hand-write them.

## Checking your work

After writing or reconciling records:

```sh
app-map/bin/appmap validate   # findings: schema, broken links, dead anchors
app-map/bin/appmap render     # rebuild manifest.yaml + rendered/ site
```

`validate` reports schema violations, dangling `edge.to` / `contains` /
`entry_point.to` targets, missing anchor files, vanished symbols, and
unresolved screenshots. Resolve every finding you caused; findings you didn't
cause (pre-existing warnings), leave and mention in your response. It never
blocks — severity ranks attention, and it always exits 0.

`render` keeps the derived index and the human-browsable site in sync with the
records you touched. Commit `manifest.yaml`; `rendered/` is gitignored.
