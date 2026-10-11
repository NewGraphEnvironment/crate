# Task: Nothing runs the test suite: add R-CMD-check (#11)

## Problem

`.github/workflows/` holds only `pkgdown.yaml`. Nothing runs the test suite — not on push, not on a PR. The suite passes when someone remembers to run `devtools::test()` locally, and at no other time.

That matters most for the guards that only pay off when something has already gone wrong. `test-crt_registry_integrity.R` walks the registry and the schemas directory and fails on a row without a YAML, a YAML without a row, a handler on a `schema_only` entry, or a declared type nothing implements. `test-crt_schema_apply_datetime.R` asserts that a timestamp's epoch is never moved, under a non-UTC timezone. Each describes a failure that would otherwise reach a caller silently.

A guard nobody runs is a comment.

## Context

`.github/workflows/` holds `pkgdown.yaml` and `update-citation-cff.yaml`, and neither runs the suite. The only tests that run in CI are the STAC schema tests, which `pkgdown.yaml` runs because it publishes the schemas. The issue asks for an `R-CMD-check.yaml` matching the sibling packages, with the skip list printed on every run.

What I measured locally (`rcmdcheck`, `--no-manual`, with the env vars the action sets):

- **0 errors | 0 warnings | 1 NOTE.** The NOTE is `CITATION.cff` in a non-standard place, because it is not in `.Rbuildignore`. `main` is warning-clean, so the gate can use the action's default `error-on: "warning"`. That is fly's stronger choice, not gq's `"error"` workaround.
- **Tests: FAIL 0 | SKIP 6 | PASS 228.** All six skips are tests that need the source tree, so they skip by design under `R CMD check`:
  - `test-stac_schemas.R` (5): already run in CI by `pkgdown.yaml`.
  - `test-crt_registry_integrity.R:124` ("decision entries referenced by a schema exist"): **runs nowhere in CI**, because `decisions/` is `.Rbuildignore`d. A check-only workflow leaves this guard as "a comment", which is the thing the issue says it wants to end.

The templates are gq's `R-CMD-check.yaml` (single ubuntu job, job-level concurrency group) and fly's "Report skipped tests" step (fails when the test output is missing instead of reporting nothing).

## Phase 1: R-CMD-check workflow
- [x] Add `.github/workflows/R-CMD-check.yaml`. It runs on push to `main`, on `pull_request` and on `workflow_dispatch`. One `ubuntu-latest` job, `permissions: read-all`, and gq's concurrency group (`check-${{ github.event_name != 'pull_request' || github.run_id }}`, `cancel-in-progress: true`). Steps: `setup-pandoc`, `setup-r` (public RSPM), `setup-r-dependencies` (`extra-packages: any::rcmdcheck`, `needs: check`), and `check-r-package` (`build_args: 'c("--no-manual")'`, `upload-snapshots: true`, `error-on` left at its default of warning). A comment records why: main measured warning-clean.
- [x] Add a "Report skipped tests" step (`if: !cancelled()`, `shell: Rscript {0}`), adapted from fly. It prints the `Skipped tests` block from `check/*.Rcheck/tests/*.Rout*`. It fails if `tests/` exists with no `.Rout`. It exits quietly with a message if the check never reached the test stage. A comment names the six skips expected under check, so a new reason stands out.
- [x] Add a "Run the tests that need the source tree" step: `testthat::test_local(filter = "crt_registry_integrity|stac_schemas", stop_on_failure = TRUE)` from the checkout, after an assertion that `jsonvalidate` is installed (as `pkgdown.yaml` does). This is the one item beyond the issue's literal proposal. Without it the `decisions/` guard never runs in CI. Strike it if you would rather leave that to a follow-up.

## Phase 2: Clean-up the workflow makes necessary
- [x] Add `^CITATION\.cff$` to `.Rbuildignore`, which clears the only NOTE.
- [x] Update the `pkgdown.yaml` comment "crate has no test workflow…". It now reads: the STAC tests stay there because that job is the one that publishes, so a failing schema is never deployed, whatever R-CMD-check says.

## Phase 3: Prove the gate fires (acceptance)

Revised after plan review: the break goes on a throwaway PR branched off this one, so
no deliberately broken commit lands in main's history (`pull_request` has no branch
filter, so a PR based on this branch runs the workflow from its head).

- [ ] Throwaway branch off this one, one commit breaking (a) an assertion that runs under check and (b) the `decisions/` assertion only the source-tree step reaches. Draft PR against this branch. Confirm `check-r-package` goes red in `checking tests` and the source-tree step goes red, both read from the failing step's log. Confirm the skip report printed the 6 skips. Close the PR and delete the branch.
- [ ] On this PR's own run: green, skip list printed with the expected 6, no `::warning::`, source-tree step passing with SKIP 0.

## Validation
- [ ] Tests pass (local `rcmdcheck` 0/0, NOTE gone; `test_local` filter passes)
- [ ] `/code-check` clean (once over the branch with `/code-check branch`)
- [ ] PWF checkboxes match landed work
- [ ] `/planning-archive` on completion

