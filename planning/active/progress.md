# Progress — STAC field schemas for the catalogues' custom prefixes (lidarbc:, las:) (#23)

## Session 2026-10-10

- Plan-mode exploration — phases approved by user (URL: pkgdown Pages; scope: lidarbc + las, #23 stays open)
- Created branch `23-stac-field-schemas-for-the-catalogues-cu` off main
- Scaffolded PWF baseline from issue #23 with approved phases
- Next: start Phase 1
- Phase 1: `tests/testthat/test-stac_schemas.R` written; fails 7 with no schemas present (expected). Site URL derived from `_pkgdown.yml`'s `url:`, so the test and the site share one source.
- Phase 2: schemas, examples (from a live item), READMEs, CHANGELOGs; 79 pass; mutation table and pystac interop in findings.md
- Phase 3: pkgdown.yaml step 'Check the STAC schemas against what is published'; guard fixed to fail closed on a bad ref; 8-case table in findings.md
- Phase 4: README section, decision entry, NEWS. Plan review folded in (review-plan.md); full suite 343 pass; R CMD check 0E/0W, 2 pre-existing CITATION.cff NOTEs; pystac rejects all 16 value negatives
- code-check round 1: 2 fragile (test/guard selector mismatch; feature-branch dispatch could freeze schemas) fixed + las summaries tests; each new guard mutation-proven
- code-check round 2: release event could deploy an off-main tag (inside round 1's fix) — deploy now main-only; routes to gh-pages enumerated in findings.md
- code-check round 3: mechanism = freeze set wider than checked set; open axes version (uncompiled, unexemplified versions) and prefix (literal list) fixed; enumeration table in findings.md ends the loop
