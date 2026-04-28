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

**Next:**
- Commit Phase 3
- Phase 4: crt_ingest dispatcher + crt_files registry accessor + tests + runnable examples
