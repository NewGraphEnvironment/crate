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
- [ ] Create `inst/extdata/crate_registry.csv` (one row: source=bcfp, file_name=user_habitat_classification, normalize_fn, schema_yaml, canonical_cols)
- [ ] Create `data-raw/crate_registry.R` (documents how registry was authored)
- [ ] Create `R/internal_bcfp_user_habitat_classification.R` — wide-input identity + long-input pivot_wider, both return wide-canonical
- [ ] Create `inst/extdata/examples/bcfp/wide_user_habitat_classification.csv` (~10 rows, covers spawning-only / rearing-only / both / -4 excluded)
- [ ] Create `inst/extdata/examples/bcfp/long_user_habitat_classification.csv` (~16 rows, semantically equivalent in old long shape)
- [ ] /code-check the diff
- [ ] Commit: "Add crate_registry + internal_bcfp_user_habitat_classification handler + example fixtures"

## Phase 4 — Public API: crt_ingest + crt_files with runnable examples
- [ ] Create `R/crt_ingest.R` (dispatcher)
- [ ] Add runnable @examples to crt_ingest using bundled fixtures via system.file()
- [ ] Create `R/crt_files.R` (registry accessor)
- [ ] Add runnable @examples to crt_files
- [ ] Create `tests/testthat/test-crt_ingest.R` (5+ test cases)
- [ ] Create `tests/testthat/test-crt_files.R` (registry shape + filter)
- [ ] Run `devtools::document()` + `devtools::test()` + `lintr::lint_package()` — all clean
- [ ] /code-check the diff
- [ ] Commit: "Add crt_ingest dispatcher and crt_files registry accessor with runnable examples"

## Phase 5 — Hex sticker
- [ ] Create `data-raw/make_hexsticker.R` (mirrors flooded)
- [ ] Run script, generate `man/figures/logo.png`
- [ ] Update README.Rmd to reference hex
- [ ] /code-check the diff
- [ ] Commit: "Add hex sticker via data-raw/make_hexsticker.R"

## Phase 6 — GHA workflows
- [ ] Create `.github/workflows/R-CMD-check.yaml` (copy from flooded)
- [ ] Create `.github/workflows/pkgdown.yaml` (copy from flooded — conditional deploy on main)
- [ ] /code-check the diff
- [ ] Commit: "Add R-CMD-check + pkgdown GHA workflows"

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
