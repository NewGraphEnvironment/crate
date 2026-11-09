# Progress — register.csv and mapping.csv are unversioned, and every verdict is a function of their rows (#58)

## Session 2026-11-09

- CLAUDE.md sync: already current with soul origin/main@470dc10, nothing to commit
- Plan-mode exploration; versioning design discussed with the owner (receipt number = form only; register and mapping versioned separately; form v1.1.0 work split to a new issue) — phases approved
- Created branch `58-register-csv-and-mapping-csv-are-unversi` off origin/main (af8574b)
- Scaffolded PWF baseline from issue #58 with approved phases
- Next: start Phase 1
- Phase 1: tests written first; 9 fail before the move (compare 4, vectors 2, migrate 1, schema 2), as intended
