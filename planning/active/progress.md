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

**Next:**
- Commit Phase 1 → Phase 2 (crt_schema_read)
