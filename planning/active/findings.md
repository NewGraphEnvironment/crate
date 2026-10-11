# Findings — Nothing runs the test suite: add R-CMD-check (#11)

## Issue context

## Problem

`.github/workflows/` holds only `pkgdown.yaml`. Nothing runs the test suite — not on push, not on a PR. The suite passes when someone remembers to run `devtools::test()` locally, and at no other time.

That matters most for the guards that only pay off when something has already gone wrong. `test-crt_registry_integrity.R` walks the registry and the schemas directory and fails on a row without a YAML, a YAML without a row, a handler on a `schema_only` entry, or a declared type nothing implements. `test-crt_schema_apply_datetime.R` asserts that a timestamp's epoch is never moved, under a non-UTC timezone. Each describes a failure that would otherwise reach a caller silently.

A guard nobody runs is a comment.

## Evidence it is not theoretical

Both classes have already fired during authoring rather than in CI:

- YAML 1.1 resolves a bare `y` or `Y` to a boolean, so `- name: y` had silently stopped being a column name and would have gone untyped with nothing reported.
- Three bugs in the datetime character parse, each of which moved a real instant, were live while the suite was green — found by review, not by a run.

## Proposed

`.github/workflows/R-CMD-check.yaml`, matching the one in the sibling packages: `ubuntu-latest`, `r-lib/actions/setup-r-dependencies` with `needs: check`, `check-r-package` with `--no-manual`, on push to `main` and on every PR.

Add the skip report at the end. A skip is invisible in a green tick, and a test that starts skipping for a reason nobody chose should be visible.

## Acceptance

- A PR that breaks a test goes red
- The skip list is printed on every run


## Local R CMD check on main (2026-10-11)

`rcmdcheck(args = "--no-manual")` with `_R_CHECK_CRAN_INCOMING_=false _R_CHECK_FORCE_SUGGESTS_=false`
(what `check-r-package@v2` sets): 0 errors | 0 warnings | 1 NOTE (`CITATION.cff` in a
non-standard place). Tests: `[ FAIL 0 | WARN 0 | SKIP 6 | PASS 228 ]`.

Skips under check, all source-tree-only by design:
- `not running in the source tree (1)`: `test-crt_registry_integrity.R:124` (decisions/ is buildignored)
- `source tree not available (R CMD check) (5)`: `test-stac_schemas.R` 63, 92, 114, 164, 189

testthat Imports pkgload, so `testthat::test_local()` can load the source tree in CI
without adding devtools.

## Errors Encountered

| Error | Resolution |
|-------|------------|
