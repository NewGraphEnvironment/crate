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

**Next:**
- Commit PWF baseline
- Phase 1: Convention C renames (registry_load → crt_registry_load, internal_bcfp_* → crt_handler_bcfp_*, file-local helpers → crt_handler_bcfp_uhc_*)
- Phase 2-5: schema family additions + tests
- Phase 6: README + version bump
- Phase 7: PR + monitor
- Phase 8: tag + comms to link + archive
