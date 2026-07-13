# Change history

Newest first. One paragraph per entry: what changed and why.

## 2026-07-13 — PRD.md: user-first product & architecture doc

Wrote a root `PRD.md` explaining the project to newcomers, organized the same
way this iteration reorganized the work: the user problem and what each
audience gets (PM browsing, engineer code-anchoring, agent fast-index) up
front, the day-to-day loop next, and mechanics (tiers, data model, CLI
implementation, parent-sha stamping rationale, non-goals) as the afterthought.
Linked from the README. Also settled a design question: `last_verified.sha`
stays, recording the parent commit — conservative diff base plus the staleness
signal humans actually need; the imprecision only over-reports.

## 2026-07-13 — Milestone 4: the map notices drift (`appmap stamp`)

`appmap stamp` (run by the new `hooks/pre-commit` shim in the drop-in) applies
the drift rules to the staged file set: records staged in the commit get
`last_verified` re-stamped (short HEAD sha + date — the commit the record was
verified on top of); a surface whose `code_anchor.file` is staged without its
record gets `needs_review: true` and a visible warning; the manifest is
rebuilt so `review_queue` reflects the flags; everything stamp modifies is
`git add`ed into the same commit. Exit 0 unconditionally. Records are patched
line-surgically — only the two tier-1 lines change, so hand-authored YAML
formatting and tier-3 bodies survive byte-for-byte (11 new tests, 52 total).
Skill gained a "Working the review queue" section. Exit criteria ran as a
scripted scenario in a hermetic git copy of shopmini: source-only commit set
the flag via the hook, the reconcile commit drained the queue and stamped
`last_verified`, tier-3 prose and flow-style YAML intact throughout.

## 2026-07-13 — Milestone 3: a human can browse the map (`appmap render`)

`appmap render` rebuilds `manifest.yaml` wholesale (id-sorted, no volatile
fields, hand-rolled deterministic YAML emitter — the regenerated shopmini
manifest is byte-identical to the committed gold one) and emits a static site
to `rendered/`: a searchable index with per-surface description snippets and
in/out edge counts, one page per surface (prose first, then contains /
contained-by / outgoing / derived-incoming / entry points / states /
dependencies), and — beyond the plan, for the PM audience — a `map.html`
navigation-graph overview: deterministic BFS-layered SVG from the launch
surface, kind-colored nodes linking to surface pages, dashed containment vs.
arrowed navigation, hover tooltips with triggers. All pages are self-contained
(inline CSS/JS, dark-mode aware). Backlinks are derived at render time only.
Skill now reads `manifest.yaml` as the fast index and runs `render` after
record changes; 14 new unit tests (41 total).

## 2026-07-12 — Milestone 2: the agent can check its work (`appmap validate`)

First Swift code: `cli/` SwiftPM package (`swift-argument-parser` + `Yams`)
producing the `appmap` universal binary, committed at `dropin/app-map/bin/` and
symlinked into `samples/shopmini/app-map/bin/`. Ported the previous iteration's
semantics (not code): frontmatter/body split with the body — and now the raw
frontmatter text — preserved verbatim as the foundation for later write paths,
plus `validate` covering schema subset checks (required/type/enum/pattern),
dangling edge/contains/entry-point targets, missing anchor files, word-bounded
symbol search, and unresolved screenshots. Always exits 0 except CLI misuse.
27 unit tests ported/extended from `previous-iteration/tests/`. Exit criteria:
gold shopmini validates with zero errors (two documented screenshot warns), a
deliberately broken map yields the expected findings and still exits 0. Skill's
"Checking your work" now points at the validator.

## 2026-07-11 — Milestone 1: agent encodes a screen

Built the `dropin/app-map/` drop-in template (`INSTALL.md` + skill + schema) and
validated the app-map skill against `samples/shopmini/`. Both exit criteria
passed: a fresh encode from source reproduced all 7 gold surfaces' tier-2
structure (kinds, anchors, edges, containment, deps), and a reconcile against a
simulated code change touched only the contradicted tier-2 field while every
tier-3 note and body section survived. Tightened the gold `cart` record and the
sample spec to drop an aspirational (non-code-grounded) push-notification entry
point, reinforcing the "entry points must be code-grounded" rule. Refined the
skill's tier-3 boundary: the agent may *add* a code-grounded `note` to a field
lacking one on new *and* existing records, but must never overwrite or delete an
existing note.
