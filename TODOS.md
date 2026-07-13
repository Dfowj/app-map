# TODOs / nice-to-haves

Future tasks and improvements surfaced during sessions but out of scope at the
time. The plan's "Parked" section holds larger milestone-adjacent items; this is
for smaller, looser threads.

- [x] Regenerate `samples/shopmini/app-map/rendered/` once `appmap render`
  exists (Milestone 3) — the committed HTML is stale previous-iteration output
  and still references the removed abandoned-cart push entry point.
  *(Done 2026-07-13: the stale HTML was on disk but never tracked; `appmap
  render` now regenerates it, and `rendered/` stays gitignored.)*
- [ ] Linux binary for `bin/appmap` — the committed universal binary is
  macOS-only; CI or Linux devs would need a build from `cli/`.
- [ ] Graph page edge labels: triggers are hover-only tooltips today; consider
  optional inline labels once maps get bigger and hover discovery falls short.

## Future directions — from topology to semantics

The map records *structure* today; the questions users actually ask are often
*behavioral* ("does home still hit the legacy feed?", "when is the offer
button enabled?"). Ordered by leverage; items marked *(schema)* are deliberate
schema changes — update `schema/surface.schema.json`, the `dropin/` copy, and
the gold records together.

- [x] **Watch lists** *(schema)* — tier-2 `watches: [file...]` on a record,
  feeding `appmap stamp` alongside `code_anchor.file`. Fixes a real drift
  blind spot: enablement/data logic usually lives in a viewmodel or service,
  and today a change there (e.g. `CartViewModel.swift` only) never flags the
  surface. Prerequisite for trustworthy conditions/dependencies below.
  *(Done 2026-07-13: schema + gold cart record + stamp/validate/render/skill;
  vanished watch files are error-level validate findings.)*
- [ ] **Grounded conditions** *(schema)* — first-class `enabled_when` / `when`
  on edges and states: prose condition + grounding symbol, symbol verified by
  `validate` like anchor symbols, rendered prominently on the surface page.
  Formalizes what the cart `checkout-cta` note does informally; makes "when is
  this button enabled?" a lookup.
- [ ] **Grounded dependencies** *(schema)* — optional grounding (symbol/file)
  on `dependencies.data` entries, verified at validate and watched at stamp,
  so "still fetching the legacy feed?" is answered by a record mechanically
  tied to code rather than by an unverifiable claim.
- [ ] **"Ask the map" skill workflow** — a SKILL.md section for answering
  questions: manifest → record → verify against the anchored code before
  answering → cite the anchor; reconcile the record if it proves stale while
  answering. Q&A sessions become maintenance sessions. No new tooling.
- [ ] **Per-surface timeline** — derive a change log per surface at render
  time from the record's git history (which commit changed the dependency,
  and when). Derived and deterministic given the repo state.
- [ ] **Gold Q&A evals** — add question/answer pairs to the shopmini spec
  ("when is checkout enabled?") and eval the skill against them, extending the
  eval from "encodes correctly" to "answers correctly."
