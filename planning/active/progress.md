# Progress — Register nge/fish_data — reconcile 2023 column names to canonical (#6)

## Session 2026-10-31

- Plan-mode exploration — phases approved by user
- Created branch `6-register-nge-fish-data-reconcile-2023-co` off origin/main
- Scaffolded PWF baseline from issue #6 with approved phases
- Next: start Phase 1
- Plan review returned; findings and dispositions in `review-plan.md` (date as UTC `format()` with a midnight check, `decisions:` key deferred to Phase 3, real-data script checks species vocabularies and time formats)
- Phase 1: `schemas/nge/fish_data.yaml` (29 canonical cols, 3 variants), registry row, synthetic fixtures, handler + ingest tests (red before the handler)
- Phase 2: `R/crt_handler_nge_fish_data.R`; suite 1251 pass. Mutation: stubbing tag extraction turns "seasons bind, and a tag recaptured from a 2023 comment is found" red
