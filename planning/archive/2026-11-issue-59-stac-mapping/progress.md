# Progress — The STAC mapping has no implementation and no vectors (#59), with #60

## Session 2026-11-10

- Plan-mode exploration; phases approved by the user, with the `crt_receipt_write()` return decided
  at the gate (it returns the digest)
- Created branch `59-the-stac-mapping-has-no-implementation-a` off origin/main (857418b; two
  housekeeping commits landed during the gate, nothing receipt-related)
- Scaffolded PWF baseline from issues #59 and #60 with the approved phases
- Next: start Phase 1
- Phase 1: tests first. `test-crt_receipt_stac.R` (7 blocks, all erroring: no function yet); the
  write tests read the receipt back from the file and pin the returned digest (fails as expected);
  compare tests that exercised the in-memory receipt now build it with `receipt_build()`
- Phase 2: `crt_receipt_write()` returns the SHA-256 of the bytes it wrote (hashed from the temp
  file before the rename), invisibly. Callers moved: the vignette, `data-raw/receipt_examples.R`,
  the roxygen example. `crt_receipt_migrate(path =)` still returns the receipt (not in scope)
- Phase 3: `crt_receipt_stac()` in `R/crt_receipt_stac.R`; all 40 expectations of
  `test-crt_receipt_stac.R` pass; example runs; `check_pkgdown()` clean. **Plan correction:** it does
  not call `crt_receipt_validate()` first, because that needs jsonvalidate (Suggests, pulls V8), and
  a catalogue builder should not need it. It checks each field it publishes instead, as stacs does
- Plan review (Plan agent, spawned 16:04Z) delivered during Phase 4: `review-plan.md`. Blockers 1-2
  were already resolved in Phase 3. Folded in so far: a neutral `error` code in `stac.json`
  (runners check "refused" only), `as.list(assets)` / `I()` extensions / `{}` for an empty object,
  the `assets.*` rows' notes exclude the receipt asset, ordering (mapping.csv, then the bump, then
  the vectors), the CHANGELOG rules, and acceptance 12 (an item built from each case passes the
  published field schema). Still to do: 4 (stale v1.0.0 mentions), 6 (crosscheck modes), 7 (stale
  comments), 11 (stacs's `version` type check)
- Phase 4: mapping v1.1.0 (installed and published copies), `stac.json` (13 cases, 5 refusals) and
  its README, `receipt_mapping_version()` 1.1.0, a CHANGELOG entry, a runner and byte pins.
  Regenerating all vectors left every released file byte-identical. `crt_receipt_migrate()` on
  both legacy examples gives identical canonical JSON under v1.0.0 (a worktree of main) and v1.1.0
- Phase 5: the crosscheck recomputes `stac.json` independently (0 mismatches; planted mismatches
  caught); mutation shows the R runner guards omit-on-null and the unmatched-asset error; stacs
  agrees on 11 of 13 cases, and the 2 divergences are in findings for the stacs issue
- Phase 6 docs: the vignette's "STAC items" section (renders; shows a migrated item without
  `receipt:recipe_id`), the test-vector section names `stac.json`, and the stale mapping v1.0.0
  mentions (review item 4: migrate roxygen, vignette, the STAC README, research) and the stale
  comments (item 7, `crt_receipt_compare.R`) are fixed. The research file gains its provenance line
  and drops `crt_receipt_stac()` from "Not in v1". CLAUDE.md names the function and `stac.json`
- Phase 6 issues: filed knowledge#188 (move off `crt_receipt_write()`'s old return value; its
  exported writers' examples break on the next crate install from main until it lands), and
  extended stacs#15's body and title: vendor mapping v1.1.0, run `stac.json`, and fix the two
  divergences and the `version` type check
- `/code-check branch` round 1 (spawned 16:26Z): one finding, real (vectors could not reach a
  malformed field value; Python `$` accepts a trailing newline). Fixed: 6 new `stac.json` cases (19),
  the crosscheck checks what it publishes, README lists the codes, pin updated, stacs#15 updated
- `/code-check branch` round 2 (spawned 16:51Z): three findings, one inside round 1's fix (a
  version case whose `recipe_id` no longer matched). Fixed, and since a fix had been found wanting,
  ended the class by enumerating every value `crt_receipt_stac()` reads (16, both readings) against
  its guard, the form schema and the pinned classes: findings.md. `stac.json` is 46 cases (37
  refusals); stacs agrees on 31 and stacs#15 lists the 15
- `/code-check branch` round 3 (spawned 17:01Z): seven findings, two inside round 2's fix (the
  no-time case was an invalid receipt pinned as valid; the Python reading let a null receipt
  through). Mechanism, per the reviewer: both readings mirrored the schema's types but not its
  `required`, its migrated `if`, null versus absent, or the keys that are published, and the R runner
  accepted any error. Fixed: `recipe_id` refused when missing unless migrated and when set on a
  migrated receipt; `context.time` required; a present `null` block refused; an empty repository
  name and `receipt_asset` refused; R's refusal reason pinned per code; the README states what a
  reading checks (published values and keys, and what decides them) and that duplicate keys are
  outside the contract (I-JSON). `stac.json` is 61 cases
- Mutation over round 3's guards: all seven red (two first-try mutants were mangled by a `|`
  delimiter meeting `||` in the code, and rerun). Enumeration revised in findings.md
- `/code-check branch` round 4 (spawned 17:13Z, the fifth reviewer on this task): seven findings.
  Mechanism: the round-3 enumeration was read off the readings' own bodies, so it agreed with them
  by construction, and the cases were written by hand per field; R's runner matched message
  fragments that collided. Concretely, `output.receipt_version` was checked on the path route only,
  an impossible time (month 13) was published, `result: null` and several states were unpinned, and
  the Python reading crashed on a non-string `receipt_asset`. Fixed by construction rather than by
  instance: R's refusals are classed conditions carrying `code`; `stac.json`'s cases are generated as
  every path the mapping reads crossed with every state (142 cases, codes derived from R's
  conditions); a test derives the paths from `mapping.csv` independently and asserts each has its
  absent, null and wrong-type cases; the form version and real-instant checks are added on both
  sides; the crosscheck reports an unexpected exception as a mismatch
- Mutation over round 4's construction: 21 of 21 mutants red, 20 guards in `crt_receipt_stac()`
  plus a generator that drops a path (receipt not an object 4, null block as absent 10, non-object
  block 3, form version 12, missing recipe_id 8, id on migrated 2, recipe_id pattern 18, time 40,
  time range 16, time newline 2, empty repo name 1, version 8, unmatched asset 8, sha256 58, negative
  bytes 2, receipt_asset type 4, empty receipt_asset 2, receipt_asset shadowing 2, digest without
  asset 2, asset without digest 2, generator path dropped 5). The review loop ends on this
  enumeration; no round 5. stacs: 87 of 142, stacs#15 updated
