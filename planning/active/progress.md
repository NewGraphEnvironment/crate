# Progress — STAC field schemas for the catalogues' custom prefixes (lidarbc:, las:) (#23)

## Session 2026-10-10

- Plan-mode exploration — phases approved by user (URL: pkgdown Pages; scope: lidarbc + las, #23 stays open)
- Created branch `23-stac-field-schemas-for-the-catalogues-cu` off main
- Scaffolded PWF baseline from issue #23 with approved phases
- Next: start Phase 1
- Phase 1: `tests/testthat/test-stac_schemas.R` written; fails 7 with no schemas present (expected). Site URL derived from `_pkgdown.yml`'s `url:`, so the test and the site share one source.
