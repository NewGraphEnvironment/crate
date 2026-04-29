# Task Plan — crate#4: Convention C refactor + schema family

Branch: `4-convention-c-refactor` (from main `e4a9149`)
Issue: NewGraphEnvironment/crate#4
Locks 3 design decisions: Convention C naming, schema-as-contract scope (types now + reserved family), imperative handlers stay.

## Phase 0 — Branch + PWF baseline
- [x] Branch from main
- [ ] PWF baseline files
- [ ] Commit baseline

## Phase 1 — Internal renames (Convention C)
- [ ] `git mv R/registry_load.R R/crt_registry_load.R`; rename function
- [ ] `git mv R/internal_bcfp_user_habitat_classification.R R/crt_handler_bcfp_user_habitat_classification.R`; rename function
- [ ] Rename file-local helpers: `bcfp_uhc_*` → `crt_handler_bcfp_uhc_*`
- [ ] Update `R/crt_ingest.R` + `R/crt_files.R` callers
- [ ] Update `inst/extdata/crate_registry.csv` handler_fn cell
- [ ] Update nolint comments
- [ ] Bump `.lintr` object_length_linter cap to 60
- [ ] devtools::document() + test (29 PASS) + lint clean
- [ ] /code-check
- [ ] Commit: "Rename internals to Convention C (crt_* prefix, family-namespaced)"

## Phase 2 — Add crt_schema_read
- [ ] Create `R/crt_schema_read.R` (path resolution + read_yaml)
- [ ] Update `R/crt_ingest.R` to use it
- [ ] Create `tests/testthat/test-crt_schema_read.R`
- [ ] document + test + lint
- [ ] /code-check
- [ ] Commit: "Extract crt_schema_read() — single source of truth for schema YAML loading"

## Phase 3 — Add crt_schema_apply
- [ ] Create `R/crt_schema_apply.R` (re-implement from abandoned 65-schema-driven-types branch under Convention C name)
- [ ] Update `R/crt_ingest.R` to call it after handler
- [ ] Create `tests/testthat/test-crt_schema_apply.R` (port 6 tests from abandoned branch)
- [ ] document + test + lint
- [ ] /code-check
- [ ] Commit: "Add crt_schema_apply() — schema-driven canonical type enforcement"

## Phase 4 — Add crt_schema_validate
- [ ] Create `R/crt_schema_validate.R` (required-cols check; future-proof for range/enum/predicate)
- [ ] Update `R/crt_ingest.R` to call it BEFORE crt_schema_apply (validate shape, then coerce types)
- [ ] Create `tests/testthat/test-crt_schema_validate.R`
- [ ] document + test + lint
- [ ] /code-check
- [ ] Commit: "Add crt_schema_validate() — required-cols enforcement"

## Phase 5 — Direct tests for crt_registry_load + handler
- [ ] Create `tests/testthat/test-crt_registry_load.R`
- [ ] Create `tests/testthat/test-crt_handler_bcfp_user_habitat_classification.R`
- [ ] document + test + lint
- [ ] /code-check
- [ ] Commit: "Add direct tests for crt_registry_load + crt_handler_bcfp_user_habitat_classification"

## Phase 6 — README + DESCRIPTION + R CMD check
- [ ] Update README.md "How it works" (5 pieces) + caveat (variant-matching narrowed)
- [ ] Add brief schema-family-naming note to README for future readers
- [ ] Bump DESCRIPTION Version to 0.0.2
- [ ] devtools::check() — 0/0/≤1
- [ ] /code-check
- [ ] Commit: "Update README + bump Version to 0.0.2"

## Phase 7 — Open PR, monitor CI
- [ ] git push branch
- [ ] gh pr create with full body (Convention C reference table, naming locks, schema family slot description, SRED ref, Closes #4)
- [ ] Monitor pkgdown.yaml until green
- [ ] Wait for review

## Phase 8 — Post-merge: tag + comms + archive
- [ ] After merge: tag v0.0.2, push tag
- [ ] Monitor pkgdown deploy on main
- [ ] File comms thread `link/comms/crate/<date>_v002_refactor_shipped.md`
- [ ] /planning-archive
