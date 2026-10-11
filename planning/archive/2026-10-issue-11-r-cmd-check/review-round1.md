# Review round 1 — branch 11-nothing-runs-the-test-suite-add-r-cmd-ch

## Findings

- **[severity: fragile]** .github/workflows/R-CMD-check.yaml:67-68, 108-109 and 124-125: the skip guard checks
  which reasons appear but never how many skips there are. A source-tree-only test added
  to any other file goes unrun, and nothing reports it.
  - The report step only flags `setdiff(reasons, known)`. The source-tree step only runs
    files matching `filter = "crt_registry_integrity|stac_schemas"`.
  - Suppose a new test in some other file copies the existing idiom, for example
    `skip_if_not(dir.exists(file.path(root, "decisions")), "not running in the source tree")`.
    Under R CMD check it skips with a known reason, so there is no annotation. The
    source-tree step's filter never selects its file, so it runs in neither job.
  - The YAML comment says "Six are expected", but the code never checks that count. So the
    "a skip here is an error" guarantee covers only the files named in the filter. This is
    the "enumerate the known states" shape from the checklist (rtj#259): an unlisted
    member defaults to pass.
  - Simplest fix: drop the `filter` from the source-tree step, so every test runs against
    the source tree. The suite is about 230 tests and cheap, and `sum(r$skipped) > 0` then
    covers any file. Another fix: assert that the parsed skip count equals 6 in the report
    step.
  - Not a bug today: the six current skips are exactly the ones the step re-runs.

## Checked and fine

- **Workflow shape.** The YAML parses. No step carries both `run` and `with`. The
  check-r-package `with:` is still attached to its own step.
- **Default check directory.** check-r-package defaults to `check-dir: "check"`. The
  `list.dirs("check")` call handles a missing directory: it returns `character(0)`, which
  takes the "no tests/" message branch.
- **`[.]Rout` pattern.** It matches both `testthat.Rout` and `testthat.Rout.fail`.
  `_snaps` holds no `.Rout` files.
- **Skip block format.** In testthat 3.3.2, `CheckReporter$end_reporter` writes the skip
  block before the warnings and failures, and `skip_bullets()` gives
  `"<bullet> <reason> (<n>): <locs>"`. Wrapped lines use `exdent = 2` and are dropped by
  `^\S`. `"Reason: "` is stripped. The `skip_if_not(cond, msg)` message is used verbatim,
  so both strings in `known` match.
- **`filter` matching.** `filter` is matched against `context_name(files)`, which only
  strips a leading `test-` and a trailing `.R`. On full paths the leading `test-` is not
  stripped, so the YAML comment about substring matching is accurate.
- **Test failures fail the step.** `test_local(stop_on_failure = TRUE)` aborts on a failure
  or an error, through `all_passed()` checking failed and error. If the filter selects no
  files, `test_dir` errors. testthat imports pkgload, so `load_all` is available after
  `needs: check`. pkgload's `system.file` shim covers `system.file(..., package = "crate")`
  in the integrity tests.
- **`.Rbuildignore`.** `^CITATION\.cff$` is correct and harmless.
- **Concurrency.** The group `check-true` does not collide with pkgdown's `pkgdown-true`.
  No other workflow sets a group.
