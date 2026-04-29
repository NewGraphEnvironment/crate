# Progress — crate#4: Convention C refactor + schema family

## Session 2026-04-29

**Branch:** `4-convention-c-refactor` (from main `e4a9149`)
**Issue:** NewGraphEnvironment/crate#4
**Plan file:** `/Users/airvine/.claude/plans/bright-spinning-wall.md`

**Setup:**
- Verified main is at `e4a9149` (no schema_apply on it; the `6764fd9` commit is on local-only `65-schema-driven-types` branch from link-Claude's session — never pushed)
- Created `4-convention-c-refactor` from main
- Plan approved via plan-mode; PWF baseline being committed now

**Auto mode active** — executing all phases per plan.

**Phase 0 done.** PWF baseline committed.

**Phase 1 complete (pre-commit):**
- Renamed `R/registry_load.R` → `R/crt_registry_load.R` + function `registry_load` → `crt_registry_load`
- Renamed `R/internal_bcfp_user_habitat_classification.R` → `R/crt_handler_bcfp_user_habitat_classification.R` + function rename
- Renamed file-local helpers: `bcfp_uhc_identity` → `crt_handler_bcfp_uhc_identity`; `bcfp_uhc_pivot_long_to_wide` → `crt_handler_bcfp_uhc_pivot_long_to_wide`
- Updated callers (`crt_ingest.R`, `crt_files.R`), registry CSV, test fixture
- `.lintr` cap NOT bumped — longest function name (44 chars) fits existing 50-char cap
- 29/29 tests PASS, lintr clean (one pre-existing unrelated data-raw warning), document clean
- Code-check round 1 clean (reviewer flagged that README + decisions/ have stale name references; planned for Phase 6 README update — out of scope for Phase 1 atomic)

**Phase 1 shipped** as commit `da40dcc`.

**Phase 2 complete (pre-commit):**
- New `R/crt_schema_read.R` — extracts inline yaml::read_yaml + system.file path resolution from crt_ingest into a dedicated internal function. Single source of truth for schema YAML loading. chk-validates yaml_path arg.
- `R/crt_ingest.R` shed ~10 inline lines; now calls `crt_schema_read(matched$schema_yaml[[1L]])`.
- New `tests/testthat/test-crt_schema_read.R` — 3 test_that blocks cover bundled-path success, missing-path fail-loud, type validation.
- 38/38 tests PASS (was 29; +9 from new test file's 3 blocks × multiple expectations).
- lintr clean (one pre-existing data-raw warning still present).
- Code-check round 1 clean.

**Phase 2 shipped** as commit `09b6629`.

**Phase 3 complete (pre-commit):**
- New `R/crt_schema_apply.R` — re-implemented from abandoned 65-schema-driven-types branch under Convention C name. Walks `canonical.cols`, coerces each named col to declared type (integer/double/string/logical), skips unrecognized cols, fails loud on unknown types.
- `R/crt_ingest.R` — added `result <- crt_schema_apply(result, schema)` call after handler dispatch, with explanatory comment block + nolint marker.
- New `tests/testthat/test-crt_schema_apply.R` — 6 test_that blocks: integer enforcement end-to-end, type enforcement on long pivot output too, no-op when no canonical.cols, skip absent cols, fail-loud on unknown type, logical+string coercion.
- Fixed lintr indent issues in test file (formatting only).
- 54/54 tests PASS. R/ lintr clean.
- Code-check round 1 clean.

**Next:**
- Commit Phase 3 → Phase 4 (crt_schema_validate)
