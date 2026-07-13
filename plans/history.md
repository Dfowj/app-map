# Change history

Newest first. One paragraph per entry: what changed and why.

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
