# Progress — crt_table_fingerprint() refuses data.table's IDate, a Date subclass (#49)

## Session 2026-11-06

- Plan-mode exploration — phases approved by user
- Created branch `49-crt-table-fingerprint-refuses-data-table` off origin/main
- Scaffolded PWF baseline from issue #49 with approved phases
- Next: start Phase 1
- Phase 1 (53cfe65): `table_cells()` admits a class vector ending in `Date` or `c("POSIXct", "POSIXt")` and rebuilds it as the base class; issue reprex gives `1f1a7f8e…` for both IDate and Date
- Phase 2: tests for IDate/POSIXct subclass spelling, refusals (base not last, character storage, extra attribute), and compare re-read pairing an IDate key with its Date; both new positive tests fail against main's code
- Full suite 235 pass; lintr clean; R CMD check 0 errors / 0 warnings (2 environmental NOTEs: pkgdown URL redirects, time check)
- `/code-check branch`: round 1 fixed integer/all-NA POSIXct and Date (df71ff7); round 2 accepted refusal of logical non-NA / complex storage; ended by a 40-cell storage x class enumeration (findings.md)
