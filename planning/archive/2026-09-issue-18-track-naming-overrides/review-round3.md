# Code-check round 3 — Phase 1+2 staged diff

Scope: `git diff --cached` covering `track_sessions.yaml`, `track_annotations.yaml`,
`crate_registry.csv`, `test-crt_schema_conform.R`, `task_plan.md`. Checklist:
`soul/conventions/code-check.md`, every section applicable to an R package with
YAML data files.

## Verified

- Round 2's over-broad override rule is fixed. `track_annotations.yaml` lines 16-24 now
  scope the rule to columns that are not `project`, `session_id` or `time_start_m`, and
  each of those three is labelled as key / fingerprint in its own `notes`. The parity
  test mirrors the same three-name exclusion (`keys` at test line 262).
- Both affected test files run green against the staged tree:
  `test-crt_schema_conform.R` 52 pass / 0 fail, `test-crt_registry_integrity.R`
  44 pass / 0 fail / 0 skipped (integrity ran in the source tree, so the decisions
  check executed and still passes — the deferred decision reference is not yet in
  the YAML, as intended).
- Restore-the-bug in the optional-columns test reaches the validator: `required <- TRUE`
  on `track_name` goes through `isTRUE(col_spec[["required"]])` in
  `crt_schema_validate()` and the abort names `track_name`. The premise loop asserts
  all four are non-required first.
- "Missing an override column is refused" — with `track_name` present, the validator's
  `missing` vector is `track_type, track_description` in schema order, matching the
  regex.
- Registry: the `track_annotations` row lists exactly the schema's six columns; the
  `track_sessions` row lists the eleven required ones, and the integrity test only
  asserts registry ⊆ schema, so the four `required: false` additions need no row change.
- YAML 1.1 boolean trap: no new column name in `y/n/yes/no/on/off/true/false`; the
  integrity string-name guard passes.
- `$` partial matching: `col$type`, `col$name`, `col$required` have no sibling keys
  sharing a prefix in these specs.
- Tightening `track_type` / `track_description` to `required: true` on annotations:
  the only producer (`trp_annotations_empty()`) derives its columns from the YAML, and
  the only stored table (`working.trp_track_annotations`) is documented as seeded
  empty and never written. No producer breaks.
- No other in-repo reference to the removed `notes` column survives outside the
  (unstaged, Phase 3) decision entry, which describes the removal.

## Findings

- **[fragile]** `tests/testthat/test-crt_schema_conform.R:263-266` — the parity test
  asserts a stricter rule than the YAML it says it guards. The YAML rule
  (`track_annotations.yaml:16-19`) is "non-key **and** shares a name with
  track_sessions ⇒ override"; the test's `overrides <- setdiff(names(annotated), keys)`
  followed by `expect_identical(setdiff(overrides, names(captured)), character(0))`
  encodes "every non-key column **must** share a name". The same file's
  `forward_compat` reserves `annotated_by`, `annotated_at` and `review_status` as
  future canonical columns of this table that are explicitly *not* overrides
  (`track_annotations.yaml:95-113`). Probed: appending `annotated_by = "string"` to
  the annotations spec makes the setdiff return `"annotated_by"`, so the test fails on
  the line whose comment reads "added to annotations without a captured counterpart" —
  blaming a column the schema deliberately planned for. Same shape as the checklist's
  "a negative-case fixture rots when the positive set grows", and the natural repair at
  that moment — growing `keys` into an exemption list — is the "escape hatch where a
  guard goes to die" pattern. Not a failure today; the test is correct for the current
  three columns. If you want it to survive Phase-3-and-later work unchanged, split the
  two claims: overrides are `intersect(non_key, names(captured))`, keep `expect_gt`
  and the `identical` type check on that set, and add one absolute assertion naming the
  three override columns (`expect_setequal(overrides, c("track_name", "track_type",
  "track_description"))`) so a rename in either file still fails loudly rather than
  silently shrinking the set. Either way, no change is required for this commit.

Nothing else. No bug, no security issue, no data-loss path in the staged diff.
