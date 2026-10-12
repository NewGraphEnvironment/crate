## Outcome

Added `.github/workflows/R-CMD-check.yaml`, the first workflow to run crate's test suite. It has three parts: `R CMD check` (`error-on` warning); a step that prints the testthat skip block on every run and annotates any skip reason beyond the six expected; and a re-run of the whole suite against the source tree that fails on any skip. The source-tree run exists because `R CMD check` has no source tree, so the `decisions/` check in `test-crt_registry_integrity.R` would otherwise have run nowhere. `^CITATION\.cff$` went into `.Rbuildignore`. What was learned: the zero-skip guard went wrong twice before it was right, both times by counting a narrower set than it claimed. First it ran a two-file `filter`. Then it used `as.data.frame()` of the results, which has one row per `test_that()` block and so misses a skip at a file's top level. Counting from `ProgressReporter$n_skip` fixed it (see findings.md).

## Measurement

- `rcmdcheck`, `--no-manual` only: 0 errors / 0 warnings / 1 NOTE (CITATION.cff). Re-measured with the action's real args (`--no-manual --as-cran`, `_R_CHECK_CRAN_INCOMING_` and `_R_CHECK_FORCE_SUGGESTS_` false) and the `.Rbuildignore` line in place: 0 / 0 / 0. The plan review caught that the first measurement used the wrong args. The clean result is what allowed `error-on: "warning"`.
- Tests under check: FAIL 0, SKIP 6, PASS 228. The full suite from the source tree: FAIL 0, SKIP 0, PASS 386.
- Gate proof on throwaway PR #29 (run 38168115419): `checking tests` red on `test-crt_schema_read.R:5`, and the source-tree step red on `test-crt_registry_integrity.R:128`. The skip report printed the six expected skips on the failing run.
- PR #30 (run 38168426313): green, 6 skips listed, source-tree step at SKIP 0.

## Evidence

CI runs 38168115419 (red, deliberate) and 38168426313 (green). The code-check rounds are in `review-round*.md` in this directory.

Closed by: PR #30
