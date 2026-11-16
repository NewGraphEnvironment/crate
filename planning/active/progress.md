# Progress — Photo-table schema: one row per photo file (#67)

## Session 2026-11-16

- Plan-mode exploration — phases approved by user
- Created branch `67-photo-table-schema-one-row-per-photo-fil` off origin/main
- Scaffolded PWF baseline from issue #67 with approved phases
- Next: start Phase 1
- Phase 1: `tests/testthat/test-crt_photo.R`, 8 tests, all erroring before the schemas exist (unregistered entry), 2026-11-16
- Phase 2: `photo_files.yaml`, `photo_links.yaml`, two registry rows; test-crt_photo 8/8, registry integrity 16/16, schema meaning 13/13, crt_files 5/5 (NOT_CRAN=true). Integrity walks the new rows unedited.
- Plan review (Plan agent) landed after Phase 2: no blockers; findings and dispositions in `review-plan.md`. Folded in: `identified` grade, `relative_to` on path, links key, time/offset text shapes, partial Camtrap DP wording, receipt digest path. Two tests added (offset refused, identified grade); photo 10/10, integrity 16/16, meaning 13/13.
- Reworded planning files so a public repo names no private repo (the photo indexer and the internal track/form reader are described in words).
