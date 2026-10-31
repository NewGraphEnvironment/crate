# Progress — Canonical schemas for field forms: vintage in columns, not filenames (#13)

## Session 2026-10-30

- Plan-mode exploration — phases approved by user
- Created branch `13-canonical-schemas-for-field-forms-vintag` off origin/main
- Scaffolded PWF baseline from issue #13 with approved phases
- Next: start Phase 1
- Phase 1 landed (3ef954c). Mid-phase fork asked and answered: fingerprint hashes the plain string.
- Plan review returned (review-13.md): confirmed fiss_site's 7 `real` text dropdowns (user: `string`)
  and rfp's private visibility; its "help names a person" claim was wrong (CHRIS = MoTI system).
- Phase 2: `crt_schema_cols()`, `crt_schema_grade()`, `crt_schema_variant()`, unknown-fingerprint
  warning in conform, integrity guards (four are empty until Phase 4 registers form schemas).
- Phase 3: derive script runs at rfp@a901caa; second run byte-identical (md5 over 5 YAMLs + fixtures).
  Units: allow-list + ordered name patterns (`_m_s_cm` first, it is mS/cm); YAML booleans as true/false.
