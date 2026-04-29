# Task Plan — crate#4: Convention C refactor + schema family

Branch: `4-convention-c-refactor` (from main `e4a9149`)
Issue: NewGraphEnvironment/crate#4
Locks 3 design decisions: Convention C naming, schema-as-contract scope (types now + reserved family), imperative handlers stay.

## Phase 0 — Branch + PWF baseline
- [x] Branch from main
- [ ] PWF baseline files
- [ ] Commit baseline

## Phase 1 — Internal renames (Convention C)
- [x] `git mv R/registry_load.R R/crt_registry_load.R`; renamed function
- [x] `git mv R/internal_bcfp_user_habitat_classification.R R/crt_handler_bcfp_user_habitat_classification.R`; renamed function
- [x] Renamed file-local helpers: `bcfp_uhc_*` → `crt_handler_bcfp_uhc_*`
- [x] Updated `R/crt_ingest.R` + `R/crt_files.R` callers
- [x] Updated `inst/extdata/crate_registry.csv` handler_fn cell
- [x] nolint comments unchanged (still valid — same nolint rule applies to renamed function)
- [N/A] `.lintr` cap bump — longest function name is 44 chars (`crt_handler_bcfp_user_habitat_classification`); existing 50-char cap fits. No bump needed.
- [x] devtools::document() + test (29 PASS) + lint clean
- [x] /code-check round 1 clean
- [x] Commit: "Rename internals to Convention C (crt_* prefix, family-namespaced)"

## Phase 2 — Add crt_schema_read
- [x] Created `R/crt_schema_read.R` (path resolution + read_yaml)
- [x] Updated `R/crt_ingest.R` to use it (replaced 10 inline lines with 1 call)
- [x] Created `tests/testthat/test-crt_schema_read.R` (3 test_that blocks: bundled-path success, missing-path throws, type validation)
- [x] document + test (38 PASS) + lint clean
- [x] /code-check round 1 clean
- [x] Commit: "Extract crt_schema_read() — single source of truth for schema YAML loading"

## Phase 3 — Add crt_schema_apply
- [x] Created `R/crt_schema_apply.R` (re-implemented from abandoned 65-schema-driven-types branch under Convention C name)
- [x] Updated `R/crt_ingest.R` to call after handler with nolint comment
- [x] Created `tests/testthat/test-crt_schema_apply.R` (6 test_that blocks ported from abandoned branch)
- [x] document + test (54 PASS) + lint clean (R/ clean; pre-existing data-raw warning unchanged)
- [x] /code-check round 1 clean
- [x] Commit: "Add crt_schema_apply() — schema-driven canonical type enforcement"

## Phase 4 — Add crt_schema_validate
- [x] Created `R/crt_schema_validate.R` (required-cols check; @details documents reserved family slots for range/enum/predicate)
- [x] Updated `R/crt_ingest.R` to call BEFORE crt_schema_apply with explanatory comment + nolint
- [x] Created `tests/testthat/test-crt_schema_validate.R` (6 test_that blocks: silent on success; throws listing missing; required:false skipped; absent-key skipped; no canonical.cols no-op; end-to-end via crt_ingest)
- [x] document + test (60 PASS) + lint clean (R/ clean)
- [x] /code-check round 1 clean
- [x] Commit: "Add crt_schema_validate() — required-cols enforcement"

## Phase 5 — Direct tests for crt_registry_load + handler
- [x] Created `tests/testthat/test-crt_registry_load.R` (4 test_that blocks: shape, non-empty, bcfp/uhc entry, all-character types)
- [x] Created `tests/testthat/test-crt_handler_bcfp_user_habitat_classification.R` (8 test_that blocks: dispatcher branches, unknown variant_id throws, helper required-cols validation, -4 preservation, both spawning+rearing produced after pivot, canonical column order)
- [x] test (86 PASS) + lint clean
- [x] /code-check round 1 clean
- [x] Commit: "Add direct tests for crt_registry_load + crt_handler_bcfp_user_habitat_classification"

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
