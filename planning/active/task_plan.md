# Task Plan — crate#2: Scaffold R package + ship `crt_ingest()` first instance

Branch: `2-scaffold-crt-ingest`
Issue: NewGraphEnvironment/crate#2
Comms thread: `link/comms/crate/20260427_fresh_bcfishpass_csv_consumers.md` + `20260427_bcfp_ingest_impl_plan.md` (both closed)
Path E architecture: source-explicit dispatcher in crate, source-agnostic API in link (link#65 consumer).

## Phase 1 — Repo scaffold
- [x] Create `DESCRIPTION` (Title, Description, Authors@R w/ ORCID, MIT license, URL = repo + pkgdown site, Imports: chk, cli, dplyr, fs, readr, tibble, tidyr, yaml; Suggests: testthat ≥ 3.0.0, knitr, rmarkdown, lintr, hexSticker; Config/testthat/edition: 3, Roxygen markdown: TRUE)
- [x] Create `R/crate-package.R` (package-level docs)
- [x] Create `.lintr` (clone from flooded)
- [x] Create `.Rbuildignore` (exclude data-raw/, dev/, planning/, comms/, decisions/, README.Rmd, .claude/)
- [x] Create `_pkgdown.yml` (bootstrap 5, url)
- [x] Create `dev/dev.R` (setup recipe, mirrors flooded)
- [x] Create `tests/testthat.R` (boilerplate)
- [x] Create `LICENSE` + `LICENSE.md` (MIT)
- [x] Run `devtools::document()` — populate NAMESPACE
- [x] /code-check the diff (round 1 clean)
- [x] Commit: "Scaffold crate as R package — DESCRIPTION, NAMESPACE, lintr, pkgdown, dev/"

## Phase 2 — Schema YAML + decision log + dir READMEs
- [x] Create `inst/extdata/schemas/README.md` (canonical authoring path: under inst/ for runtime access)
- [x] Create `inst/extdata/schemas/bcfp/user_habitat_classification.yaml` (canonical wide + 2 known upstream variants — yaml::read_yaml validates)
- [x] Create `decisions/README.md` (root, Rbuildignored — docs only)
- [x] Create `decisions/bcfp/20260427_user_habitat_classification_wide_canonical.md`
- [x] /code-check the diff (round 1 clean)
- [x] Commit: "Add bcfp/user_habitat_classification schema + wide-canonical decision log"

## Phase 3 — Registry + first-instance handler + example fixtures
- [x] Create `inst/extdata/crate_registry.csv` (cols: source, file_name, handler_fn, schema_yaml, canonical_cols — 1 row)
- [x] Create `data-raw/crate_registry.R` (documents how registry was authored + sanity check)
- [x] Create `R/internal_bcfp_user_habitat_classification.R` — dispatches on variant_id; identity + pivot_long_to_wide handlers
- [x] Create `inst/extdata/examples/bcfp/wide_user_habitat_classification.csv` (6 rows: both / spawning-only / rearing-only / -4 excluded)
- [x] Create `inst/extdata/examples/bcfp/long_user_habitat_classification.csv` (7 rows, equivalent to wide minus the -4 row)
- [x] Create `data-raw/example_fixtures_bcfp_user_habitat_classification.R` (documents fixture authoring)
- [x] Manual smoke test: handler runs both paths, invariance check (long pivoted == wide minus -4 row) passes
- [x] /code-check round 1 clean (one doc/intent mismatch in pivot comment fixed: comment now accurately describes that metadata is part of id_cols and divergent metadata would split — known limitation, deferred until it bites real data)
- [x] Commit: "Add crate_registry + internal_bcfp_user_habitat_classification handler + example fixtures"

## Phase 4 — Public API: crt_ingest + crt_files with runnable examples
- [x] Create `R/crt_ingest.R` (dispatcher)
- [x] Add runnable @examples to crt_ingest using bundled fixtures via system.file()
- [x] Create `R/crt_files.R` (registry accessor)
- [x] Add runnable @examples to crt_files
- [x] Refactor: extract `R/registry_load.R` private helper called by both (DRY + cleaner separation)
- [x] Create `tests/testthat/test-crt_ingest.R` (8 test cases: identity, pivot, invariance, -4 preservation, unknown source/file, missing path, garbage shape, type validation)
- [x] Create `tests/testthat/test-crt_files.R` (5 test cases: shape, contains-bcfp-uhc, source filter, bogus filter, type validation)
- [x] Bump `.lintr` object_length_linter cap to 50 (allow `internal_<source>_<file_name>` pattern)
- [x] devtools::document() + devtools::test() (29 PASS / 0 FAIL / 0 WARN) + lintr::lint_package() (No lints found) — all clean
- [x] devtools::run_examples() — examples execute cleanly
- [x] /code-check round 1 clean (verified: variant matching, registry lookup, system.file resolution, chk validation paths, fixture-schema col equivalence, -4 preservation)
- [x] Commit: "Add crt_ingest dispatcher and crt_files registry accessor with runnable examples"

## Phase 5 — Hex sticker
- [x] Copy `data-raw/make_hexsticker.R` from flooded verbatim (script reads pkg name from DESCRIPTION; no per-repo edits)
- [x] Run script: generates `man/figures/logo.png` (300 dpi pkgdown) + `man/figures/logo_small.png` (150 dpi README) + downloads `data-raw/nge-icon_white.png` source
- [x] /code-check the diff (binary images + verbatim script)
- [x] Commit: "Add hex sticker via data-raw/make_hexsticker.R (verbatim from flooded)"
- README integration moves to Phase 7 (README.Rmd doesn't exist yet — Phase 7 creates it)

## Phase 6 — GHA workflows
- [x] Note: flooded/fresh/gq all have ONLY pkgdown.yaml (no separate R-CMD-check workflow). Pkgdown's `build_site_github_pages` implicitly runs R CMD check. Match convention.
- [x] Copy `.github/workflows/pkgdown.yaml` from flooded verbatim (deploys to gh-pages branch on push to main / release / workflow_dispatch; PRs build only)
- [x] /code-check the diff
- [x] Commit: "Add pkgdown.yaml GHA workflow (verbatim from flooded)"

## Phase 7 — README + final R CMD check
- [ ] Update `README.Rmd` (rebuild README.md): hex, install snippet, example, pkgdown link
- [ ] Run `R CMD check` locally — 0/0/0
- [ ] /code-check the diff
- [ ] Commit: "Update README with hex + install + example; pass R CMD check"

## Phase 8 — Open PR, monitor PR CI
- [ ] `git push -u origin 2-scaffold-crt-ingest`
- [ ] Open PR via gh CLI with body containing: summary, draft schema YAML inline, canonical-shape correction note, test plan, `Relates to NewGraphEnvironment/sred-2025-2026#28`, `Closes #2`
- [ ] Monitor GHA on PR with `gh pr checks --watch` until R-CMD-check completes green
- [ ] Wait for link-Claude review of schema YAML before tagging v0.0.1

## Phase 9 — Post-merge: monitor pkgdown publish + update issue bodies + planning archive
- [ ] After PR merge: tag v0.0.1, push tag
- [ ] Monitor GHA on main with `gh run watch` until pkgdown completes
- [ ] Verify pkgdown site loads at https://newgraphenvironment.github.io/crate/ with `crt_ingest`, `crt_files` in reference + examples render
- [ ] Edit crate#2 body: replace "long-canonical" → "wide-canonical"; update stale schema example
- [ ] Edit link#65 body: same correction
- [ ] Run `/planning-archive`
