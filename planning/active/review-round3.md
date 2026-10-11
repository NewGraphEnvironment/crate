# Review round 3 — crate#11 branch (R-CMD-check.yaml, pkgdown.yaml comment, .Rbuildignore)

## Clean

No issues found.

## Mechanism behind rounds 1 and 2

Both defects had the same root: **the guard counted a population narrower than the one
its claim covers, and the assumption that "a test that did not run shows up in the
thing I count" was taken as given.** Round 1 counted skips over a two-file `filter`
while the claim was the whole suite. Round 2 counted skips over the results data frame
(one row per `test_that()` block) while the claim covered file-level skips, which only the
reporter sees. In both cases the population the guard read and the population the claim
named happened to agree on the fixtures in hand, and diverged on a shape nobody had
written yet.

The other half of the same mechanism is "two lists that happen to agree": the Report
step's `known` vector against the literal skip messages in
`test-stac_schemas.R:10` / `test-crt_registry_integrity.R:124`, and the comment's "six
expected" against what the tests actually do.

## Where the mechanism reaches, and whether each place is covered

All runs below were done in copies under
`scratchpad/r3/` (`git archive HEAD`), with the source-tree step's script extracted
verbatim from the workflow and run with `CI=true`, one extra file per case.

### "Run the suite against the source tree" step

| population the guard reads | the claim's population | covered? |
|---|---|---|
| files: `test_local()` -> `find_test_scripts()` | every test file `test_check()` runs | yes, same discovery function |
| skips: `ProgressReporter$n_skip` (every `expectation_skip`) | every skip, block-level or file-level | yes |
| failures: `stop_on_failure` via the results frame | every failure/error | yes, see below |

New shapes tried (outside the round 2 list), all exit 1 unless noted:

- `if (FALSE) test_that(...)` (conditional definition, no skip) -> SKIP 1 (testthat 3.3.2 reports a file with no tests as an empty-test skip) -> exit 1
- top-level `return()` before any test -> SKIP 1 -> exit 1
- skip after a passing expectation in the same block -> SKIP 1 -> exit 1
- `describe()/it()` with skip -> SKIP 1 -> exit 1
- `skip_on_ci()` -> SKIP 1 -> exit 1 (`skip_on_cran()` likewise: `test_local()` sets `NOT_CRAN=true` only when unset, so any other value fails toward red)
- block with only a `warning()` -> WARN 1 SKIP 1 -> exit 1
- `skip()` in `helper-*.R` or `setup-*.R` -> aborts -> exit 1
- `stop()` in `helper-*.R` or `teardown-*.R` -> aborts -> exit 1
- top-level `expect_equal(1, 2)` outside `test_that()` -> FAIL 1 -> exit 1
- `withr::defer(stop())` / `withr::defer(expect_true(FALSE))` at file level -> FAIL 1 -> exit 1
- `withr::defer(stop())` inside a block -> FAIL 1 -> exit 1
- failing expectation in top-level `local()` after a passing block -> FAIL 1 -> exit 1
- new `expect_snapshot()` with no stored snapshot under `CI=true` -> FAIL 1 -> exit 1

Only one shape passes: **a block that bails with `return()` after at least one
expectation** (`test_that("x", { expect_true(TRUE); if (cond) return(invisible()); expect_true(FALSE) })`)
-> SKIP 0, exit 0. That shape is not a skip idiom, and the step's comment claims only
skips ("any later test that copies their skip idiom"). No current test uses it
(`grep 'return(' tests/testthat/*.R` hits only a helper in `test-stac_schemas.R:57`).
Out of the guard's stated reach, not a defect in it.

The `check/` directory that `check-r-package` leaves at the repo root does not reach this
step: no test walks the repo root recursively (the STAC tests walk
`pkgdown/assets/stac/`, and the registry tests read `system.file()` through pkgload's shim).

### "Report skipped tests" step

Exercised against a real `R CMD build` + `R CMD check --no-manual` of a copy with three
extra skips (a long reason, a reason containing `: ... (2):`, and a known reason in a new file):

- File population: `list.files(check/*/tests, "[.]Rout", recursive = TRUE)` picks up
  `testthat.Rout` and `testthat.Rout.fail`; CheckReporter writes the skip block before
  the failure block, so a failing run is still read. Covered.
- Wrapped bullets: `skip_bullets()` wraps with `exdent = 2`, so continuation lines are
  indented and the `^\S` filter drops them. A reason longer than the console width wraps
  inside the reason, and the step reports the truncated first line. A reason containing
  ` (n):` is cut at that point. Both still warn, so both fail toward visible.
- Known reason in a new file: passes this step silently by design, and the source-tree step
  went red on it (3 skips there). Covered by the enforcement step, as intended.
- The only fail-toward-pass parse is contrived: a new reason that begins with a known string
  followed by ` (n):`, e.g. `"not running in the source tree (2): ..."`. Not reachable from
  any realistic message.
- Absence: no `.Rout` under a present `tests/` -> `stop()`, and no skip block -> `::warning::`.
  Covered.

### pkgdown.yaml "Test the STAC schemas" step (context; comment-only change)

This step does not assert a zero skip count, so the mechanism reaches it in principle. Its
three skip conditions cannot fire in that job, though: `_pkgdown.yml` is in the checkout,
jsonvalidate is checked by `stopifnot`, and jsonlite is a Suggests installed by
`setup-r-dependencies` (default `dependencies: "all"`). Covered by construction, not by
assertion. The edited comment is accurate.

### .Rbuildignore

`^CITATION\.cff$` is a correct anchored regex. No other line changed.
