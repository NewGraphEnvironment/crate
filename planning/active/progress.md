# Progress — crate#2: Scaffold R package + ship crt_ingest

## Session 2026-04-27 (afternoon)

**Branch:** `2-scaffold-crt-ingest` (created from main `896843d`)

**Setup commits (pre-PWF baseline):**
- `8ba0b4e` — Initialize planning directory structure (planning-init skill)

**Plan-mode exploration:**
- Three Explore agents in parallel: (1) R-package conventions + flooded reference patterns, (2) user_habitat_classification CSV current/historical shape, (3) fresh's overlay API + recent #176/#177 resolution
- Plan file: `/Users/airvine/.claude/plans/bright-spinning-wall.md`
- **Critical correction surfaced:** canonical shape is WIDE not long. Issue body and decision log filename will need post-merge update (Phase 9).

**Plan approved.** Starting Phase 1.

**Phase 1 complete (pre-commit):**
- DESCRIPTION, R/crate-package.R, .lintr, .Rbuildignore, _pkgdown.yml, dev/dev.R, tests/testthat.R, LICENSE, LICENSE.md created
- devtools::document() ran clean — NAMESPACE populated with @importFrom directives from R/crate-package.R; man/crate-package.Rd generated
- Path decision (vs original plan): schemas/ and decisions/ live at root for human visibility; schemas/ ALSO ships via inst/extdata/schemas/ for runtime access by crt_ingest. Decision finalized when Phase 2 schema authoring lands.
- Next: /code-check + commit Phase 1

**Phase 1 shipped** as commit `838a236`. /code-check round 1 clean.

**Phase 2 complete (pre-commit):**
- inst/extdata/schemas/README.md, inst/extdata/schemas/bcfp/user_habitat_classification.yaml created
- decisions/README.md, decisions/bcfp/20260427_user_habitat_classification_wide_canonical.md created
- yaml::read_yaml validates: file=user_habitat_classification, canonical.shape=wide, 11 canonical cols, 2 upstream variants
- Path decision finalized: schemas at inst/extdata/schemas/, decisions at root (Rbuildignored). Rationale documented in schemas/README.md and decisions/README.md.

**Phase 2 shipped** as commit `6ff7614`. /code-check round 1 clean.

**Phase 3 complete (pre-commit):**
- inst/extdata/crate_registry.csv — 1 row mapping (bcfp, user_habitat_classification) → handler
- data-raw/crate_registry.R + data-raw/example_fixtures_bcfp_user_habitat_classification.R — author documentation
- R/internal_bcfp_user_habitat_classification.R — dispatcher on variant_id; bcfp_uhc_identity + bcfp_uhc_pivot_long_to_wide handlers
- inst/extdata/examples/bcfp/wide_user_habitat_classification.csv (6 rows) + long_user_habitat_classification.csv (7 rows)
- devtools::document() ran, generated man/internal_bcfp_user_habitat_classification.Rd (with expected warning about unresolved @link to crt_ingest — will resolve in Phase 4 when crt_ingest documented)
- Manual smoke test: both handler paths execute clean; invariance check (long pivoted == wide minus -4 excluded row) returns TRUE

**Phase 3 reviewed:** /code-check round 1 returned Clean. Reviewer flagged one minor non-blocking observation (pivot handler comment said "take first per group" but implementation includes metadata in id_cols — divergent metadata across paired long rows would split into 2 wide rows). Fixed the comment to accurately describe the implementation + flagged the limitation for future fix-if-it-bites. Real-world long data has constant metadata per group; YAGNI on the proper aggregate-metadata fix.

**Phase 3 shipped** as commit `e7a1811`.

**Phase 4 complete (pre-commit):**
- R/crt_ingest.R + R/crt_files.R (exported public API)
- R/registry_load.R (private helper — single source of truth for registry CSV reading; DRY across crt_files + crt_ingest; refactored mid-Phase from initial dotted-prefix `.crate_registry()`)
- Both public funcs have runnable @examples using bundled fixtures via system.file()
- tests/testthat/{test-crt_ingest.R,test-crt_files.R} — 13 tests total, all passing
- devtools::document() — clean (after second pass; first pass had expected unresolved-link warning that resolves once crt_ingest is documented)
- devtools::test() — 29 PASS / 0 FAIL / 0 WARN / 0 SKIP
- devtools::run_examples() — both examples execute clean, output sensible
- lintr::lint_package() — No lints found (after bumping object_length_linter cap to 50 + adding nolint comments for cross-file function refs and cli-string-interpolated variables)
- All design decisions from comms thread baked in: source-explicit dispatcher, fail-loud on unknown source/file/shape, runtime YAML validation, tibble return contract

**Phase 4 shipped** as commit `9b55916`. /code-check round 1 clean.

**Phase 5 complete (pre-commit):**
- data-raw/make_hexsticker.R — verbatim copy from flooded (matches flooded + fresh; script reads pkg name from DESCRIPTION)
- Ran script: generated man/figures/logo.png (28 KB, 300 dpi) + man/figures/logo_small.png (13 KB, 150 dpi) + downloaded data-raw/nge-icon_white.png (9 KB source)
- Hex visual: NGE icon (stylized white symbol) on black hexagon, "crate" label below — matches NGE family aesthetic
- README.Rmd integration deferred to Phase 7 (README.Rmd doesn't exist yet)

**Next:**
- Commit Phase 5
- Phase 6: GHA workflows (R-CMD-check + pkgdown.yaml — copy from flooded; deploys to gh-pages branch)
- Phase 7: README.Rmd (with hex) + final R CMD check
- Phase 8: PR + monitor CI
