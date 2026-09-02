# Code-check review, round 1 (Phase 1 staged diff)

Scope: `git diff --cached` covering `inst/extdata/schemas/nge/track_sessions.yaml`,
`tests/testthat/test-crt_schema_conform.R`, `planning/active/task_plan.md`.
Checklist: `soul/conventions/code-check.md`, every applicable item.

## Clean

No issues found.

## What was verified

- **Staged diff is green on its own.** Ran `devtools::test(filter = "crt_schema_conform|crt_registry_integrity")`
  against a `git checkout-index` copy of the index (no unstaged files):
  `FAIL 0 | WARN 0 | SKIP 0 | PASS 90`. The decisions-exist test ran (not skipped)
  and passed, so the deferred `decisions:` reference costs nothing here.
- **The working-tree run fails 1 test, and it is not this diff.** In the live tree
  `test-crt_schema_conform.R:218` (the pre-existing annotations test, unchanged by
  the diff) errors on a missing required column because
  `inst/extdata/schemas/nge/track_annotations.yaml` and `crate_registry.csv` are
  modified but **unstaged** (Phase 2 work already begun). Commit Phase 1 as staged;
  that failure belongs to Phase 2 and its test will need updating there.
- **Restore-the-bug test actually reaches the bug.** `crt_schema_validate()` gates on
  `isTRUE(col_spec$required)`; flipping `cols[[idx[[1]]]]$required <- TRUE` on the
  parsed list puts `track_name` in `missing`, and the abort message
  (`"Missing: track_name"`) matches the `"track_name"` regex. Premise assertion
  (all four `required: false`) precedes it, per the negative-fixture rule.
- **Type coercions in the positive test are exercised.** `NA` (logical) -> `as.character`
  gives `NA_character_`; `factor("example_user")` -> `"example_user"`. Both asserted.
- **YAML 1.1 boolean trap:** none of the new names (`track_name`, `track_type`,
  `track_description`, `named_by`) or variant col entries resolve to booleans. The
  integrity test's is-character guard also passed.
- **Factual claims in the YAML prose, against sources:**
  - `rfp::rfp_tracking_fields_add()` / `rfp::rfp_qgs_tracking_fields_add()` exist and
    are exported (`rfp/NAMESPACE:66,79`).
  - `rfp/inst/lookups/rfp_tracking_fields.csv`: all four TEXT; `track_type` valuemap
    `day log|stream survey|bushwhack|access route|drive|other`, default `'day log'`,
    "stored value equals the label"; `named_by` default `@mergin_username`. Matches.
  - "rfp's roxygen has lagged it": `rfp/R/rfp_tracking.R:529` lists
    `reach walk, bushwhack, access route, drive, other` -- no `day log`, no
    `stream survey`. Claim is correct.
  - Safety argument (single `create_tracking_layer()` call site behind an unreachable
    branch; `setup_tracking_layer()` uses `indexFromName()` and never enumerates or
    prunes; desktop only; asserted against installed plugin source):
    `rfp/R/rfp_tracking.R:533-556` and `rfp/tests/testthat/test-rfp_tracking.R:216,280`.
    Matches.
  - "`annotated_by`, which that schema reserves": present in `track_annotations.yaml`
    `forward_compat` at HEAD (line 62).
  - "the `enum` slot crt_schema_validate() reserves": `R/crt_schema_validate.R:20`.
- **Registry row untouched** is consistent with the integrity test's contract
  (registry may list a subset of schema cols, never a superset).
- Shell/heredoc/quoting/path items in the checklist: not applicable, no shell in the diff.

## Non-blocking note

- `track_sessions.yaml` description (lines 16-17) says track_annotations' "columns of
  the same name override these" for all four. At HEAD, annotations declares only
  `track_name` (+ `notes`); `track_type` / `track_description` overrides arrive with
  the unstaged Phase 2 reshape. Same deliberate forward reference as the deferred
  decision entry -- fine within the branch, just make sure Phase 2 lands before merge.
