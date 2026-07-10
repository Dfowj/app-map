---
name: app-map
description: STUB — not built yet. Will maintain the App Map (surfaces, edges, states, deps) for the current app by asserting tier-2 code-grounded fields and working the review queue.
---

# App Map skill — STUB (handoff §7C)

**This skill is not implemented yet.** It is the last and most iterative piece,
deferred until the deterministic core has settled (it did, this pass). This file
is a placeholder capturing intended responsibilities so a later session can build
it against the existing engine.

## Why the engine comes first

The skill only *supplies values*; the engine (`../app-map`) owns all mechanics —
manifest regen, backlink derivation, validation, the keyed merge. The skill reads
the derived `manifest.yaml` as its fast index and writes tier-2 fields into
`surfaces/<id>/surface.md`.

## Planned responsibilities (agentic tier-2 + tier-3 suggestions)

- On a code change affecting a surface, update tier-2 fields (kind, code_anchor,
  edges, contains, entry_points, states, dependencies) and let the engine merge —
  **preserving tier-3 `note`s and body prose**.
- Decide whether an edge exists / changed / was removed (SwiftUI nav can't be
  reliably derived statically — assert from code understanding, don't parse).
- Work the `review_queue` from `manifest.yaml`: inspect changed source, reconcile
  the record, clear `needs_review` (or leave it flagged with a reason).
- Scaffold new surface records (prompt human for `id` + tier-3 prose, or leave
  placeholders).
- **Suggest** tier-3 content (Description/Goal/KPIs/Notes) as proposals — never
  overwrite existing human prose.
- Assign edge `id` slugs from the trigger; keep them stable once a `note` is
  attached.

## Boundaries (do not violate)

- Never overwrite tier-3: body prose, `id`, and `note` annotations.
- Map-as-projection: describe what the code *is*, never author intent.
- Warn, record, never block.

## Test target

`samples/shopmini/` — regenerate its map from code and diff against the committed
hand-authored gold records (`samples/shopmini/app-map/surfaces/`). See
`plans/shopmini-sample.md`.
