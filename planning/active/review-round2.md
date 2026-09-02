# Review round 2: Phase 1 + 2 (track_sessions naming columns, track_annotations overrides)

Scope: `git diff --cached` at `phase12.diff` — `track_sessions.yaml`,
`track_annotations.yaml`, `crate_registry.csv`, `test-crt_schema_conform.R`,
`task_plan.md`. Checked against `soul/conventions/code-check.md` (all sections
applicable to YAML contracts and R tests), the crate `crt_schema_*` sources, the
integrity test, the trap consumer, and rfp's shipped lookup / source / tests.

## Findings

- **[fragile]** `inst/extdata/schemas/nge/track_annotations.yaml:16-19` — the
  load-bearing sentence ("a column here that shares its name with a column of
  track_sessions is an override of it") is over-broad. `project`, `session_id`
  and `time_start_m` also share their names with track_sessions and are the join
  key and the fingerprint, not overrides. The parity test carves them out with a
  hand-written `keys <- c("project", "session_id", "time_start_m")`
  (`test-crt_schema_conform.R:260`), so the contract and its guard disagree about
  what an override is. This schema's whole premise is that readers are written
  from the prose; a reader implementing the rule literally would coalesce
  `time_start_m`, replacing the session's vertex-derived start with the
  annotation's fingerprint copy (which trap tolerates differing by up to 1 s).
  One-line fix: qualify the rule — "a non-key column here that shares its name…"
  or "…other than the key and fingerprint columns, which are declared as such
  above". The `(key)` / "Fingerprint, not data" labels in the column notes
  already say which columns those are; the rule sentence just needs to point at
  them.

Nothing else rises to a real issue.

## Verified, not flagged

Factual claims in the YAML prose, checked against sources:

- `rfp::rfp_tracking_fields_add()` and `rfp::rfp_qgs_tracking_fields_add()`
  exist (`rfp/R/rfp_tracking.R:584`, `:690`).
- Shipped lookup `rfp/inst/lookups/rfp_tracking_fields.csv`: all four TEXT;
  `track_type` value map `day log|stream survey|bushwhack|access route|drive|other`,
  default `'day log'`, stored value equals label; `named_by` default
  `@mergin_username`. Matches the YAML's list and default exactly.
- rfp's roxygen table lags the lookup (`reach walk…`, no `track_description`) —
  the YAML's "not rfp's roxygen, which has lagged it" is accurate, and Phase 4
  files the rfp issue.
- `@mergin_username` is the installed-plugin spelling (upstream master writes
  `@mm_username`, per `rfp_tracking.R:352-358`); the YAML names the installed one,
  which is what an rfp-deployed layer carries.
- "asserted by test against the installed plugin's source": `rfp/tests/testthat/
  test-rfp_tracking.R:278` ("the plugin still has no path that could rebuild the
  layer") and `:216` (default expressions compared against plugin source).
  Desktop-only caveat matches rfp's own section.
- `crt_schema_validate()` lists missing required columns in schema order, so the
  `"track_type, track_description"` expectation is stable; `crt_schema_apply()`
  skips absent columns, so the plugin-shape frame passes through without the four,
  as the accepted contract says.
- Registry row for `track_annotations` names exactly the six schema columns; the
  integrity test's registry-is-subset-of-schema check holds.
- YAML 1.1 boolean trap: no bare `y`/`n`/`on`/`off` names introduced. Folded
  scalars containing `*`, backticks and a trailing ` -` line-end parse as plain
  text (suite green at 234 confirms).
- `$` partial matching in the tests: keys per column are `name`, `type`,
  `required`, `notes` — no prefix pairs, so `col$name` / `col$type` /
  `col$required` resolve exactly.
- Premise assertions are real, not decoration: `expect_gt(length(overrides), 0)`
  fails only if annotations shrink to keys alone; `expect_false(isTRUE(required))`
  per column fails on a flip; the caller reports the parity test going red on a
  renamed override column.

Known downstream break, tracked in Phase 4 (not a finding on this diff):

- trap's `trp_track_annotate()` (`trap/R/trp_track_annotate.R:131-134`) assigns
  every non-key annotation column over `sessions` without coalescing — once
  sessions carry the four captured columns, unannotated sessions get their
  captured `track_name`/`track_type`/`track_description` blanked. This is exactly
  the failure the YAML paragraph warns about, and Phase 4's trap issue names it.
  Two things worth making sure that issue text also carries, since neither is in
  the current wording:
  - the `""` -> `NA` normalisation before coalescing (YAML line 24-27 puts it on
    the reader; trap does not do it today);
  - the roxygen `@examples` block at `trp_track_annotate.R:54-63` builds an
    annotations frame with `track_name` + `notes` and no `track_type` /
    `track_description`. It is conformed to `nge/track_annotations` on entry, so
    against this crate it aborts on required columns — and examples run at
    pkgdown build, so trap's docs site goes red on the next crate release.
    "Fixtures move from `notes`" may or may not be read as covering the example.

Per the checklist entry "Making an optional field mandatory breaks every producer
that legitimately left it empty": producers of `track_annotations` rows found are
trap's example, trap's tests/fixtures, and `working.trp_track_annotations` (empty,
reseed noted in Phase 3/4). `trp_annotations_empty()` derives its columns from the
schema and is unaffected.

## Verdict

One fragile item (prose rule over-broad relative to its own key columns and to the
test that guards it). No bugs, no security issues.
