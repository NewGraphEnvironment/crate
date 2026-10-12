# Review round 2 — branch 11-nothing-runs-the-test-suite-add-r-cmd-ch

## Findings

- **[severity: fragile]** .github/workflows/R-CMD-check.yaml:126-131 — the source-tree step's
  "a skip is an error" gate cannot see a **file-level** skip. `sum(r$skipped)` reads
  `as.data.frame()` of the results, and that frame has one row per `test_that()` block. A
  `skip()` / `skip_if_not()` / `skip_if_not_installed()` / `skip_on_ci()` at a test file's
  top level (outside any block) skips the whole file, is counted by the reporter, and adds
  **no row** to the frame, so the step exits 0.

  Measured (testthat 3.3.2), on a scratch package with one passing test, one file whose
  first line is `skip("top level file skip")` and one whose only line is
  `skip_if_not(FALSE, "outside block not in tree")`, using the step's exact code:

  ```
  [ FAIL 0 | WARN 0 | SKIP 2 | PASS 1 ]
  STEP PASSES      # sum(as.data.frame(r)$skipped) == 0
  exit=0
  ```

  Why it matters: the step is now the sole enforcement (the skip-report step only warns), and
  its comment claims it catches "any later test that copies their skip idiom, whatever file it
  lands in". A later file that guards itself at top level — the natural shape for a whole
  file of source-tree tests, or a top-level `skip_if_not_installed()` for a Suggests package
  CI did not install — skips in the source tree with a green tick, and its tests run
  nowhere. That is the round-1 defect class (a test that runs nowhere, silently), reached
  through a different door. No current crate test has a top-level skip (all are inside
  `test_that()`), so nothing is lost today.

  Fix, verified on the same scratch package: keep the reporter and read its count, which does
  include file-level skips.

  ```r
  rep <- testthat::ProgressReporter$new(show_praise = FALSE)
  testthat::test_local(stop_on_failure = TRUE, reporter = rep)
  if (rep$n_skip > 0) stop(rep$n_skip, " test(s) skipped in the source tree")
  ```

  Measured: `n_skip = 1  df skipped = 0` for a file-level `skip()`. (An empty `test_that()`
  is counted by both, so nothing is lost by switching.)

## Checked and not a problem

- `test_local()` calls `local_assume_not_on_cran()`, so `skip_on_cran()`/`expect_snapshot()`
  cannot silently skip there for lack of `NOT_CRAN`; and the suite has no snapshots or
  `skip_on_*` calls anyway.
- `stop_on_failure = TRUE` fails on errored tests too (`all_passed()` checks `error`), so an
  uncaught error is not scored as a pass.
- pkgload (needed by `test_local`) arrives via testthat's Imports; jsonvalidate is in Suggests
  and installed by `needs: check`.
- The `check/` directory left in the workspace by check-r-package is not walked by any test
  (the STAC and decisions tests read scoped paths).
- Skip-report `.Rout` pattern matches `testthat.Rout.fail` on a failing check.
- Concurrency groups `check-true` / `pkgdown-true` differ, so the two workflows do not cancel
  each other.
- `^CITATION\.cff$` in `.Rbuildignore` is a valid anchored regex and nothing in the built
  package reads that file.
